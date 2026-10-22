import PizZip from 'pizzip';
export interface IdentidadContrato {nombres:string;apellidos:string;dni?:string|null;ruc?:string|null;razon_social?:string|null;propietario?:{dni:string;nombre:string};representante?:{dni:string;nombre:string}|null}
export interface DatosContrato {id:string;fecha_prestamo:string;monto:number;plazo_meses:number;identidad_contrato?:IdentidadContrato|null;clientes:IdentidadContrato;agencias:{nombre:string};cuotas:{numero_cuota:number;fecha_vencimiento:string;cuota_total:number;interes:number}[]}
export const escapar=(x:string)=>x.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]!));
const dinero=(n:number)=>'S/ '+Number(n).toLocaleString('es-PE',{minimumFractionDigits:2,maximumFractionDigits:2});
const fecha=(s:string)=>s.slice(0,10).split('-').reverse().join('/');
export function camposContrato(p:DatosContrato):Record<string,string>{
 const copia=p.identidad_contrato;
 const c=copia&&(copia.nombres||copia.razon_social)?copia:p.clientes;
 const empresa=!!c.ruc?.startsWith('20');
 if(empresa&&(c!==copia||!copia?.ruc||!copia.representante?.nombre?.trim()||!/^\d{8}$/.test(copia.representante.dni)))throw new Error('El préstamo no conserva los datos completos del representante para el contrato. Revisa el expediente antes de emitirlo.');
 const cuotas=[...p.cuotas].sort((a,b)=>a.numero_cuota-b.numero_cuota);
 const cliente=empresa?(c.razon_social?.trim()||[c.nombres,c.apellidos].filter(Boolean).join(' ')):[c.nombres,c.apellidos].filter(Boolean).join(' ');
 const firmante=c.representante?.nombre||cliente;const dniFirma=c.representante?.dni||c.dni;
 return {CODIGO:'PR-'+p.id.slice(0,8).toUpperCase(),CLIENTE:cliente,DOCUMENTO:c.ruc?'RUC Nº '+c.ruc:'DNI Nº '+c.dni,
 REPRESENTACION:c.representante?', representada por '+firmante+', con DNI Nº '+dniFirma:'',DOCUMENTO_FIRMA:dniFirma?'DNI: '+dniFirma:'Documento: '+(c.ruc||''),
 PROPIETARIO:c.propietario?c.propietario.nombre+' · DNI '+c.propietario.dni:cliente+' · DNI '+(c.dni||'—'),FIRMANTE:firmante+(dniFirma?' · DNI '+dniFirma:''),CALIDAD_FIRMANTE:empresa?'Representante de EL CLIENTE':'EL CLIENTE',
 AGENCIA:p.agencias.nombre.replace(/^Agencia\s+/i,''),FECHA:fecha(p.fecha_prestamo),FECHA_LARGA:new Date(p.fecha_prestamo.slice(0,10)+'T12:00:00Z').toLocaleDateString('es-PE',{day:'numeric',month:'long',year:'numeric',timeZone:'America/Lima'}),MONTO:dinero(p.monto),PLAZO:String(p.plazo_meses),
 INTERES_TOTAL:dinero(cuotas.reduce((s,c)=>s+Number(c.interes),0)),TOTAL:dinero(cuotas.reduce((s,c)=>s+Number(c.cuota_total),0)),PRIMER_VENCIMIENTO:cuotas[0]?fecha(cuotas[0].fecha_vencimiento):'—',ULTIMO_VENCIMIENTO:cuotas.length?fecha(cuotas.at(-1)!.fecha_vencimiento):'—'};
}
export function completarTexto(texto:string,campos:Record<string,string>){return texto.replace(/\{\{([A-Z_]+)\}\}/g,(_,clave)=>campos[clave]??'');}
export function generarContratoDocx(template:Buffer,p:DatosContrato){const zip=new PizZip(template);const campos=camposContrato(p);for(const name of Object.keys(zip.files).filter(n=>/^word\/.*\.xml$/.test(n))){const xml=zip.file(name)!.asText();zip.file(name,xml.replace(/\{\{([A-Z_]+)\}\}/g,(_,clave)=>escapar(campos[clave]??'')));}return zip.generate({type:'nodebuffer',compression:'DEFLATE'});}
