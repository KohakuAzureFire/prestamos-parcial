// src/lib/decolecta.ts — Cliente de servidor para la API RENIEC de Decolecta (HU-03).
// IMPORTANTE: este módulo solo debe importarse desde código de servidor (Route Handlers).
// El token se lee de process.env.DECOLECTA_API_TOKEN (sin prefijo NEXT_PUBLIC_),
// por lo que Next.js nunca lo incluye en el bundle del navegador.
import 'server-only';

const DECOLECTA_URL = 'https://api.decolecta.com/v1/reniec/dni';
const TIMEOUT_MS = 8000;

export const DNI_REGEX = /^[0-9]{8}$/;

export type ConsultaDniResultado =
  | {
      ok: true;
      dni: string;
      nombres: string;
      apellidoPaterno: string;
      apellidoMaterno: string;
      apellidos: string;
      nombreCompleto: string;
    }
  | {
      ok: false;
      codigo:
        | 'DNI_INVALIDO'
        | 'NO_ENCONTRADO'
        | 'NO_COINCIDE'
        | 'TOKEN_INVALIDO'
        | 'LIMITE_CONSULTAS'
        | 'TIEMPO_AGOTADO'
        | 'ERROR_PROVEEDOR'
        | 'NO_CONFIGURADO';
      mensaje: string;
      status: number;
    };

interface DecolectaRespuesta {
  first_name?: string;
  first_last_name?: string;
  second_last_name?: string;
  full_name?: string;
  document_number?: string;
}

const limpiar = (v: unknown) => (typeof v === 'string' ? v.trim().replace(/\s+/g, ' ') : '');

export async function consultarDni(dni: string): Promise<ConsultaDniResultado> {
  // El DNI se trata siempre como texto para conservar ceros iniciales.
  if (typeof dni !== 'string' || !DNI_REGEX.test(dni)) {
    return { ok: false, codigo: 'DNI_INVALIDO', mensaje: 'El DNI debe tener exactamente 8 dígitos numéricos.', status: 400 };
  }

  const token = process.env.DECOLECTA_API_TOKEN;
  if (!token) {
    return {
      ok: false,
      codigo: 'NO_CONFIGURADO',
      mensaje: 'La consulta RENIEC no está configurada en el servidor (falta DECOLECTA_API_TOKEN).',
      status: 503,
    };
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(`${DECOLECTA_URL}?numero=${encodeURIComponent(dni)}`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
      cache: 'no-store',
      signal: controller.signal,
    });
  } catch (e) {
    const abortado = e instanceof Error && e.name === 'AbortError';
    return abortado
      ? { ok: false, codigo: 'TIEMPO_AGOTADO', mensaje: 'RENIEC (Decolecta) no respondió a tiempo. Intente nuevamente.', status: 504 }
      : { ok: false, codigo: 'ERROR_PROVEEDOR', mensaje: 'No se pudo conectar con el servicio de identidad. Intente nuevamente.', status: 502 };
  } finally {
    clearTimeout(timer);
  }

  if (res.status === 401 || res.status === 403) {
    // Decolecta responde 401 "Apikey Required / Limit Exceeded" tanto para token inválido como para cuota agotada.
    const cuerpo = (await res.text().catch(() => '')).toLowerCase();
    if (cuerpo.includes('limit') && !cuerpo.includes('apikey')) {
      return { ok: false, codigo: 'LIMITE_CONSULTAS', mensaje: 'Se alcanzó el límite de consultas del servicio de identidad. Intente más tarde.', status: 429 };
    }
    return {
      ok: false,
      codigo: 'TOKEN_INVALIDO',
      mensaje: 'El servicio de identidad rechazó la credencial (token inválido o cuota agotada). Contacte al administrador.',
      status: 502,
    };
  }
  if (res.status === 429) {
    return { ok: false, codigo: 'LIMITE_CONSULTAS', mensaje: 'Se alcanzó el límite de consultas del servicio de identidad. Intente más tarde.', status: 429 };
  }
  if (res.status === 404 || res.status === 422) {
    return { ok: false, codigo: 'NO_ENCONTRADO', mensaje: 'DNI no encontrado en RENIEC. Verifique el número e intente nuevamente.', status: 404 };
  }
  if (!res.ok) {
    return { ok: false, codigo: 'ERROR_PROVEEDOR', mensaje: `El servicio de identidad respondió con un error (${res.status}). Intente nuevamente.`, status: 502 };
  }

  let data: DecolectaRespuesta;
  try {
    data = (await res.json()) as DecolectaRespuesta;
  } catch {
    return { ok: false, codigo: 'ERROR_PROVEEDOR', mensaje: 'Respuesta inválida del servicio de identidad.', status: 502 };
  }

  const documento = limpiar(data?.document_number);
  const nombres = limpiar(data?.first_name);
  const apellidoPaterno = limpiar(data?.first_last_name);
  const apellidoMaterno = limpiar(data?.second_last_name);

  if (!documento && !nombres) {
    return { ok: false, codigo: 'NO_ENCONTRADO', mensaje: 'DNI no encontrado en RENIEC. Verifique el número e intente nuevamente.', status: 404 };
  }
  if (documento !== dni) {
    return { ok: false, codigo: 'NO_COINCIDE', mensaje: 'El documento devuelto por RENIEC no coincide con el DNI consultado. Verificación inconclusa.', status: 502 };
  }
  if (!nombres || (!apellidoPaterno && !apellidoMaterno)) {
    return { ok: false, codigo: 'ERROR_PROVEEDOR', mensaje: 'RENIEC devolvió datos incompletos para este DNI. Verificación inconclusa.', status: 502 };
  }

  const apellidos = [apellidoPaterno, apellidoMaterno].filter(Boolean).join(' ');
  return {
    ok: true,
    dni,
    nombres,
    apellidoPaterno,
    apellidoMaterno,
    apellidos,
    nombreCompleto: `${nombres} ${apellidos}`,
  };
}
