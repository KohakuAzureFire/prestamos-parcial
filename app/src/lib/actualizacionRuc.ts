export interface DatosRucGuardados {
 razon_social:string|null;estado_ruc:string|null;condicion_ruc:string|null;direccion_fiscal:string|null;ruc_consultado_at:string|null;
}
export const camposRuc=[
 {etiqueta:'Nombre o razón social',guardado:'razon_social',consulta:'razon_social'},
 {etiqueta:'Estado',guardado:'estado_ruc',consulta:'estado'},
 {etiqueta:'Condición',guardado:'condicion_ruc',consulta:'condicion'},
 {etiqueta:'Domicilio fiscal',guardado:'direccion_fiscal',consulta:'direccion'},
] as const;
export function textoRuc(valor:string|null|undefined){const texto=valor?.trim()||'';return texto==='-'?'':texto;}
export function fechaRevision(valor:string|null|undefined){return valor?new Date(valor).toLocaleString('es-PE',{timeZone:'America/Lima'}):'Sin registro';}
