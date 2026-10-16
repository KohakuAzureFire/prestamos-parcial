/** Presentación de moneda; no cambia los cálculos financieros. */
export function formatImporte(value: number | string): string {
 const n=Number(value); if(!Number.isFinite(n))return '—';
 const [entero,decimal]=n.toFixed(2).split('.');
 return `S/ ${entero.replace(/\B(?=(\d{3})+(?!\d))/g,' ')}${','}${decimal}`;
}
export const condiciones = {activo:'Habilitado',restringido:'Moroso',extrajudicial:'Extrajudicial',fallecido:'Fallecido'} as const;

/** Estado visual de la constancia existente; no habilita clientes ni sustituye validación. */
export function estadoVerificacion(cliente:{resultado_verificacion:string|null;fecha_verificacion:string|null;fuente_verificacion:string|null}, hoy=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date())):'aprobada'|'pendiente' {
 const text=cliente.resultado_verificacion || '';
 const vencimiento=text.match(/DNI vigente hasta (\d{4}-\d{2}-\d{2})/i)?.[1];
 return cliente.fecha_verificacion&&cliente.fuente_verificacion&&vencimiento&&vencimiento>=hoy&&/sin condici[oó]n de fallecido/i.test(text)&&/identidad verificada/i.test(text)?'aprobada':'pendiente';
}
