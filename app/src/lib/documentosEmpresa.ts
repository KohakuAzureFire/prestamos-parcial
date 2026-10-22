export interface DocumentoEmpresa{tipo:string;referencia:string;campos?:Record<string,string>}
export const documentoVacio=():DocumentoEmpresa=>({tipo:'',referencia:''});
export const tiposPropiedad=[['partida','Copia literal de la partida de la empresa'],['constitucion','Escritura pública de constitución'],['acto','Acto constitutivo de SACS'],['matricula','Copia certificada del libro de matrícula de acciones']] as const;
export const tiposPoder=[['vigencia','Vigencia de poder'],['poder','Poder inscrito o partida registral'],['otro','Otro documento'],['anterior','Documento previamente registrado']] as const;
const todos=new Map<string,string>([...tiposPropiedad,...tiposPoder]);
export const ejemploReferencia=(tipo:string)=>tipo==='constitucion'?'Ej.: Escritura 245, 15/03/2026, Notaría Pérez':tipo==='acto'?'Ej.: Acto constitutivo SACS, partida 12345678, 15/03/2026':tipo==='matricula'?'Ej.: Libro 1, folio 12, asiento de titularidad':'Ej.: Partida 12345678, asiento A00001';
export function leerDocumento(texto?:string|null):DocumentoEmpresa{
 if(!texto)return documentoVacio();
 try{const d=JSON.parse(texto);if(d.v===1&&typeof d.tipo==='string'&&todos.has(d.tipo)&&typeof d.ref==='string'&&d.ref.length<=240)return recuperarCampos({tipo:d.tipo,referencia:d.ref});}catch{}
 return {tipo:'anterior',referencia:texto.length<=240?texto:''};
}
export const documentoCompleto=(d:DocumentoEmpresa)=>todos.has(d.tipo)&&d.referencia.trim().length>0&&d.referencia.trim().length<=240&&(!d.campos||camposCompletos(d));
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

