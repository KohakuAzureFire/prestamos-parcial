export type TipoBusqueda = 'dni' | 'id';
export function normalizarCodigo(valor: string) {
  return valor.trim().replace(/^PR-/i, '').toUpperCase();
}
export function errorBusqueda(tipo: TipoBusqueda, valor: string) {
  if (tipo === 'dni') return /^\d{8}$/.test(valor) ? '' : 'Ingresa un DNI de exactamente 8 dígitos numéricos.';
  return /^[A-F0-9]{8}$/.test(normalizarCodigo(valor)) ? '' : 'Completa los 8 caracteres del código: números y letras de A a F.';
}
export function valorBusqueda(tipo: TipoBusqueda, valor: string) {
  return tipo === 'dni' ? valor : 'PR-' + normalizarCodigo(valor);
}
