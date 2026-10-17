export interface DocumentoEmpresa{tipo:string;referencia:string}
export const documentoVacio=():DocumentoEmpresa=>({tipo:'',referencia:''});
export const tiposPropiedad=[['partida','Partida registral'],['constitucion','Escritura o acto constitutivo'],['designacion','Designación documentada del responsable'],['otro','Otro documento'],['anterior','Documento previamente registrado']] as const;
export const tiposPoder=[['vigencia','Vigencia de poder'],['poder','Poder inscrito o partida registral'],['otro','Otro documento'],['anterior','Documento previamente registrado']] as const;
const todos=new Map<string,string>([...tiposPropiedad,...tiposPoder]);
export function leerDocumento(texto?:string|null):DocumentoEmpresa{
 if(!texto)return documentoVacio();
 try{const d=JSON.parse(texto);if(d.v===1&&typeof d.tipo==='string'&&todos.has(d.tipo)&&typeof d.ref==='string'&&d.ref.length<=240)return {tipo:d.tipo,referencia:d.ref};}catch{}
 return {tipo:'anterior',referencia:texto.length<=240?texto:''};
}
export const documentoCompleto=(d:DocumentoEmpresa)=>todos.has(d.tipo)&&d.referencia.trim().length>0&&d.referencia.trim().length<=240;
export function guardarDocumento(d:DocumentoEmpresa,datos:{dni:string;presente:boolean}){
 if(!documentoCompleto(d))throw new Error('Selecciona el documento e ingresa su referencia.');
 const texto=JSON.stringify({v:1,tipo:d.tipo,ref:d.referencia.trim(),dni:datos.dni,presente:datos.presente});
 if(texto.length>500)throw new Error('La referencia supera el espacio disponible. Usa una referencia más breve.');
 return texto;
}
export function resumenDocumento(texto?:string|null){
 if(!texto)return '';
 try{const d=JSON.parse(texto);if(d.v===1&&typeof d.ref==='string')return (todos.get(d.tipo)||'Documento')+': '+d.ref+(typeof d.presente==='boolean'?' · '+(d.presente?'Persona presente':'Persona ausente'):'');}catch{}
 return texto;
}
export interface RegistroEmpresa{propietario_dni:string;representante_dni:string;evidencia_propiedad:string|null;evidencia_poder:string|null}
