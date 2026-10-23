import {createHmac} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {consultarRepresentantes} from '@/lib/apiPeru';
import {validarRuc} from '@/lib/ruc';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function POST(request:NextRequest){
 const headers={'Cache-Control':'private, no-store'};
 try{
  if(new URL(request.headers.get('origin')||'').host!==request.headers.get('host'))return NextResponse.json({mensaje:'Origen no permitido.'},{status:403,headers});
  const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)return NextResponse.json({mensaje:'Inicia sesión.'},{status:401,headers});
  const {data:sesion,error}=await s.rpc('control_sesion',{p_accion:'estado'});if(error||!sesion?.ok)return NextResponse.json({mensaje:'Vuelve a iniciar sesión.'},{status:401,headers});
  const {ruc}=await request.json();if(typeof ruc!=='string'||!ruc.startsWith('20')||!validarRuc(ruc))throw new Error('Ingresa un RUC 20 válido.');
  const secret=process.env.IDENTITY_SIGNING_SECRET;if(!secret)throw new Error('Falta configuración de firma del servidor.');
  const representantes=await consultarRepresentantes(ruc);
  const payload=JSON.stringify({tipo:'representantes',ruc,representantes,proveedor:'apiperu.pe',asesor_id:user.id,consultadoEn:new Date().toISOString()});
  return NextResponse.json({ok:true,ruc,representantes,payload,firma:createHmac('sha256',secret).update(payload).digest('hex')},{headers});
 }catch(e){return NextResponse.json({mensaje:e instanceof Error?e.message:'No se pudo consultar representantes.'},{status:400,headers});}
}
