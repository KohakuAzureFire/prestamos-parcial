import {createHmac} from 'node:crypto';
import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {consultarRuc} from '@/lib/sunat';
import {validarRuc} from '@/lib/ruc';
export const dynamic='force-dynamic';
export async function GET(request:NextRequest){
 const s=await createClient();const {data:{user}}=await s.auth.getUser();
 if(!user)return NextResponse.json({ok:false,mensaje:'Inicia sesión nuevamente.'},{status:401});
 const {data:a}=await s.from('asesores').select('activo').eq('id',user.id).maybeSingle();
 if(!a?.activo)return NextResponse.json({ok:false,mensaje:'Cuenta sin autorización.'},{status:403});
 const secret=process.env.IDENTITY_SIGNING_SECRET;
 if(!secret)return NextResponse.json({ok:false,mensaje:'La verificación necesita configuración del servidor.'},{status:503});
 const ruc=request.nextUrl.searchParams.get('numero')||'';
 if(!validarRuc(ruc))return NextResponse.json({ok:false,mensaje:'RUC inválido. Revisa los 11 dígitos y el dígito verificador.'},{status:400});
 try{const d=await consultarRuc(ruc);const payload=JSON.stringify({...d,tipo:'ruc',asesor_id:user.id,consultadoEn:new Date().toISOString()});
 const {data:tieneDeuda,error:deudaError}=await s.rpc('tiene_deuda_pendiente_ruc',{p_ruc:ruc});
 if(deudaError)throw new Error('No se pudo comprobar si el RUC tiene préstamos pendientes. Intenta nuevamente.');
 const registro=null;

 return NextResponse.json({ok:true,...d,registro,tiene_deuda_pendiente:tieneDeuda===true,payload,firma:createHmac('sha256',secret).update(payload).digest('hex')},{headers:{'Cache-Control':'no-store'}});
 }catch(e){return NextResponse.json({ok:false,mensaje:e instanceof Error?e.message:'No se pudo consultar el RUC.'},{status:502,headers:{'Cache-Control':'no-store'}});}
}
