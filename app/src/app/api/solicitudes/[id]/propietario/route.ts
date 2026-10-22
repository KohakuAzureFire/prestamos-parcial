import {createHmac} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {consultarRuc} from '@/lib/sunat';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function POST(request:NextRequest,{params}:{params:Promise<{id:string}>}){
 const headers={'Cache-Control':'private, no-store'};
 try{
  if(new URL(request.headers.get('origin')||'').host!==request.headers.get('host'))return NextResponse.json({mensaje:'Origen no permitido.'},{status:403,headers});
  if(Number(request.headers.get('content-length')||0)>20000)throw new Error('Solicitud demasiado grande.');
  const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)return NextResponse.json({mensaje:'Inicia sesión.'},{status:401,headers});
  const {id}=await params;const b=await request.json();
  const {data:sol,error:es}=await s.from('solicitudes_prestamo').select('*').eq('id',id).maybeSingle();
  if(es||!sol)return NextResponse.json({mensaje:'Solicitud no disponible.'},{status:404,headers});
  if(!sol.expediente?.propietario?.verificacion_pendiente)return NextResponse.json({ok:true,id},{headers});
  if(!['pendiente_identidad','observada'].includes(sol.estado)||sol.version!==b.version)throw new Error('La solicitud cambió. Actualiza antes de continuar.');
  if(b.propietario?.dni!==sol.expediente.propietario.dni||!b.propietario?.borrador)throw new Error('Verifica presencialmente al propietario de esta solicitud.');
  const secret=process.env.IDENTITY_SIGNING_SECRET;if(!secret)throw new Error('Falta configuración de firma.');
  const d=await consultarRuc(sol.ruc);const payload=JSON.stringify({...d,tipo:'ruc',asesor_id:user.id,consultadoEn:new Date().toISOString()});
  const {error}=await s.rpc('completar_propietario_solicitud',{p_id:id,p_version:b.version,p_propietario:b.propietario,p_consulta:{ruc:sol.ruc,payload,firma:createHmac('sha256',secret).update(payload).digest('hex')}});
  if(error)throw new Error(error.message);return NextResponse.json({ok:true,id},{headers});
 }catch(e){return NextResponse.json({mensaje:e instanceof Error?e.message:'No se pudo completar la verificación.'},{status:400,headers});}
}
