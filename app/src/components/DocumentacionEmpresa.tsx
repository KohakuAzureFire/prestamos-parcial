'use client';
import {useState} from 'react';
import {tiposPropiedad,tiposPoder,camposReferencia,documentoConCampos,campoReferenciaValido,errorEntradaReferencia,ayudaCampoReferencia,type DocumentoEmpresa} from '@/lib/documentosEmpresa';
interface Props{soloPropiedad?:boolean;propiedad:DocumentoEmpresa;poder:DocumentoEmpresa;misma:boolean;revisionPropiedad:boolean;revisionPoder:boolean;onPropiedad:(d:DocumentoEmpresa)=>void;onPoder:(d:DocumentoEmpresa)=>void;onMisma:(v:boolean)=>void;onRevisionPropiedad:(v:boolean)=>void;onRevisionPoder:(v:boolean)=>void;recuperados:boolean}
export default function DocumentacionEmpresa(p:Props){
 return <section className="card company-documentation"><h2>Documentación de la empresa</h2><p className="page-subtitle">{p.recuperados?'Revisa las referencias recuperadas y confirma su validez para esta operación. Actualiza solo lo que cambió.':'Selecciona el documento revisado y completa sus datos. La referencia se generará automáticamente.'}</p>
 <fieldset><legend>Propiedad y designación</legend><div className="form-group"><label className="form-label" htmlFor="tipo-propiedad">Documento que sustenta el vínculo</label><select id="tipo-propiedad" className="form-input" value={p.propiedad.tipo} onChange={e=>p.onPropiedad(documentoConCampos(e.target.value))}><option value="">Selecciona un documento</option>{tiposPropiedad.map(([v,t])=><option value={v} key={v}>{t}</option>)}</select></div>
 <ReferenciaPropiedad key={p.propiedad.tipo} documento={p.propiedad} onChange={p.onPropiedad}/>
 <label className="form-checkbox"><input id="revision-propiedad" type="checkbox" checked={p.revisionPropiedad} onChange={e=>p.onRevisionPropiedad(e.target.checked)}/>Revisé el documento y la designación del propietario para el límite global.</label></fieldset>
 {!p.soloPropiedad&&<fieldset><legend>Facultades para firmar</legend><label className="form-checkbox"><input id="misma-referencia" type="checkbox" checked={p.misma} onChange={e=>p.onMisma(e.target.checked)}/>El mismo documento acredita las facultades del representante.</label>
 {p.misma?<p className="shared-reference" role="status">Se usará el documento y la referencia de propiedad. Comprueba que también acredita las facultades para contratar el préstamo.</p>:<div className="document-reference-row"><div className="form-group"><label className="form-label" htmlFor="tipo-poder">Documento de representación</label><select id="tipo-poder" className="form-input" value={p.poder.tipo} onChange={e=>p.onPoder({...p.poder,tipo:e.target.value})}><option value="">Selecciona un documento</option>{tiposPoder.map(([v,t])=><option value={v} key={v}>{t}</option>)}</select></div><div className="form-group"><label className="form-label" htmlFor="referencia-poder">Referencia de representación</label><input id="referencia-poder" className="form-input" value={p.poder.referencia} maxLength={240} placeholder="Ej.: Certificado o partida y asiento" onChange={e=>p.onPoder({...p.poder,referencia:e.target.value})}/></div></div>}
 <label className="form-checkbox"><input id="revision-poder" type="checkbox" checked={p.revisionPoder} onChange={e=>p.onRevisionPoder(e.target.checked)}/>Revisé las facultades del representante para contratar y firmar este préstamo.</label></fieldset>}</section>;
}

function ReferenciaPropiedad({documento:d,onChange}:{documento:DocumentoEmpresa;onChange:(d:DocumentoEmpresa)=>void}){
 const [avisos,setAvisos]=useState<Record<string,string>>({});
 const esquema=camposReferencia[d.tipo];
 if(!esquema)return null;
 if(!d.campos&&d.referencia)return <div className="saved-document-reference"><p><strong>Referencia registrada:</strong> {d.referencia}</p><p className="page-subtitle">Se conservará esta referencia. Para corregirla, completa los campos del documento.</p><button type="button" className="btn btn-sm btn-secondary" onClick={()=>onChange(documentoConCampos(d.tipo))}>Corregir datos del documento</button></div>;
 const campos=d.campos||{};
 function aceptar(c:typeof esquema[number],valor:string){
  const error=errorEntradaReferencia(c,valor);
  setAvisos(actual=>({...actual,[c.id]:error}));
  if(!error)onChange(documentoConCampos(d.tipo,{...campos,[c.id]:c.tipo==='asiento'?valor.toUpperCase():valor}));
 }
 return <><div className="document-fields-grid">{esquema.map(c=>{
  const valor=campos[c.id]||'';
  const error=avisos[c.id]||(valor&&!campoReferenciaValido(c,valor)?(c.tipo==='texto'?'Ingresa el nombre de la notaría.':'Revisa este dato.'):'');
  const ayuda='ayuda-documento-'+c.id;const errorId='error-documento-'+c.id;
  return <div className="form-group" key={c.id}><label className="form-label" htmlFor={'documento-'+c.id}>{c.etiqueta}</label><input id={'documento-'+c.id} className="form-input" type={c.tipo==='fecha'?'date':'text'} inputMode={c.tipo==='numero'?'numeric':undefined} maxLength={c.max} min={c.tipo==='fecha'?'0001-01-01':undefined} max={c.tipo==='fecha'?'9999-12-31':undefined} required value={valor} placeholder={c.ejemplo} aria-invalid={!!error} aria-describedby={ayuda+(error?' '+errorId:'')} onChange={e=>aceptar(c,e.target.value)} onPaste={e=>{
   if(c.tipo==='fecha')return;
   e.preventDefault();const entrada=e.currentTarget;const pegado=e.clipboardData.getData('text');
   aceptar(c,valor.slice(0,entrada.selectionStart??valor.length)+pegado+valor.slice(entrada.selectionEnd??valor.length));
  }}/><small id={ayuda}>{ayudaCampoReferencia(c)}</small>{error&&<small id={errorId} className="form-error" role="status">{error}</small>}</div>;
 })}</div>{d.referencia&&<p className="generated-document-reference" role="status"><strong>Referencia generada:</strong> {d.referencia}</p>}</>;
}
