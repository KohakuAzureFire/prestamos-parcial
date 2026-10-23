export interface RepresentanteApi {tipo_documento:string;documento:string;nombre:string;cargo:string;desde:string;dni_completo:boolean}
export interface ConsultaRepresentantes {ruc:string;representantes:RepresentanteApi[];payload:string;firma:string}
export interface SeleccionRepresentante {payload:string;firma:string;indice:number}
export function normalizarRepresentantes(respuesta:unknown):RepresentanteApi[]{
 const r=respuesta as {success?:unknown;data?:unknown};
 if(r?.success!==true||!Array.isArray(r.data)||r.data.length>100)throw new Error('API Perú devolvió una respuesta no disponible o incompleta.');
 return r.data.map((item:unknown)=>{
  const d=item as Record<string,unknown>;const t=(v:unknown)=>typeof v==='string'?v.trim():'';
  const tipo=t(d?.tipo_de_documento).toUpperCase(),documento=t(d?.numero_de_documento),nombre=t(d?.nombre);
  if(!tipo||!documento||!nombre||documento.length>40||nombre.length>240||t(d.cargo).length>160||t(d.fecha_desde).length>40)throw new Error('API Perú devolvió un representante incompleto. Reintenta la consulta.');
  return {tipo_documento:tipo,documento,nombre,cargo:t(d.cargo),desde:t(d.fecha_desde),dni_completo:tipo.toUpperCase()==='DNI'&&/^\d{8}$/.test(documento)};
 });
}
