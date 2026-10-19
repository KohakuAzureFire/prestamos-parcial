export const LIMITE_PDF=5*1024*1024;
export const BUCKET_CERTIFICADOS='certificados-representacion';
export interface Representacion {
 id:string;ruc:string;razon_social:string;propietario_dni:string;representante_dni:string;
 asesor_id:string;agencia_id:string;archivo_ruta:string;archivo_nombre:string;archivo_bytes:number;
 fecha_emision:string;estado:'cargando'|'pendiente'|'revisada'|'observada'|'descartada';archivo_sha256:string|null;
 observacion:string|null;referencia_validacion:string|null;revisor_id:string|null;revisado_at:string|null;
 valida_hasta:string|null;monto_maximo:number|null;version:number;created_at:string;
 asesor_nombre?:string;agencia_nombre?:string;revisor_nombre?:string;
}
export const estadoRepresentacion=(r:Representacion,hoy:string)=>r.estado==='revisada'&&r.valida_hasta&&r.valida_hasta<hoy?'Revisión vencida':({cargando:'Carga sin completar',pendiente:'Pendiente de revisión',revisada:'Representación revisada',observada:'Observada',descartada:'Descartada'}[r.estado]);
export const representacionVigente=(r:Representacion,hoy:string)=>r.estado==='revisada'&&!!r.valida_hasta&&r.valida_hasta>=hoy;
export function errorArchivoPdf(nombre:string,size:number,tipo:string){
 if(!/\.pdf$/i.test(nombre)||nombre.length>150||tipo!=='application/pdf')return 'Selecciona un archivo PDF (.pdf).';
 if(size<=0||size>LIMITE_PDF)return 'El PDF debe tener contenido y pesar como máximo 5 MB.';
 return null;
}
export function comprobarContenidoPdf(bytes:Uint8Array){
 if(bytes.length===0||bytes.length>LIMITE_PDF)throw new Error('El PDF supera el límite de 5 MB o está vacío.');
 const inicio=new TextDecoder('latin1').decode(bytes.subarray(0,8));
 const final=new TextDecoder('latin1').decode(bytes.subarray(Math.max(0,bytes.length-1024)));
 if(!/^%PDF-1\.[0-9]|^%PDF-2\.0/.test(inicio)||!final.includes('%%EOF'))throw new Error('El archivo no tiene un formato PDF reconocible.');
}
