export const dynamic='force-dynamic';
import Link from 'next/link';import {notFound,redirect} from 'next/navigation';import {createClient} from '@/lib/supabase/server';import RevalidarRuc from '@/components/RevalidarRuc';
export default async function Revalidar({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<{tipo?:string}>}){
 const {id}=await params;const {tipo}=await searchParams;const s=await createClient();const {data:c,error}=await s.from('clientes_resumen').select('*').eq('id',id).maybeSingle();if(error)throw new Error('No se pudo consultar la ficha.');if(!c)notFound();
 if(!c.ruc)redirect('/dashboard/clientes/nuevo?dni='+c.dni);
 if(c.tipo_cliente==='natural'&&tipo!=='ruc')return <div className="animate-fade-in"><div className="page-heading"><h1>Revalidar datos</h1></div><section className="card"><h2>{c.nombres} {c.apellidos}</h2><p>Selecciona los datos que necesitas revisar.</p><div className="action-group"><Link className="btn btn-primary" href={'/dashboard/clientes/nuevo?dni='+c.dni}>Identidad · DNI</Link><Link className="btn btn-secondary" href="?tipo=ruc">Datos del negocio · RUC 10</Link></div></section><Link className="breadcrumb" href={'/dashboard/clientes/'+id}>← Volver a la ficha</Link></div>;
 return <RevalidarRuc key={id} clienteId={id} ruc={c.ruc}/>;
}
