// src/app/api/reniec/dni/route.ts — Consulta de DNI (HU-03) protegida por la sesión del asesor.
// El token de Decolecta se usa solo aquí, en el servidor; nunca se devuelve al navegador.
import {createHmac} from 'node:crypto';
import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { consultarDni } from '@/lib/decolecta';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json(
      { ok: false, codigo: 'NO_AUTENTICADO', mensaje: 'Sesión no válida. Inicie sesión nuevamente.' },
      { status: 401 },
    );
  }

  const {data:perfil}=await supabase.from('asesores').select('activo').eq('id',user.id).maybeSingle();
  if(!perfil?.activo)return NextResponse.json({ok:false,mensaje:'Cuenta sin autorización.'},{status:403});
  const secret=process.env.IDENTITY_SIGNING_SECRET;
  if(!secret)return NextResponse.json({ok:false,mensaje:'La verificación necesita configuración del servidor.'},{status:503});

  // Se conserva como texto: nunca se convierte a número (mantiene ceros iniciales).
  const dni = (request.nextUrl.searchParams.get('numero') ?? '').trim();
  const resultado = await consultarDni(dni);

  if (!resultado.ok) {
    // Registro sin datos sensibles (sin token ni DNI completo).
    console.warn(`[HU-03] Consulta RENIEC fallida: ${resultado.codigo} (asesor ${user.id})`);
    const { status, ...cuerpo } = resultado;
    return NextResponse.json(cuerpo, { status, headers: { 'Cache-Control': 'no-store' } });
  }

  const consultadoEn=new Date().toISOString();
  const payload=JSON.stringify({dni:resultado.dni,nombres:resultado.nombres,apellidos:resultado.apellidos,asesor_id:user.id,consultadoEn});
  const firma=createHmac('sha256',secret).update(payload).digest('hex');
  return NextResponse.json(
    { ...resultado, consultadoEn, payload, firma },
    { headers: { 'Cache-Control': 'no-store' } },
  );
}
