export const dynamic='force-dynamic';
import {notFound,redirect} from 'next/navigation';import {createClient} from '@/lib/supabase/server';import RevalidarRuc from '@/components/RevalidarRuc';
export default async function Revalidar({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<{tipo?:string}>}){
 const {id}=await params;const {tipo}=await searchParams;const s=await createClient();const {data:c,error}=await s.from('clientes_resumen').select('*').eq('id',id).maybeSingle();if(error)throw new Error('No se pudo consultar la ficha.');if(!c)notFound();
 if(!c.ruc)redirect('/dashboard/clientes/nuevo?dni='+c.dni);
 if(c.tipo_cliente==='natural'&&tipo!=='ruc')redirect('/dashboard/clientes/nuevo?dni='+c.dni);
 return <RevalidarRuc key={id} clienteId={id} ruc={c.ruc} guardados={{razon_social:c.razon_social,estado_ruc:c.estado_ruc,condicion_ruc:c.condicion_ruc,direccion_fiscal:c.direccion_fiscal,ruc_consultado_at:c.ruc_consultado_at}}/>;
}
