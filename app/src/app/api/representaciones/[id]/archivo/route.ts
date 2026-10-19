import {createHash,createHmac} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {BUCKET_CERTIFICADOS,comprobarContenidoPdf,LIMITE_PDF,type Representacion} from '@/lib/representaciones';
export const runtime='nodejs';export const dynamic='force-dynamic';
const cabeceras={'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'};
async function obtener(id:string){
 if(!/^[a-f0-9-]{36}$/i.test(id))return null;
 const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)return null;
 const {data:r,error}=await s.from('representaciones_empresa').select('*').eq('id',id).maybeSingle();
 return !error&&r?{s,r:r as Representacion,user}:null;
}
export async function GET(_request:NextRequest,{params}:{params:Promise<{id:string}>}){
 const ctx=await obtener((await params).id);if(!ctx)return NextResponse.json({mensaje:'Documento no disponible.'},{status:404,headers:cabeceras});
 const {data,error}=await ctx.s.storage.from(BUCKET_CERTIFICADOS).download(ctx.r.archivo_ruta);
 if(error||!data)return NextResponse.json({mensaje:'No se pudo recuperar el PDF.'},{status:404,headers:cabeceras});
 return new Response(data.stream(),{headers:{...cabeceras,'Content-Type':'application/pdf','Content-Disposition':`attachment; filename="certificado_${ctx.r.ruc}.pdf"`,'Content-Security-Policy':"sandbox; default-src 'none'"}});
}
export async function POST(request:NextRequest,{params}:{params:Promise<{id:string}>}){
 const origen=request.headers.get('origin');
 let mismoOrigen=false;try{mismoOrigen=!!origen&&new URL(origen).host===request.headers.get('host');}catch{}
 if(!mismoOrigen)return NextResponse.json({mensaje:'Origen no permitido.'},{status:403,headers:cabeceras});
 const ctx=await obtener((await params).id);
 if(!ctx||ctx.r.asesor_id!==ctx.user.id)return NextResponse.json({mensaje:'Solicitud no disponible.'},{status:404,headers:cabeceras});
 if(['pendiente','revisada','observada'].includes(ctx.r.estado))return NextResponse.json({ok:true,solicitud:ctx.r},{headers:cabeceras});
 if(ctx.r.estado!=='cargando')return NextResponse.json({mensaje:'La carga fue descartada.'},{status:409,headers:cabeceras});
 const secret=process.env.IDENTITY_SIGNING_SECRET;
 if(!secret)return NextResponse.json({mensaje:'La verificación necesita configuración del servidor.'},{status:503,headers:cabeceras});
 try{
  const {data,error}=await ctx.s.storage.from(BUCKET_CERTIFICADOS).download(ctx.r.archivo_ruta);
  if(error||!data)throw new Error('No se pudo leer el archivo subido.');
  if(data.size!==ctx.r.archivo_bytes||data.size>LIMITE_PDF)throw new Error('El tamaño del PDF no coincide con la solicitud.');
  const bytes=new Uint8Array(await data.arrayBuffer());comprobarContenidoPdf(bytes);
  const payload=JSON.stringify({tipo:'certificado_pdf',id:ctx.r.id,ruta:ctx.r.archivo_ruta,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),asesor_id:ctx.user.id,consultadoEn:new Date().toISOString()});
  const {data:solicitud,error:ef}=await ctx.s.rpc('finalizar_representacion',{p_payload:payload,p_firma:createHmac('sha256',secret).update(payload).digest('hex')});
  if(ef)throw new Error(ef.message);
  return NextResponse.json({ok:true,solicitud},{headers:cabeceras});
 }catch(e){return NextResponse.json({mensaje:e instanceof Error?e.message:'No se pudo verificar el PDF. Puedes reintentar la verificación.'},{status:400,headers:cabeceras});}
}
