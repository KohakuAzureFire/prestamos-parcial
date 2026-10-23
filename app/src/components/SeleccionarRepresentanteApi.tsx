'use client';
import {useRef,useState} from 'react';
import type {ConsultaRepresentantes,RepresentanteApi,SeleccionRepresentante} from '@/lib/representantesApi';
export default function SeleccionarRepresentanteApi({ruc,inicial,onSeleccion}:{ruc:string;inicial:SeleccionRepresentante|null;onSeleccion:(seleccion:SeleccionRepresentante|null,persona:RepresentanteApi|null)=>void}){
 const [consulta,setConsulta]=useState<ConsultaRepresentantes|null>(()=>{if(!inicial)return null;try{const d=JSON.parse(inicial.payload);return {...d,payload:inicial.payload,firma:inicial.firma};}catch{return null;}}),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const elegido=inicial?.indice??null;const enviando=useRef(false);
 async function consultar(){
  if(enviando.current)return;enviando.current=true;setBusy(true);setError('');setConsulta(null);onSeleccion(null,null);
  try{const r=await fetch('/api/sunat/representantes',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ruc})});const d=await r.json();if(!r.ok||!d.ok)throw new Error(d.mensaje||'No se pudo consultar representantes.');setConsulta(d);}
  catch(e){setError(e instanceof Error?e.message:'No se pudo consultar.');}finally{enviando.current=false;setBusy(false);}
 }
 return <section className="card"><div className="company-identity-heading"><h2>Representantes registrados</h2><button type="button" className="btn btn-secondary" disabled={busy} onClick={()=>void consultar()}>{busy?'Consultando…':consulta?'Volver a consultar':'Consultar en API Perú'}</button></div>
 <p className="page-subtitle">Consulta opcional para recuperar al firmante. Selecciona a la persona que está presente; después verifica su DNI. La consulta no identifica al propietario ni acredita facultades para este préstamo.</p>
 {error&&<p className="alert alert-info" role="status">{error}</p>}
 {consulta&&consulta.representantes.length===0&&<p role="status">El proveedor no devolvió representantes. Puedes continuar con la revisión documental; esto no demuestra ausencia de representación.</p>}
 {consulta&&consulta.representantes.length>0&&<fieldset className="api-representantes"><legend>Selecciona al firmante de esta atención</legend>{consulta.representantes.map((p,i)=><label className="api-representante" key={i}><input type="radio" name="representante-api" checked={elegido===i} disabled={busy||p.tipo_documento.toUpperCase()!=='DNI'} onChange={()=>{onSeleccion({payload:consulta.payload,firma:consulta.firma,indice:i},p);}}/><span><strong>{p.nombre}</strong><small>{p.tipo_documento} {p.documento} · {p.cargo}{p.desde?' · Desde '+p.desde:''}</small><small>{p.dni_completo?'DNI completo disponible para contrastar.':p.tipo_documento.toUpperCase()==='DNI'?'Datos parciales: ingresa el DNI completo y contrasta el documento. No se afirma coincidencia automática.':'Documento fuera del alcance DNI de este sistema.'}</small></span></label>)}</fieldset>}
 {elegido!==null&&<button type="button" className="identity-correction" onClick={()=>{onSeleccion(null,null);}}>Quitar selección de API</button>}
 <small className="page-subtitle">Solo consulta al pulsar el botón. Los resultados quedan en el borrador hasta enviar la solicitud. El certificado de vigencia de poder continúa en Documentación.</small></section>;
}
