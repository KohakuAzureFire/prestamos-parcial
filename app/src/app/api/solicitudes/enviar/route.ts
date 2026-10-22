import {createHash,createHmac} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {BUCKET_CERTIFICADOS,comprobarContenidoPdf,LIMITE_PDF} from '@/lib/representaciones';
export const runtime='nodejs';export const dynamic='force-dynamic';
const headers={'Cache-Control':'private, no-store'};
export async function POST(request:NextRequest){
 try{
  if(new URL(request.headers.get('origin')||'').host!==request.headers.get('host'))return NextResponse.json({mensaje:'Origen no permitido.'},{status:403,headers});
  if(Number(request.headers.get('content-length')||0)>100000)return NextResponse.json({mensaje:'Solicitud demasiado grande.'},{status:413,headers});
  const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)return NextResponse.json({mensaje:'Inicia sesión.'},{status:401,headers});
  const b=await request.json();
  const {data:prev,error:ep}=await s.from('solicitudes_prestamo').select('id,ruc,monto,plazo_meses').eq('clave_envio',b.clave).maybeSingle();if(ep)throw new Error(ep.message);
  if(prev){if(prev.ruc!==b.datos?.consulta?.ruc||Number(prev.monto)!==b.monto||prev.plazo_meses!==b.meses)throw new Error('La clave pertenece a otra solicitud.');return NextResponse.json({id:prev.id},{headers});}
  const {data:r,error:er}=await s.from('representaciones_empresa').select('*').eq('id',b.representacion_id).eq('asesor_id',user.id).maybeSingle();
  if(er||!r||r.estado!=='cargando')throw new Error('Carga no disponible. Vuelve al borrador y envía nuevamente.');
  const secret=process.env.IDENTITY_SIGNING_SECRET;if(!secret)throw new Error('Falta configuración de firma del servidor.');
  const {data:file,error:ef}=await s.storage.from(BUCKET_CERTIFICADOS).download(r.archivo_ruta);
  if(ef||!file||file.size!==r.archivo_bytes||file.size>LIMITE_PDF)throw new Error('No se pudo recuperar el PDF completo.');
  const bytes=new Uint8Array(await file.arrayBuffer());comprobarContenidoPdf(bytes);
  const payload=JSON.stringify({tipo:'certificado_pdf',id:r.id,ruta:r.archivo_ruta,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),asesor_id:user.id,consultadoEn:new Date().toISOString()});
  const {data:id,error}=await s.rpc('enviar_solicitud',{p_datos:b.datos,p_monto:b.monto,p_meses:b.meses,p_clave:b.clave,p_payload:payload,p_firma:createHmac('sha256',secret).update(payload).digest('hex'),p_id:b.solicitud_id||null,p_version:b.version||null});
  if(error)throw new Error(error.message);return NextResponse.json({id},{headers});
 }catch(e){return NextResponse.json({mensaje:e instanceof Error?e.message:'No se pudo enviar la solicitud.'},{status:400,headers});}
}
