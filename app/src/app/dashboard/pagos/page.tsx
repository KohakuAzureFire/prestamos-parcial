export const dynamic='force-dynamic';
import Pagos from '@/components/Pagos';import {createClient} from '@/lib/supabase/server';import {notFound} from 'next/navigation';
export default async function Pagina({searchParams}:{searchParams:Promise<{buscar?:string;cliente_id?:string}>}){
 const p=await searchParams;
 if(p.cliente_id){const s=await createClient();const {data:c,error}=await s.from('clientes_resumen').select('id,nombres,apellidos,dni,ruc,tipo_cliente').eq('id',p.cliente_id).maybeSingle();if(error)throw new Error('No se pudo recuperar el cliente seleccionado.');if(!c)notFound();const empresa=c.tipo_cliente==='juridica';return <Pagos key={c.id} clienteFijo={{id:c.id,nombre:[c.nombres,c.apellidos].filter(Boolean).join(' '),documento:empresa?c.ruc:c.dni,tipo:empresa?'ruc':'dni'}}/>;}
 return <Pagos key={p.buscar||'general'} busquedaInicial={p.buscar}/>;
}
