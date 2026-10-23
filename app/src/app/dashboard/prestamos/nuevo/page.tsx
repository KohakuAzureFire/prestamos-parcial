export const dynamic='force-dynamic';
import Link from 'next/link';
import type {SolicitudPrestamo} from '@/lib/solicitudes';
import type {Representacion} from '@/lib/representaciones';
import VerificarCliente from '@/components/VerificarCliente';import InicioPrestamo from '@/components/InicioPrestamo';import VerificarRuc from '@/components/VerificarRuc';
import FormularioPrestamo from '@/components/FormularioPrestamo';import LimiteAlcanzado from '@/components/LimiteAlcanzado';
import {createClient} from '@/lib/supabase/server';import {notFound,redirect} from 'next/navigation';import {errorBusqueda} from '@/lib/busqueda';import {esEmpresa} from '@/lib/clientes';
export default async function Nuevo({searchParams}:{searchParams:Promise<{cliente_id?:string;dni?:string;ruc?:string;modalidad?:string;revision_id?:string;solicitud_id?:string}>}){
 const {cliente_id,dni,ruc,modalidad,revision_id,solicitud_id}=await searchParams;
 const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)redirect('/login');
 const {data:a}=await s.from('asesores').select('*,agencias(nombre)').eq('id',user.id).single();if(!a)throw new Error('No se pudo identificar la agencia.');
 const {data:parametros}=await s.from('parametros_negocio').select('clave,valor').eq('clave','capital_maximo');const limite=Number(parametros?.[0]?.valor||10000);
 const comunes={agencia:a.agencias.nombre,asesor:a.nombre_completo,limite};
 if(solicitud_id){const {data:sol,error}=await s.from('solicitudes_resumen').select('*').eq('id',solicitud_id).eq('agencia_id',a.agencia_id).maybeSingle();if(error)throw new Error('No se pudo recuperar la solicitud.');if(!sol||sol.estado!=='observada')notFound();return <VerificarRuc {...comunes} solicitudInicial={sol as SolicitudPrestamo} rucInicial={sol.ruc} autoConsultar/>;}
 if(revision_id){const {data:rev,error}=await s.from('representaciones_resumen').select('*').eq('id',revision_id).eq('agencia_id',a.agencia_id).maybeSingle();if(error)throw new Error('No se pudo recuperar la revisión.');if(!rev)notFound();return <VerificarRuc {...comunes} rucInicial={rev.ruc} revisionInicial={rev as Representacion} autoConsultar/>;}
 // Desde una ficha se conserva la identidad seleccionada y se verifica el cupo antes de elegir modalidad.
 if(cliente_id){
  const {data:c,error}=await s.from('clientes_resumen').select('*').eq('id',cliente_id).maybeSingle();if(error)throw new Error('No se pudo recuperar la ficha.');if(!c)notFound();
  if(!esEmpresa(c)&&Number(c.situacion.capital_disponible)<0.01)return <LimiteAlcanzado clienteId={c.id}/>;
  if(esEmpresa(c))return <VerificarRuc key={c.id} {...comunes} rucInicial={c.ruc} autoConsultar/>;
  if(c.ruc?.startsWith('10')&&modalidad!=='dni'&&modalidad!=='ruc')return <div className="animate-fade-in"><div className="page-heading"><div><h1>Nuevo préstamo</h1><p>{c.nombres} {c.apellidos}</p></div></div><section className="card"><h2>Modalidad del préstamo</h2><p>Elige cómo se registrará este préstamo. Ambas modalidades comparten el mismo límite global.</p><div className="action-group"><Link className="btn btn-primary" href={'?'+new URLSearchParams({cliente_id:c.id,modalidad:'dni'})}>Personal · DNI</Link><Link className="btn btn-secondary" href={'?'+new URLSearchParams({cliente_id:c.id,modalidad:'ruc'})}>Negocio · RUC 10</Link></div></section><Link className="breadcrumb" href={'/dashboard/clientes/'+c.id}>← Volver a la ficha</Link></div>;
  if(c.ruc?.startsWith('10')&&modalidad==='ruc')return <VerificarRuc key={c.id} {...comunes} rucInicial={c.ruc} autoConsultar/>;
  if(c.situacion.verificacion!=='aprobada')return <VerificarCliente {...comunes} nuevo dniFijo automatico dniInicial={c.dni}/>;
  return <FormularioPrestamo {...comunes} cliente={c} situacion={c.situacion} volverHref={'/dashboard/clientes/'+c.id}/>;
 }
 if(ruc){
  if(!errorBusqueda('ruc',ruc)){const {data:c,error}=await s.from('clientes_resumen').select('id,situacion,tipo_cliente,ruc,dni').eq('ruc',ruc).maybeSingle();if(error)throw new Error('No se pudo recuperar el cupo del cliente.');if(c&&!esEmpresa(c)&&Number(c.situacion.capital_disponible)<0.01)return <LimiteAlcanzado clienteId={c.id}/>;}
  return <InicioPrestamo {...comunes} rucInicial={ruc}/>;
 }
 if(!dni)return <InicioPrestamo {...comunes}/>;
 if(errorBusqueda('dni',dni))return <VerificarCliente {...comunes} nuevo/>;
 const {data:r,error}=await s.rpc('resolver_cliente',{p_dni:dni});if(error)throw new Error('No se pudo recuperar el cliente.');if(!r)return <VerificarCliente {...comunes} nuevo dniInicial={dni}/>;
 if(Number(r.situacion.capital_disponible)<0.01)return <LimiteAlcanzado/>;
 // Una búsqueda explícita por DNI conserva la modalidad personal, aunque exista RUC 10.
 if(r.situacion.verificacion!=='aprobada')return <VerificarCliente {...comunes} nuevo dniInicial={dni}/>;
 return <FormularioPrestamo {...comunes} cliente={r.cliente} situacion={r.situacion}/>;
}
