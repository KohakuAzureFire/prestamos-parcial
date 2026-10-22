'use client';
import {useState} from 'react';
import {createClient} from '@/lib/supabase/client';
import type {PersonaPrestamo} from '@/lib/ruc';
export default function PropietarioAusente({onVerificado,dniInicial='',limite=10000,dniFijo=false}:{dniInicial?:string;limite?:number;dniFijo?:boolean;onVerificado:(persona:PersonaPrestamo)=>void}){
 const [dni,setDni]=useState(dniInicial),[busy,setBusy]=useState(false),[error,setError]=useState('');
 async function consultar(){if(!/^\d{8}$/.test(dni)||busy)return;setBusy(true);setError('');try{
  const {data,error:fallo}=await createClient().rpc('resolver_cliente',{p_dni:dni});if(fallo)throw fallo;
  if(!data||(data.verificacion_identidad||data.situacion.verificacion)!=='aprobada'){
   onVerificado({...(data?.cliente||{dni,nombres:'Identidad por verificar',apellidos:''}),identidad_pendiente:true,situacion:data?.situacion||{capital_pendiente:0,capital_disponible:limite,limite,deuda_pendiente:0,atraso_desde:null,condicion_pago:'habilitado',conciliado:true,verificacion:'pendiente',elegible:false}});return;
  }
  if(data.cliente.tipo_cliente!=='natural')throw new Error('Selecciona una persona natural como propietario.');
  onVerificado({...data.cliente,situacion:data.situacion});
 }catch(e){setError((e as {message?:string}).message||'No se pudo consultar al propietario.');}finally{setBusy(false);}}
 return <section className="card verification-embedded"><h2>Identificar al propietario ausente</h2><p className="page-subtitle">Si su identidad no está verificada y vigente, podrás enviar la solicitud para completarla después. No se aprobará el préstamo hasta verificarlo presencialmente.</p>
 <form className="lookup-row" onSubmit={e=>{e.preventDefault();void consultar();}}><div className="form-group"><label className="form-label" htmlFor="dni-propietario-ausente">DNI del propietario</label><input id="dni-propietario-ausente" className="form-input" value={dni} inputMode="numeric" maxLength={8} disabled={busy} readOnly={dniFijo} onChange={e=>{setDni(e.target.value.replace(/\D/g,''));setError('');}}/></div><button className="btn btn-primary" disabled={busy||!/^\d{8}$/.test(dni)}>{busy?'Consultando…':'Consultar propietario'}</button></form>
 {error&&<p className="alert alert-warning" role="alert">{error}</p>}</section>;
}