// Los valores estructurados viven en el borrador. Se conserva el formato v1 al enviar.
export interface CampoReferencia {id:string;etiqueta:string;tipo:'numero'|'asiento'|'fecha'|'texto';ejemplo?:string;max:number}
export const camposReferencia:Record<string,readonly CampoReferencia[]>={
 partida:[{id:'partida',etiqueta:'N.º de partida',tipo:'numero',ejemplo:'12345678',max:12},{id:'asiento',etiqueta:'Asiento',tipo:'asiento',ejemplo:'A00001',max:10}],
 constitucion:[{id:'escritura',etiqueta:'N.º de escritura',tipo:'numero',ejemplo:'245',max:10},{id:'fecha',etiqueta:'Fecha de la escritura',tipo:'fecha',max:10},{id:'notaria',etiqueta:'Notaría',tipo:'texto',ejemplo:'Pérez',max:80}],
 acto:[{id:'partida',etiqueta:'N.º de partida',tipo:'numero',ejemplo:'12345678',max:12},{id:'fecha',etiqueta:'Fecha del acto constitutivo',tipo:'fecha',max:10}],
 matricula:[{id:'libro',etiqueta:'N.º de libro',tipo:'numero',ejemplo:'1',max:6},{id:'folio',etiqueta:'Folio',tipo:'numero',ejemplo:'12',max:6},{id:'asiento',etiqueta:'Asiento de titularidad',tipo:'asiento',ejemplo:'A00001',max:10}],
};
function fechaValida(v:string){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(v)||v.startsWith('0000'))return false;
 const d=new Date(v+'T00:00:00Z');return !Number.isNaN(d.getTime())&&d.toISOString().slice(0,10)===v;
}
/** Valida también valores parciales antes de aceptar escritura o pegado. No modifica identificadores. */
export function errorEntradaReferencia(c:CampoReferencia,v:string):string{
 if(v.length>c.max)return `Máximo ${c.max} ${c.tipo==='numero'?'dígitos':'caracteres'}.`;
 if(c.tipo==='numero'&&!/^\d*$/.test(v))return 'Ingresa solo números, sin espacios ni signos.';
 if(c.tipo==='asiento'&&!/^[A-Za-z0-9]*$/.test(v))return 'Ingresa solo letras y números, sin espacios ni signos.';
 if(c.tipo==='texto'&&!/^[\p{L}\p{M}\p{N} .,'’()&/ºª°-]*$/u.test(v))return 'Usa letras, números, espacios y signos habituales del nombre de la notaría.';
 if(c.tipo==='fecha'&&v&&!fechaValida(v))return 'Ingresa una fecha válida.';
 return '';
}
export function campoReferenciaValido(c:CampoReferencia,v:string){
 return !!v.trim()&&!errorEntradaReferencia(c,v)&&(c.tipo!=='texto'||/\p{L}/u.test(v));
}
export function ayudaCampoReferencia(c:CampoReferencia){
 return c.tipo==='numero'?`Solo números · máximo ${c.max} dígitos.`:
 c.tipo==='asiento'?`Letras y números · máximo ${c.max} caracteres.`:
 c.tipo==='fecha'?'Selecciona una fecha válida.':`Nombre de la notaría · máximo ${c.max} caracteres.`;
}
export function camposCompletos(d:DocumentoEmpresa){
 const esquema=camposReferencia[d.tipo];return !!esquema&&!!d.campos&&esquema.every(c=>campoReferenciaValido(c,d.campos![c.id]||''));
}
function fechaReferencia(v:string){return /^\d{4}-\d{2}-\d{2}$/.test(v)?v.split('-').reverse().join('/'):v;}
export function documentoConCampos(tipo:string,campos:Record<string,string>={}):DocumentoEmpresa{
 const c=Object.fromEntries((camposReferencia[tipo]||[]).map(f=>[f.id,campos[f.id]||'']));
 const ref=tipo==='partida'?`Partida ${c.partida}, asiento ${c.asiento}`:
 tipo==='constitucion'?`Escritura ${c.escritura}, ${fechaReferencia(c.fecha)}, Notaría ${c.notaria.trim()}`:
 tipo==='acto'?`Acto constitutivo SACS, partida ${c.partida}, ${fechaReferencia(c.fecha)}`:
 tipo==='matricula'?`Libro ${c.libro}, folio ${c.folio}, asiento ${c.asiento}`:'';
 return {tipo,campos:c,referencia:Object.values(c).some(v=>v.trim())?ref:''};
}
function recuperarCampos(d:DocumentoEmpresa):DocumentoEmpresa{
 let m:RegExpMatchArray|null=null;let c:Record<string,string>|null=null;
 if(d.tipo==='partida'&&(m=d.referencia.match(/^Partida (\d+), asiento ([A-Za-z0-9]+)$/)))c={partida:m[1],asiento:m[2]};
 if(d.tipo==='constitucion'&&(m=d.referencia.match(/^Escritura (\d+), (\d{2})\/(\d{2})\/(\d{4}), Notaría (.+)$/)))c={escritura:m[1],fecha:`${m[4]}-${m[3]}-${m[2]}`,notaria:m[5]};
 if(d.tipo==='acto'&&(m=d.referencia.match(/^Acto constitutivo SACS, partida (\d+), (\d{2})\/(\d{2})\/(\d{4})$/)))c={partida:m[1],fecha:`${m[4]}-${m[3]}-${m[2]}`};
 if(d.tipo==='matricula'&&(m=d.referencia.match(/^Libro (\d+), folio (\d+), asiento ([A-Za-z0-9]+)$/)))c={libro:m[1],folio:m[2],asiento:m[3]};
 if(c){const nuevo=documentoConCampos(d.tipo,c);if(camposCompletos(nuevo)&&nuevo.referencia===d.referencia)return nuevo;}
 return d;
}
