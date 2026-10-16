// src/lib/financiero.ts
/**
 * Motor de cálculos financieros.
 * Sistema francés, TEA 30%, base anual 360 días, período 30 días.
 *
 * TEM = (1 + 0.30)^(30/360) - 1 ≈ 0.02210445
 */

export const TEA = 0.30;
export const CAPITAL_MAXIMO = 10_000;
const BASE_ANUAL = 360;
const DIAS_PERIODO = 30;

export const TEM = Math.pow(1 + TEA, DIAS_PERIODO / BASE_ANUAL) - 1;

export interface FilaCuota {
  numero_cuota: number;
  fecha_vencimiento: Date;
  cuota_total: number;
  interes: number;
  amortizacion: number;
  saldo: number;
}

/** Redondea a 2 decimales (half-up). */
export function r2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Agrega k meses a una fecha.
 * Si el día no existe en el mes destino → último día del mes (bisiestos incluidos).
 */
export function agregarMeses(fecha: Date, meses: number): Date {
  const dia = fecha.getDate();
  const resultado = new Date(fecha.getFullYear(), fecha.getMonth() + meses, 1);
  const ultimoDia = new Date(resultado.getFullYear(), resultado.getMonth() + 1, 0).getDate();
  resultado.setDate(Math.min(dia, ultimoDia));
  return resultado;
}

/**
 * Genera el cronograma de cuotas (sistema francés).
 */
export function generarCronograma(
  monto: number,
  n: number,
  fechaPrestamo: Date | string
): FilaCuota[] {
  const fecha0 = typeof fechaPrestamo === 'string' ? new Date(fechaPrestamo + 'T00:00:00') : fechaPrestamo;
  const cuotaConst = monto * TEM / (1 - Math.pow(1 + TEM, -n));

  const filas: FilaCuota[] = [];
  let saldo = monto;

  for (let k = 1; k <= n; k++) {
    const interes = r2(saldo * TEM);
    let amortizacion: number;
    let cuota_total: number;

    if (k < n) {
      cuota_total = r2(cuotaConst);
      amortizacion = r2(cuota_total - interes);
    } else {
      amortizacion = r2(saldo);
      cuota_total = r2(amortizacion + interes);
    }

    const nuevoSaldo = k < n ? r2(saldo - amortizacion) : 0;

    filas.push({
      numero_cuota: k,
      fecha_vencimiento: agregarMeses(fecha0, k),
      cuota_total,
      interes,
      amortizacion,
      saldo: nuevoSaldo,
    });

    saldo = nuevoSaldo;
  }

  return filas;
}

/** Formatea fecha como DD/MM/YYYY */
export function formatFecha(d: Date): string {
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
}

/** Formatea número como moneda peruana */
export function formatMoneda(n: number | string): string {
  const val = typeof n === 'number' ? n : parseFloat(String(n)) || 0;
  return `S/ ${val.toFixed(2)}`;
}
