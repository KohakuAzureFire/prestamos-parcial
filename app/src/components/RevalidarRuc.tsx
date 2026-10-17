'use client';
import {useState,useEffect,useCallback,useRef} from 'react';
import Link from 'next/link';import {useRouter} from 'next/navigation';
import {createClient} from '@/lib/supabase/client';import type {ConsultaRuc} from '@/lib/ruc';
import {camposRuc,textoRuc,fechaRevision,type DatosRucGuardados} from '@/lib/actualizacionRuc';

export default function RevalidarRuc({clienteId,ruc,guardados}:{clienteId:string;ruc:string;guardados:DatosRucGuardados}){
 const [dato,setDato]=useState<ConsultaRuc|null>(null),[error,setError]=useState(''),[busy,setBusy]=useState(true),[guardando,setGuardando]=useState(false);
 const enviando=useRef(false);const router=useRouter();
 const consultar=useCallback(async(signal?:AbortSignal)=>{
  setBusy(true);setError('');setDato(null);
  try{const r=await fetch('/api/sunat/ruc?numero='+ruc,{cache:'no-store',signal});const d=await r.json();if(!r.ok||!d.ok)throw new Error(d.mensaje||'Consulta SUNAT no disponible. Reintenta.');if(!signal?.aborted)setDato(d);}
  catch(e){if(!signal?.aborted)setError(e instanceof Error?e.message:'Consulta SUNAT no disponible. Reintenta.');}
  finally{if(!signal?.aborted)setBusy(false);}
 },[ruc]);
 useEffect(()=>{const controller=new AbortController();queueMicrotask(()=>{if(!controller.signal.aborted)void consultar(controller.signal);});return()=>controller.abort();},[consultar]);
 const cambios=dato?camposRuc.filter(c=>textoRuc(guardados[c.guardado])!==textoRuc(dato[c.consulta])):[];
 async function guardar(){
  if(!dato||enviando.current)return;enviando.current=true;setGuardando(true);setError('');
  try{const {error}=await createClient().rpc('revalidar_datos_ruc',{p_cliente:clienteId,p_payload:dato.payload,p_firma:dato.firma});if(error)throw error;router.push('/dashboard/clientes/'+clienteId+'?actualizado=ruc');router.refresh();}
  catch(e){setError((e as {message?:string}).message||'No se pudieron guardar los datos.');enviando.current=false;setGuardando(false);}
 }
 return <div className="sunat-update animate-fade-in"><div className="page-heading"><div><h1>Actualizar datos SUNAT</h1><p>Consulta el estado actual del RUC y revisa los cambios antes de guardarlos.</p></div></div>
 <section className="card"><div className="section-heading"><h2>RUC {ruc}</h2><p className="page-subtitle">Última consulta guardada: {fechaRevision(guardados.ruc_consultado_at)}</p></div>
 {busy&&<p role="status">Consultando SUNAT…</p>}
 {error&&<p className="alert alert-error" role="alert">{error}</p>}
 {!busy&&!dato&&error&&<p className="page-subtitle">La consulta no pudo completarse. No se han cambiado los datos ni la aprobación del cliente.</p>}
 {dato&&<><p className="alert alert-info" role="status">{cambios.length?`${cambios.length} ${cambios.length===1?'dato cambió':'datos cambiaron'} respecto de la ficha guardada.`:'Sin cambios en los datos SUNAT. Puedes registrar esta nueva consulta para actualizar su fecha e historial.'}</p>
 <dl className="sunat-fields">{camposRuc.map(c=>{
  const actual=textoRuc(dato[c.consulta]);const anterior=textoRuc(guardados[c.guardado]);const cambio=actual!==anterior;
  return <div key={c.consulta} className={c.consulta==='direccion'?'sunat-address':undefined}><dt>{c.etiqueta}{cambio&&<span className="badge badge-info">Cambió</span>}</dt><dd>{actual||'No informado por SUNAT'}</dd>{cambio&&<dd className="sunat-previous">Antes: {anterior||'Sin dato registrado'}</dd>}</div>;
 })}</dl>
 {(dato.estado!=='ACTIVO'||dato.condicion!=='HABIDO')&&<p className="alert alert-warning">RUC observado: no cumple ACTIVO y HABIDO para un nuevo préstamo por este RUC. Puedes guardar su estado actual; los pagos existentes siguen disponibles.</p>}
 <p className="page-subtitle">Los datos consultados no se editan manualmente. Esta actualización no revalida el DNI ni las facultades del representante.</p></>}
 <div className="loan-actions"><Link className="btn btn-secondary" href={'/dashboard/clientes/'+clienteId}>Volver a la ficha</Link>{!busy&&!dato&&error&&<button className="btn btn-secondary" disabled={guardando} onClick={()=>void consultar()}>Reintentar consulta</button>}{dato&&<button id="guardar-ruc" className="btn btn-primary" disabled={busy||guardando} onClick={guardar}>{guardando?'Guardando…':cambios.length?'Guardar cambios SUNAT':'Registrar consulta SUNAT'}</button>}</div>
 </section></div>;
}
