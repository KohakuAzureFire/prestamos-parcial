'use client';
import {useState,useEffect,useCallback,useRef} from 'react';
import Link from 'next/link';
import {createClient} from '@/lib/supabase/client';
import type {ConsultaRuc} from '@/lib/ruc';
import {fechaPeru} from '@/lib/operaciones';
import {BUCKET_CERTIFICADOS,errorArchivoPdf,estadoRepresentacion,representacionVigente,type Representacion} from '@/lib/representaciones';
interface Props {consulta:ConsultaRuc;propietario:string;representante:string;onRevision:(r:Representacion|null)=>void}
export default function CertificadoRepresentacion({consulta,propietario,representante,onRevision}:Props){
 const [solicitudes,setSolicitudes]=useState<Representacion[]>([]),[archivo,setArchivo]=useState<File|null>(null),[emision,setEmision]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false),[cargando,setCargando]=useState(true),[pendiente,setPendiente]=useState<Representacion|null>(null);
 const enviando=useRef(false);const notificar=onRevision;
 const ultima=solicitudes[0];const vigente=ultima&&representacionVigente(ultima,fechaPeru());
 const cargar=useCallback(async()=>{
  setCargando(true);setError('');
  try{const s=createClient();const {data:{user}}=await s.auth.getUser();if(!user)throw new Error('Vuelve a iniciar sesión.');
   const {data:a,error:ea}=await s.from('asesores').select('agencia_id').eq('id',user.id).single();if(ea||!a)throw new Error('No se pudo identificar la agencia.');
   const {data,error:er}=await s.from('representaciones_resumen').select('*').eq('ruc',consulta.ruc).eq('propietario_dni',propietario).eq('representante_dni',representante).eq('agencia_id',a.agencia_id).in('estado',['pendiente','revisada','observada']).order('created_at',{ascending:false}).order('id',{ascending:false}).limit(10);
   if(er)throw new Error('No se pudo consultar la representación. Comprueba que esté activada la actualización.');
   const lista=(data||[]) as Representacion[];setSolicitudes(lista);notificar(lista[0]&&representacionVigente(lista[0],fechaPeru())?lista[0]:null);
  }catch(e){setError(e instanceof Error?e.message:'No se pudo consultar.');notificar(null);}finally{setCargando(false);}
 },[consulta.ruc,propietario,representante,notificar]);
 useEffect(()=>{let activo=true;queueMicrotask(()=>{if(activo)void cargar();});return()=>{activo=false;};},[cargar]);
 async function verificar(r:Representacion){
  const res=await fetch('/api/representaciones/'+r.id+'/archivo',{method:'POST'});const d=await res.json();if(!res.ok||!d.ok)throw new Error(d.mensaje||d.error||'No se pudo verificar la carga.');
  setPendiente(null);setArchivo(null);setEmision('');await cargar();
 }
 async function subir(){
  if(enviando.current||!archivo)return;const fallo=errorArchivoPdf(archivo.name,archivo.size,archivo.type);if(fallo){setError(fallo);return;}
  if(!emision||emision>fechaPeru()){setError('Indica la fecha de emisión del certificado, hasta hoy.');return;}
  enviando.current=true;setBusy(true);setError('');
  try{const s=createClient();const {data:r,error:er}=await s.rpc('reservar_representacion',{p_consulta:consulta,p_propietario:propietario,p_representante:representante,p_nombre:archivo.name,p_bytes:archivo.size,p_emision:emision});if(er)throw new Error(er.message);
   const solicitud=r as Representacion;const {error:eu}=await s.storage.from(BUCKET_CERTIFICADOS).upload(solicitud.archivo_ruta,archivo,{contentType:'application/pdf',upsert:false});
   if(eu){await s.rpc('descartar_representacion',{p_id:solicitud.id});throw new Error('No se pudo subir el PDF. Revisa tu conexión y vuelve a intentarlo.');}
   setPendiente(solicitud);await verificar(solicitud);
  }catch(e){setError(e instanceof Error?e.message:'No se pudo guardar el documento.');}finally{enviando.current=false;setBusy(false);}
 }
 async function reintentar(){if(!pendiente||enviando.current)return;enviando.current=true;setBusy(true);setError('');try{await verificar(pendiente);}catch(e){setError(e instanceof Error?e.message:'No se pudo verificar.');}finally{enviando.current=false;setBusy(false);}}
 return <section className="card representation-card"><div className="section-heading"><h2>Representación de la empresa</h2><Link className="text-link" href="/dashboard/representaciones">Ver solicitudes</Link></div>
 <p className="page-subtitle">El certificado acredita la representación que revisará un asesor autorizado. No aprueba el crédito ni cambia el límite del propietario.</p>
 {cargando?<p role="status">Consultando representación…</p>:ultima&&<div className={'alert '+(vigente?'alert-success':'alert-warning')} role="status"><strong>{estadoRepresentacion(ultima,fechaPeru())}</strong>{ultima.observacion&&<p>{ultima.observacion}</p>}{vigente&&<p>Revisión hasta {ultima.valida_hasta?.split('-').reverse().join('/')} · Importe máximo S/ {Number(ultima.monto_maximo).toFixed(2)}.</p>}<Link className="text-link" href={'/dashboard/representaciones/'+ultima.id}>Ver documento y revisión</Link></div>}
 {error&&<p className="alert alert-error" role="alert">{error}</p>}
 {!cargando&&<button type="button" className="btn btn-sm btn-secondary" disabled={busy} onClick={()=>void cargar()}>Actualizar estado de revisión</button>}
 <details className="representation-upload" open={!ultima&&!cargando}><summary>{ultima?'Presentar un nuevo certificado':'Adjuntar certificado de vigencia de poder'}</summary><p className="page-subtitle">Solo PDF, hasta 5 MB. El documento se guarda de forma privada. Una nueva presentación reemplaza la revisión anterior para futuras operaciones.</p>
 <div className="evidence-grid"><div className="form-group"><label className="form-label" htmlFor="certificado-pdf">Certificado PDF</label><input className="form-input" id="certificado-pdf" type="file" accept=".pdf,application/pdf" disabled={busy||!!pendiente} onChange={e=>{const f=e.target.files?.[0]||null;setArchivo(f);setError(f?errorArchivoPdf(f.name,f.size,f.type)||'':'');}}/></div><div className="form-group"><label className="form-label" htmlFor="certificado-emision">Fecha de emisión</label><input className="form-input" id="certificado-emision" type="date" max={fechaPeru()} disabled={busy||!!pendiente} value={emision} onChange={e=>setEmision(e.target.value)}/></div></div>
 <p className="page-subtitle">Guardar la solicitud no registra al cliente ni genera un préstamo. Para retomarla, abre su detalle y vuelve a comprobar los datos vigentes.</p>
 <div className="loan-actions">{pendiente?<button type="button" className="btn btn-primary" disabled={busy} onClick={()=>void reintentar()}>{busy?'Verificando…':'Reintentar verificación del PDF'}</button>:<button type="button" className="btn btn-primary" disabled={busy||!archivo||!emision||!!errorArchivoPdf(archivo?.name||'',archivo?.size||0,archivo?.type||'')} onClick={()=>void subir()}>{busy?'Guardando…':'Enviar a revisión'}</button>}</div></details>
 </section>;
}
