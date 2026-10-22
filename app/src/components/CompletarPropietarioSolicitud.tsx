'use client';
import {useState,useRef} from 'react';
import {useRouter} from 'next/navigation';
import VerificarCliente from './VerificarCliente';
import type {PersonaPrestamo} from '@/lib/ruc';
import type {SolicitudPrestamo} from '@/lib/solicitudes';
export default function CompletarPropietarioSolicitud({solicitud:s}:{solicitud:SolicitudPrestamo}){
 const [persona,setPersona]=useState<PersonaPrestamo|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const lock=useRef(false);const router=useRouter();
 async function completar(){
  if(!persona||lock.current)return;lock.current=true;setBusy(true);setError('');
  try{const r=await fetch('/api/solicitudes/'+s.id+'/propietario',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({version:s.version,propietario:persona})});const d=await r.json();if(!r.ok||!d.ok)throw new Error(d.mensaje||'No se pudo guardar la verificación.');router.refresh();}
  catch(e){setError(e instanceof Error?e.message:'No se pudo completar.');}finally{lock.current=false;setBusy(false);}
 }
 return <section className="card"><h2>Completar verificación del propietario</h2><p>Cuando acuda el propietario, revisa su DNI original y verifica su identidad. Se conservarán esta solicitud y el certificado presentado. Esta acción no aprueba el préstamo.</p>
 {!persona?<VerificarCliente enBorrador forzarRevision dniFijo dniInicial={s.expediente.propietario.dni} etiqueta="Propietario pendiente de verificación" onVerificado={setPersona}/>:<><p>{persona.nombres} {persona.apellidos} · DNI {persona.dni}</p><div className="action-group"><button className="btn btn-secondary" disabled={busy} onClick={()=>setPersona(null)}>Revisar verificación</button><button className="btn btn-primary" disabled={busy} onClick={()=>void completar()}>{busy?'Guardando…':'Guardar verificación del propietario'}</button></div></>}
 {error&&<p className="alert alert-error" role="alert">{error}</p>}</section>;
}
