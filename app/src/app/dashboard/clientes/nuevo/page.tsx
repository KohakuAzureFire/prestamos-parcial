import VerificarCliente from '@/components/VerificarCliente';
import {createClient} from '@/lib/supabase/server';import {redirect} from 'next/navigation';
export const dynamic='force-dynamic';
export default async function Verificacion({searchParams}:{searchParams:Promise<{dni?:string}>}){const p=await searchParams;const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)redirect('/login');const {data:a}=await s.from('asesores').select('*,agencias(nombre)').eq('id',user.id).single();if(!a)redirect('/login');const {data:parametro}=await s.from('parametros_negocio').select('valor').eq('clave','capital_maximo').single();return <VerificarCliente dniInicial={p.dni} agencia={a.agencias.nombre} asesor={a.nombre_completo} limite={Number(parametro?.valor||10000)}/>;}
