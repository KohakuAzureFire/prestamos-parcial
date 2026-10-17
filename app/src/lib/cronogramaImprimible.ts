import { escapar } from './contrato';
export interface CronogramaImprimible {
  identidad_contrato?: {nombres:string;apellidos?:string|null;ruc?:string|null;dni?:string|null}|null;
  id: string; fecha_prestamo: string; monto: number; plazo_meses: number;
  clientes: { nombres: string; apellidos?: string | null; ruc?: string | null; dni?: string | null };
  agencias: { nombre: string };
  cuotas: { numero_cuota: number; fecha_vencimiento: string; cuota_total: number; interes: number; amortizacion: number; saldo: number }[];
}
const dinero = (n: number) => 'S/ ' + Number(n).toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const fecha = (s: string) => s.slice(0, 10).split('-').reverse().join('/');
export function htmlCronograma(p: CronogramaImprimible): string {
  const c = p.identidad_contrato?.nombres?p.identidad_contrato:p.clientes, codigo = 'PR-' + p.id.slice(0, 8).toUpperCase();
  const cuotas = [...p.cuotas].sort((a, b) => a.numero_cuota - b.numero_cuota);
  const filas = cuotas.map(q => '<tr>' + [q.numero_cuota, fecha(q.fecha_vencimiento), dinero(q.cuota_total), dinero(q.interes), dinero(q.amortizacion), dinero(q.saldo)].map(v => '<td>' + escapar(String(v)) + '</td>').join('') + '</tr>').join('');
  const datos = [['Cliente', [c.nombres, c.apellidos].filter(Boolean).join(' ')], [c.ruc ? 'RUC' : 'DNI', c.ruc || c.dni || ''], ['Código', codigo], ['Agencia de origen', p.agencias.nombre], ['Fecha', fecha(p.fecha_prestamo)], ['Monto y plazo', dinero(p.monto) + ' · ' + p.plazo_meses + ' meses'], ['TEA / TEM', '30 % / 2,210445 %']];
  const totales = ['TOTAL', '', ...(['cuota_total', 'interes', 'amortizacion'] as const).map(k => dinero(cuotas.reduce((s, q) => s + Number(q[k]), 0))), ''];
  return '<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Cronograma ' + codigo + '</title><style>body{max-width:185mm;margin:16mm auto;font:10pt Arial;color:#102a43}h1{font-size:20pt}dl{display:grid;grid-template-columns:40mm 1fr;gap:7px}dt{font-weight:bold}dd{margin:0}table{width:100%;border-collapse:collapse;margin-top:20px}th,td{padding:8px;border-bottom:1px solid #d7e2ec;text-align:right}th:first-child,td:first-child{text-align:left}th{background:#102a43;color:white}tr{break-inside:avoid}thead{display:table-header-group}tfoot{display:table-row-group;font-weight:bold}button{padding:10px 18px;background:#00a1ad;color:white;border:0;border-radius:6px;cursor:pointer}.note{font-size:9pt;color:#526779}main{padding:0 10px}@media print{button{display:none}body{margin:0;max-width:none}main{padding:0}th{color:#102a43;background:#eef4f8}@page{size:A4;margin:15mm}}</style></head><body><main><button onclick="window.print()">Imprimir o guardar como PDF</button><h1>Cronograma de pagos</h1><p>Sistema francés · Condiciones originales del préstamo</p><dl>' + datos.map(([k, v]) => '<dt>' + escapar(k) + '</dt><dd>' + escapar(v) + '</dd>').join('') + '</dl><table><thead><tr>' + ['N.º', 'Vencimiento', 'Cuota', 'Interés', 'Capital', 'Saldo'].map(t => '<th>' + t + '</th>').join('') + '</tr></thead><tbody>' + filas + '</tbody><tfoot><tr>' + totales.map(t => '<td>' + escapar(t) + '</td>').join('') + '</tr></tfoot></table><p class="note">El cronograma original no incluye cargos moratorios posteriores ni refleja pagos realizados. Consulta el detalle del préstamo para ver su estado actual.</p></main><script>window.addEventListener("load",()=>window.print());</script></body></html>';
}
