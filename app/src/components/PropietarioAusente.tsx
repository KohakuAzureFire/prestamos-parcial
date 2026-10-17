'use client';
import {useState} from 'react';
import {createClient} from '@/lib/supabase/client';
import type {PersonaPrestamo} from '@/lib/ruc';
export default function PropietarioAusente({onVerificado,dniInicial=''}:{dniInicial?:string;onVerificado:(persona:PersonaPrestamo)=>void}){
 const [dni,setDni]=useState(dniInicial),[busy,setBusy]=useState(false),[error,setError]=useState('');
 async function consultar(){if(!/^\d{8}$/.test(dni)||busy)return;setBusy(true);setError('');try{
  const {data,error:fallo}=await createClient().rpc('resolver_cliente',{p_dni:dni});if(fallo)throw fallo;
  if(!data||(data.verificacion_identidad||data.situacion.verificacion)!=='aprobada')throw new Error('El propietario ausente necesita una identidad previamente verificada y vigente. La solicitud queda pendiente de revisión documental; este formulario no crea ni revalida una identidad presencial.');
  if(data.cliente.tipo_cliente!=='natural')throw new Error('Selecciona una persona natural como propietario.');
  onVerificado({...data.cliente,situacion:data.situacion});
 }catch(e){setError((e as {message?:string}).message||'No se pudo consultar al propietario.');}finally{setBusy(false);}}
 return <section className="card verification-embedded"><h2>Identificar al propietario ausente</h2><p className="page-subtitle">Se reutiliza su identidad verificada y vigente. No se registra su presencia ni una nueva revisión del DNI original.</p>
 <form className="lookup-row" onSubmit={e=>{e.preventDefault();void consultar();}}><div className="form-group"><label className="form-label" htmlFor="dni-propietario-ausente">DNI del propietario</label><input id="dni-propietario-ausente" className="form-input" value={dni} inputMode="numeric" maxLength={8} disabled={busy} onChange={e=>{setDni(e.target.value.replace(/\D/g,''));setError('');}}/></div><button className="btn btn-primary" disabled={busy||!/^\d{8}$/.test(dni)}>{busy?'Consultando…':'Consultar propietario'}</button></form>
 {error&&<p className="alert alert-warning" role="alert">{error}</p>}</section>;
}
