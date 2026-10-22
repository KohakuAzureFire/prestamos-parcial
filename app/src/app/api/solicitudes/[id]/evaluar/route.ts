import {createHmac} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {consultarRuc} from '@/lib/sunat';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function POST(request:NextRequest,{params}:{params:Promise<{id:string}>}){
 const headers={'Cache-Control':'private, no-store'};
 try{
  if(new URL(request.headers.get('origin')||'').host!==request.headers.get('host'))return NextResponse.json({mensaje:'Origen no permitido.'},{status:403,headers});
  const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)return NextResponse.json({mensaje:'Inicia sesión.'},{status:401,headers});
  const {id}=await params;const b=await request.json();
  const {data:sol,error:es}=await s.from('solicitudes_prestamo').select('*').eq('id',id).maybeSingle();if(es||!sol)return NextResponse.json({mensaje:'Solicitud no disponible.'},{status:404,headers});
  if(sol.estado==='aprobada'&&b.estado==='aprobada')return NextResponse.json({ok:true,prestamo_id:sol.prestamo_id},{headers});
  let consulta=null;
  if(b.estado==='aprobada'&&sol.expediente?.propietario?.verificacion_pendiente)throw new Error('Completa la verificación del propietario antes de aprobar.');
  if(b.estado==='aprobada'){
   const secret=process.env.IDENTITY_SIGNING_SECRET;if(!secret)throw new Error('Falta configuración de firma.');
   const d=await consultarRuc(sol.ruc);const payload=JSON.stringify({...d,tipo:'ruc',asesor_id:user.id,consultadoEn:new Date().toISOString()});consulta={payload,firma:createHmac('sha256',secret).update(payload).digest('hex')};
  }
  const {data:pid,error}=await s.rpc('evaluar_solicitud',{p_id:id,p_version:b.version,p_estado:b.estado,p_motivo:b.motivo,p_consulta:consulta,p_referencia:b.referencia||null,p_facultades:b.facultades===true,p_individual:b.individual===true});
  if(error)throw new Error(error.message);return NextResponse.json({ok:true,prestamo_id:pid},{headers});
 }catch(e){return NextResponse.json({mensaje:e instanceof Error?e.message:'No se pudo evaluar.'},{status:400,headers});}
}
