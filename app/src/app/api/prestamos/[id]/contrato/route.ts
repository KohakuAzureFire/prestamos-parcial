import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {NextRequest,NextResponse} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {camposContrato,completarTexto,escapar,generarContratoDocx,DatosContrato} from '@/lib/contrato';
import bloques from '../../../../../../templates/contrato-texto.json';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function GET(request:NextRequest,{params}:{params:Promise<{id:string}>}){
 const {id}=await params;if(!/^[a-f0-9-]{36}$/i.test(id))return NextResponse.json({mensaje:'Préstamo no encontrado.'},{status:404});
 const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)return NextResponse.json({mensaje:'Inicia sesión nuevamente.'},{status:401});
 const {data:p,error}=await s.from('prestamos').select('*,clientes(*),agencias(nombre),cuotas(*)').eq('id',id).eq('estado','confirmado').maybeSingle();
 if(error||!p)return NextResponse.json({mensaje:'Préstamo no disponible para tu agencia.'},{status:404});
 const prestamo=p as DatosContrato;let campos:Record<string,string>;
 try{campos=camposContrato(prestamo);}catch(e){return NextResponse.json({mensaje:e instanceof Error?e.message:'Revisa los datos del contrato.'},{status:409,headers:{'Cache-Control':'private, no-store'}});}
 if(request.nextUrl.searchParams.get('formato')==='imprimir'){
  const body=bloques.map(b=>b.tipo==='tabla'?'<table>'+b.filas!.map(f=>'<tr>'+f.map(c=>'<td>'+escapar(completarTexto(c,campos))+'</td>').join('')+'</tr>').join('')+'</table>':b.tipo==='titulo'?'<h2>'+escapar(completarTexto(b.texto!,campos))+'</h2>':'<p>'+escapar(completarTexto(b.texto!,campos))+'</p>').join('');
  return new Response('<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Contrato '+campos.CODIGO+'</title><style>body{max-width:180mm;margin:20mm auto;font:11pt Arial;line-height:1.4;color:#111}h2{font-size:11pt;break-after:avoid}p{text-align:justify}table{border-collapse:collapse;width:100%;break-inside:avoid}td{border:1px solid #ccc;padding:5px;white-space:pre-line}button{padding:12px;margin-bottom:20px}@media print{button{display:none}body{margin:0;max-width:none}@page{size:A4;margin:20mm}}</style></head><body><button onclick="window.print()">Imprimir o guardar como PDF</button>'+body+'</body></html>',{headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'private, no-store','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'self'"}});
 }
 const template=await readFile(path.join(process.cwd(),'templates','contrato.docx'));
 const buffer=generarContratoDocx(template,prestamo);
 return new Response(new Uint8Array(buffer),{headers:{'Content-Type':'application/vnd.openxmlformats-officedocument.wordprocessingml.document','Content-Disposition':'attachment; filename="Contrato_'+campos.CODIGO+'.docx"','Cache-Control':'private, no-store'}});
}
