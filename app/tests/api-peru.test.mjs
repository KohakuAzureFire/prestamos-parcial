import assert from 'node:assert/strict';import fs from 'node:fs';import ts from 'typescript';import crypto from 'node:crypto';
import {normalizarRepresentantes} from '../src/lib/representantesApi.ts';
import {generarCronograma,formatFecha} from '../src/lib/financiero.ts';
const raw=[{tipo_de_documento:'DNI',numero_de_documento:'00000001',nombre:'APODERADO UNO',cargo:'GERENTE',fecha_desde:'01/01/2020'},{tipo_de_documento:'DNI',numero_de_documento:'1*****72',nombre:'PAIMO *****O ***NA',cargo:'APODERADO',fecha_desde:'30/09/2002'}];
const data=normalizarRepresentantes({success:true,data:raw});assert.equal(data.length,2);assert.equal(data[0].documento,'00000001');assert.equal(data[0].dni_completo,true);assert.equal(data[1].dni_completo,false);assert.equal(data[1].documento,'1*****72');assert.deepEqual(normalizarRepresentantes({success:true,data:[]}),[]);
for(const r of [{success:false,data:[]},{success:true,data:{}},{success:true,data:[{}]}])assert.throws(()=>normalizarRepresentantes(r));
const mod=(file,mocks)=>{const m={exports:{}};new Function('require','exports',ts.transpileModule(fs.readFileSync(new URL(file,import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)((n)=>{assert.ok(n in mocks,n);return mocks[n];},m.exports);return m.exports;};
const provider=mod('../src/lib/apiPeru.ts',{'server-only':{},'./representantesApi':{normalizarRepresentantes}});
const previousFetch=globalThis.fetch,previousToken=process.env.API_PERU_TOKEN,previousSecret=process.env.IDENTITY_SIGNING_SECRET;
try{
 delete process.env.API_PERU_TOKEN;await assert.rejects(provider.consultarRepresentantes('20601030013'),/API_PERU_TOKEN/);
 process.env.API_PERU_TOKEN='token-ficticio-de-prueba';let calls=0;
 globalThis.fetch=async(url,opts)=>{calls++;assert.equal(url,'https://api.apiperu.pe/ruc/representantes');assert.equal(opts.method,'POST');assert.deepEqual(JSON.parse(opts.body),{ruc:'20601030013'});return Response.json({success:true,data:raw});};
 assert.deepEqual(await provider.consultarRepresentantes('20601030013'),data);assert.equal(calls,1);
 for(const status of [401,403,404,429,503]){globalThis.fetch=async()=>Response.json({},{status});await assert.rejects(provider.consultarRepresentantes('20601030013'));}
 globalThis.fetch=async()=>{throw new Error('timeout');};await assert.rejects(provider.consultarRepresentantes('20601030013'),/temporalmente/);
 let authenticated=true,session=true,queries=0;process.env.IDENTITY_SIGNING_SECRET='firma-ficticia-prueba';
 const route=mod('../src/app/api/sunat/representantes/route.ts',{'node:crypto':crypto,'next/server':{NextResponse:{json:(d,o)=>Response.json(d,o)}},'@/lib/ruc':{validarRuc:()=>true},'@/lib/apiPeru':{consultarRepresentantes:async()=>{queries++;return data;}},'@/lib/supabase/server':{createClient:async()=>({auth:{getUser:async()=>({data:{user:authenticated?{id:'asesor-prueba'}:null}})},rpc:async()=>({data:{ok:session}})})}});
 const req=(ruc,origin='https://prueba.local')=>new Request('https://prueba.local/api/sunat/representantes',{method:'POST',headers:{origin,host:'prueba.local','content-type':'application/json'},body:JSON.stringify({ruc})});
 authenticated=false;assert.equal((await route.POST(req('20601030013'))).status,401);authenticated=true;session=false;assert.equal((await route.POST(req('20601030013'))).status,401);session=true;assert.equal((await route.POST(req('10601030013'))).status,400);assert.equal((await route.POST(req('20601030013','https://otro.local'))).status,403);assert.equal(queries,0);
 const response=await route.POST(req('20601030013'));assert.equal(response.status,200);const result=await response.json();assert.equal(result.representantes.length,2);assert.equal(JSON.parse(result.payload).ruc,'20601030013');assert.equal(result.firma,crypto.createHmac('sha256',process.env.IDENTITY_SIGNING_SECRET).update(result.payload).digest('hex'));
}finally{globalThis.fetch=previousFetch;if(previousToken===undefined)delete process.env.API_PERU_TOKEN;else process.env.API_PERU_TOKEN=previousToken;if(previousSecret===undefined)delete process.env.IDENTITY_SIGNING_SECRET;else process.env.IDENTITY_SIGNING_SECRET=previousSecret;}
for(const [base,expected] of [['2026-10-22',['21/11/2026','21/12/2026','20/01/2027']],['2028-01-31',['01/03/2028','31/03/2028','30/04/2028']],['2026-05-12',['11/06/2026','11/07/2026','10/08/2026']]])assert.deepEqual(generarCronograma(1000,3,base).map(q=>formatFecha(q.fecha_vencimiento)),expected);
assert.equal(formatFecha(generarCronograma(1000,2,'2028-01-31','mensual')[0].fecha_vencimiento),'29/02/2028','Las simulaciones antiguas conservan su periodicidad');
assert.equal(generarCronograma(1000,6,'2026-10-22').reduce((s,c)=>s+Math.round(c.amortizacion*100),0),100000);
console.log('PASS: API Perú con varios representantes, datos parciales, errores, sesión, firma y cronograma cada 30 días. Sin consultas reales.');
