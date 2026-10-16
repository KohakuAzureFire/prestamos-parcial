export const dynamic='force-dynamic';
import VerificarCliente from '@/components/VerificarCliente';
import FormularioPrestamo from '@/components/FormularioPrestamo';
import {createClient} from '@/lib/supabase/server';
import {notFound,redirect} from 'next/navigation';
import {errorBusqueda} from '@/lib/busqueda';
export default async function Nuevo({searchParams}:{searchParams:Promise<{cliente_id?:string;dni?:string}>}){
 const {cliente_id,dni}=await searchParams;
 const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)redirect('/login');
 const {data:a}=await s.from('asesores').select('*,agencias(nombre)').eq('id',user.id).single();if(!a)throw new Error('No se pudo identificar la agencia.');
 const {data:parametro}=await s.from('parametros_negocio').select('valor').eq('clave','capital_maximo').single();const limite=Number(parametro?.valor||10000);
 if(!cliente_id&&!dni)return <VerificarCliente nuevo agencia={a.agencias.nombre} asesor={a.nombre_completo} limite={limite}/>;
 if(dni){if(errorBusqueda('dni',dni))return <VerificarCliente nuevo agencia={a.agencias.nombre} asesor={a.nombre_completo} limite={limite}/>;
  const {data:r,error}=await s.rpc('resolver_cliente',{p_dni:dni});if(error)throw new Error('No se pudo recuperar el cliente.');if(!r)return <VerificarCliente nuevo dniInicial={dni} agencia={a.agencias.nombre} asesor={a.nombre_completo} limite={limite}/>;
  if(r.situacion.verificacion!=='aprobada')return <VerificarCliente nuevo dniInicial={dni} agencia={a.agencias.nombre} asesor={a.nombre_completo} limite={limite}/>;
  return <FormularioPrestamo cliente={r.cliente} situacion={r.situacion} agencia={a.agencias.nombre} asesor={a.nombre_completo}/>;
 }
 const {data:c}=await s.from('clientes_resumen').select('*').eq('id',cliente_id).maybeSingle();if(!c)notFound();
 if(c.situacion.verificacion!=='aprobada')return <VerificarCliente nuevo dniInicial={c.dni} agencia={a.agencias.nombre} asesor={a.nombre_completo} limite={limite}/>;
 return <FormularioPrestamo cliente={c} situacion={c.situacion} agencia={a.agencias.nombre} asesor={a.nombre_completo}/>;
}
