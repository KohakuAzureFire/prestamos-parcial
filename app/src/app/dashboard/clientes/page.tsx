export const dynamic='force-dynamic';
import {createClient} from '@/lib/supabase/server';import TablaClientes from '@/components/TablaClientes';
import type {Cliente} from '@/types/database';import type {Situacion} from '@/lib/operaciones';
export default async function Clientes(){
 const s=await createClient();
 // La RLS de préstamos limita esta consulta a la agencia del asesor.
 const titulares=new Set<string>();
 for(let desde=0;;desde+=1000){
  const {data,error}=await s.from('prestamos').select('cliente_id,responsable_id').eq('estado','confirmado').order('id').range(desde,desde+999);
  if(error)throw new Error('No se pudo consultar la cartera de tu agencia.');
  for(const p of data||[]){titulares.add(p.cliente_id);if(p.responsable_id)titulares.add(p.responsable_id);}
  if(!data||data.length<1000)break;
 }
 const clientes:(Cliente&{situacion:Situacion})[]=[];const ids=[...titulares];
 for(let inicio=0;inicio<ids.length;inicio+=100){
  const {data,error}=await s.from('clientes_resumen').select('*').in('id',ids.slice(inicio,inicio+100));
  if(error)throw new Error('No se pudieron cargar los clientes de tu agencia.');
  clientes.push(...data||[]);
 }
 clientes.sort((a,b)=>b.created_at.localeCompare(a.created_at));
 return <div className="animate-fade-in"><div className="page-heading"><div><h1>Clientes</h1><p>Personas y empresas con préstamos confirmados en tu agencia, incluidos los ya pagados.</p></div></div><TablaClientes clientesIniciales={clientes}/></div>;
}
