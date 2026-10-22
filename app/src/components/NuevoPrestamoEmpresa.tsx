'use client';
import {useState,useRef} from 'react';
import type {ConsultaRuc,PersonaPrestamo,BorradorRuc} from '@/lib/ruc';
import type {RegistroEmpresa} from '@/lib/documentosEmpresa';
import {documentoVacio,documentoCompleto,leerDocumento,guardarDocumento} from '@/lib/documentosEmpresa';
import type {SolicitudPrestamo} from '@/lib/solicitudes';
import {fechaPeru} from '@/lib/operaciones';
import {BUCKET_CERTIFICADOS,errorArchivoPdf,comprobarContenidoPdf,type Representacion} from '@/lib/representaciones';
import {createClient} from '@/lib/supabase/client';
import {useBorradorGuard} from '@/lib/useBorradorGuard';
import VerificarCliente from './VerificarCliente';
import PropietarioAusente from './PropietarioAusente';
import DocumentacionEmpresa from './DocumentacionEmpresa';
import FormularioPrestamo from './FormularioPrestamo';

export default function NuevoPrestamoEmpresa({consulta,registro,solicitudInicial,agencia,asesor,limite,onPaso}:{consulta:ConsultaRuc;registro:RegistroEmpresa|null;solicitudInicial?:SolicitudPrestamo;agencia:string;asesor:string;limite:number;onPaso:(documentos:boolean)=>void}){
 const [paso,setPaso]=useState(1),[propietario,setPropietario]=useState<PersonaPrestamo|null>(null),[representante,setRepresentante]=useState<PersonaPrestamo|null>(null);
 const [mismo,setMismo]=useState((solicitudInicial?.expediente.propietario.dni||registro?.propietario_dni)===(solicitudInicial?.expediente.representante.dni||registro?.representante_dni));
 const [presente,setPresente]=useState(true),[presencia,setPresencia]=useState(false),[error,setError]=useState('');
 const [propiedad,setPropiedad]=useState(()=>leerDocumento(solicitudInicial?.expediente.evidencia_propiedad||registro?.evidencia_propiedad)),[revisada,setRevisada]=useState(false);
 const [archivo,setArchivo]=useState<File|null>(null),[emision,setEmision]=useState('');
 const [condiciones,setCondiciones]=useState({monto:solicitudInicial?Number(solicitudInicial.monto).toFixed(2):'',plazo:String(solicitudInicial?.plazo_meses||0)});
 const carga=useRef<{clave:string;registro:Representacion;datos:BorradorRuc;monto:number;meses:number;subido:boolean}|null>(null);
 const firmante=mismo?propietario:representante;
 const propietarioFijo=registro?.propietario_dni||solicitudInicial?.expediente.propietario.dni;
 const dniRep=solicitudInicial?.expediente.representante.dni||registro?.representante_dni||'';
 const propietarioValido=!!propietario&&(!propietarioFijo||propietario.dni===propietarioFijo);
 const identificado=propietarioValido&&!!firmante&&(presencia||!!firmante.borrador?.evidencia.no_fallecido);
 const docValido=tiposPermitidos(propiedad.tipo)&&documentoCompleto(propiedad)&&revisada&&!!archivo&&!!emision&&emision<=fechaPeru()&&!errorArchivoPdf(archivo.name,archivo.size,archivo.type);
 useBorradorGuard(paso<3,paso<3);
 function ir(n:number){if(carga.current){void createClient().rpc('descartar_representacion',{p_id:carga.current.registro.id});carga.current=null;}setError('');setPaso(n);onPaso(n>1);window.scrollTo({top:0,behavior:'smooth'});}
 function aceptarPropietario(p:PersonaPrestamo){if(propietarioFijo&&p.dni!==propietarioFijo){setError('La empresa ya está vinculada al DNI '+propietarioFijo+'. No se puede reasignar su propietario desde Nuevo préstamo.');return;}setPropietario(p);if(!mismo&&representante?.dni===p.dni)setRepresentante(null);setPresencia(false);}
 function aceptarRepresentante(p:PersonaPrestamo){if(p.dni===propietario?.dni){setError('Si firma el propietario, selecciona esa opción en Atención de la empresa.');return;}setRepresentante(p);setPresencia(false);}
 function corregir(rol:'propietario'|'representante'){
  if(rol==='propietario')setPropietario(null);else setRepresentante(null);
  setPresencia(false);setRevisada(false);setArchivo(null);setEmision('');carga.current=null;setError('');
 }
 async function enviar(monto:number,meses:number,clave:string){
  if(!identificado||!docValido||!archivo||!propietario||!firmante)throw new Error('Vuelve a identificación y documentación para completar el expediente.');
  const s=createClient();
  if(!carga.current){
   comprobarContenidoPdf(new Uint8Array(await archivo.arrayBuffer()));
   const datos:BorradorRuc={consulta,propietario,representante:firmante,propiedad_confirmada:true,evidencia_propiedad:guardarDocumento(propiedad,{dni:propietario.dni,presente}),evidencia_poder:'Certificado de vigencia de poder presentado para evaluación'};
   const {data:r,error:e}=await s.rpc('reservar_representacion',{p_consulta:consulta,p_propietario:propietario.dni,p_representante:firmante.dni,p_nombre:archivo.name,p_bytes:archivo.size,p_emision:emision});if(e)throw new Error(e.message);
   carga.current={clave,registro:r as Representacion,datos,monto,meses,subido:false};
  }
  const c=carga.current;
  if(c.monto!==monto||c.meses!==meses)throw new Error('Hay un envío sin confirmar. Reintenta con sus condiciones originales o vuelve a Documentación para preparar otro envío.');
  if(!c.subido){const {error:e}=await s.storage.from(BUCKET_CERTIFICADOS).upload(c.registro.archivo_ruta,archivo,{contentType:'application/pdf',upsert:false});
   if(e){await s.rpc('descartar_representacion',{p_id:c.registro.id});carga.current=null;throw new Error('No se pudo subir el PDF. Vuelve a enviar para reintentar.');}c.subido=true;
  }
  const res=await fetch('/api/solicitudes/enviar',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({representacion_id:c.registro.id,datos:c.datos,monto:c.monto,meses:c.meses,clave:c.clave,solicitud_id:solicitudInicial?.id,version:solicitudInicial?.version})});
  const d=await res.json();if(!res.ok||!d.id)throw new Error(d.mensaje||'No se pudo enviar. Puedes reintentar sin duplicar la solicitud.');return d.id as string;
 }
 if(paso===3&&propietario&&firmante){const st=propietario.situacion;return <FormularioPrestamo cliente={{id:propietario.id||'',dni:null,nombres:consulta.razon_social,apellidos:''}} situacion={{...st,verificacion:'aprobada',elegible:st.conciliado&&st.condicion_pago==='habilitado'&&!st.requiere_autorizacion}} agencia={agencia} asesor={asesor} borradorRuc={{consulta,propietario,representante:firmante,evidencia_propiedad:'',evidencia_poder:'',propiedad_confirmada:true}} onEnviarSolicitud={enviar} condicionesIniciales={condiciones} onCondicionesCambio={setCondiciones} onRevisarCliente={()=>ir(2)}/>;}
 return <div className="verification-page animate-fade-in"><div className="page-heading"><div><h1>Nuevo préstamo</h1><p>{consulta.razon_social} · RUC {consulta.ruc}</p></div></div>
 <ol className="loan-stepper" aria-label="Pasos del préstamo">{['Identificación','Documentación','Condiciones','Cronograma'].map((t,i)=><li key={t} className={i===paso-1?'current':i<paso-1?'complete':''} aria-current={i===paso-1?'step':undefined}><span>{i+1}</span><div>{i+1}. {t}</div></li>)}</ol>
 {error&&<p className="alert alert-error" role="alert">{error}</p>}
 {paso===1?<><section className="card"><h2>Atención de la empresa</h2><div className="evidence-grid"><div className="form-group"><label className="form-label" htmlFor="firma-empresa">¿Quién realiza el trámite y firma?</label><select className="form-input" id="firma-empresa" value={mismo?'propietario':'representante'} onChange={e=>{setMismo(e.target.value==='propietario');if(e.target.value==='propietario')setPresente(true);setRepresentante(null);setPresencia(false);setArchivo(null);setRevisada(false);}}><option value="propietario">El propietario, con facultades de representación</option><option value="representante">Un representante distinto del propietario</option></select></div>{!mismo&&<div className="form-group"><label className="form-label" htmlFor="presente-propietario">¿El propietario está presente?</label><select className="form-input" id="presente-propietario" value={presente?'si':'no'} onChange={e=>{setPresente(e.target.value==='si');corregir('propietario');}}><option value="si">Sí, está presente</option><option value="no">No, acude el representante</option></select></div>}</div><p className="page-subtitle">El límite de S/ 10 000 reúne a la persona y todas sus empresas. El representante no aporta su cupo al grupo.</p></section>
 {!propietario?(presente||mismo?<VerificarCliente enBorrador etiqueta="Propietario para el límite global" dniInicial={propietarioFijo||''} dniFijo={!!propietarioFijo} onVerificado={aceptarPropietario} limite={limite}/>:<PropietarioAusente dniInicial={propietarioFijo||''} onVerificado={aceptarPropietario}/>):<section className="card"><h2>Propietario para el límite global</h2><p>{propietario.nombres} {propietario.apellidos} · DNI {propietario.dni}</p><p>Capital pendiente: S/ {Number(propietario.situacion.capital_pendiente).toFixed(2)} · Disponible: S/ {Number(propietario.situacion.capital_disponible).toFixed(2)}</p>{!propietarioFijo&&<button className="btn btn-secondary" onClick={()=>corregir('propietario')}>Corregir DNI del propietario</button>}{propietarioFijo&&<p className="page-subtitle">Se conserva el propietario registrado de la empresa.</p>}</section>}
 {propietario&&!mismo&&(!representante?<VerificarCliente enBorrador etiqueta="Representante que firma" dniInicial={dniRep} onVerificado={aceptarRepresentante} limite={limite}/>:<section className="card"><h2>Representante verificado</h2><p>{representante.nombres} {representante.apellidos} · DNI {representante.dni}</p><button className="btn btn-secondary" onClick={()=>corregir('representante')}>Corregir DNI del representante</button></section>)}
 {firmante&&<section className="card"><h2>Presencia de quien firma</h2>{firmante.borrador?.evidencia.no_fallecido?<p>La presencia y el DNI original fueron comprobados en esta atención.</p>:<label className="form-checkbox"><input type="checkbox" checked={presencia} onChange={e=>setPresencia(e.target.checked)}/>Revisé el DNI original y confirmo la presencia del firmante.</label>}</section>}
 <div className="loan-actions loan-actions-end"><button className="btn btn-primary" disabled={!identificado} onClick={()=>ir(2)}>Continuar a documentación →</button></div></>:<>
 <DocumentacionEmpresa soloPropiedad propiedad={propiedad} poder={documentoVacio()} misma={false} revisionPropiedad={revisada} revisionPoder={false} recuperados={!!registro||!!solicitudInicial} onPropiedad={d=>{setPropiedad(d);setRevisada(false);}} onPoder={()=>{}} onMisma={()=>{}} onRevisionPropiedad={setRevisada} onRevisionPoder={()=>{}}/>
 <section className="card representation-card"><h2>Certificado de vigencia de poder</h2><p className="page-subtitle">Adjunta el certificado de SUNARP del representante que firma. Se enviará para evaluación al finalizar Nuevo préstamo.</p><div className="evidence-grid"><div className="form-group"><label className="form-label" htmlFor="archivo-empresa">Certificado PDF · hasta 5 MB</label><input id="archivo-empresa" className="form-input" type="file" accept=".pdf,application/pdf" onChange={e=>{const f=e.target.files?.[0]||null;setArchivo(f);setError(f?errorArchivoPdf(f.name,f.size,f.type)||'':'');}}/>{archivo&&<small>Seleccionado: {archivo.name}</small>}</div><div className="form-group"><label className="form-label" htmlFor="fecha-certificado">Fecha de emisión</label><input className="form-input" id="fecha-certificado" type="date" max={fechaPeru()} value={emision} onChange={e=>setEmision(e.target.value)}/></div></div><p className="page-subtitle">Los datos y el PDF permanecen en el borrador hasta pulsar Enviar solicitud de préstamo. El envío no concede el préstamo.</p></section>
 <div className="loan-actions"><button className="btn btn-secondary" onClick={()=>ir(1)}>Atrás</button><button className="btn btn-primary" disabled={!docValido} onClick={()=>ir(3)}>Continuar a condiciones →</button></div></>}
 </div>;
}
function tiposPermitidos(tipo:string){return ['partida','constitucion','acto','matricula'].includes(tipo);}
