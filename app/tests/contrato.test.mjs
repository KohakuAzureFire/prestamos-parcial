import ts from 'typescript';
import assert from 'node:assert/strict';import fs from 'node:fs';import PizZip from 'pizzip';
import {generarContratoDocx,camposContrato,completarTexto,escapar} from '../src/lib/contrato.ts';import {validarRuc} from '../src/lib/ruc.ts';
const sample={id:'abcdef12-1111-4111-8111-111111111111',fecha_prestamo:'2026-10-16',monto:1000,plazo_meses:2,identidad_contrato:{nombres:'EMPRESA & HIJOS <PRUEBA>',apellidos:'',ruc:'20601030013',propietario:{nombre:'PERSONA PROPIETARIA',dni:'00000301'},representante:{nombre:'REPRESENTANTE PRUEBA',dni:'00000302'}},clientes:{nombres:'Nombre modificado después',apellidos:'',ruc:'20601030013'},agencias:{nombre:'Chimbote'},cuotas:[{numero_cuota:1,fecha_vencimiento:'2026-11-16',cuota_total:516.63,interes:22.10},{numero_cuota:2,fecha_vencimiento:'2026-12-16',cuota_total:516.63,interes:11.16}]};
assert.ok(validarRuc('20601030013'));assert.equal(validarRuc('20601030014'),false);assert.equal(validarRuc('2060103001'),false);assert.equal(validarRuc('2060103001A'),false);
const template=fs.readFileSync(new URL('../templates/contrato.docx',import.meta.url));const out=generarContratoDocx(template,sample);const z=new PizZip(out);const xml=z.file('word/document.xml').asText();const allXml=Object.keys(z.files).filter(n=>/^word\/.*\.xml$/.test(n)).map(n=>z.file(n).asText()).join('');assert.equal(/\bmora\b|moratori|Condiciones particulares del préstamo/i.test(allXml),false);assert.equal(xml.includes('{{'),false);assert.ok(xml.includes('EMPRESA &amp; HIJOS &lt;PRUEBA&gt;'));assert.ok(xml.includes('REPRESENTANTE PRUEBA'));assert.equal(xml.includes('Nombre modificado después'),false);assert.ok(xml.includes('Chimbote'));assert.equal(/moratori|Condiciones particulares del préstamo/.test(xml),false);assert.ok(xml.includes('PR-ABCDEF12'));assert.equal(camposContrato(sample).DOCUMENTO_FIRMA,'DNI: 00000302');
const snapshot=structuredClone(sample.identidad_contrato);
const same=structuredClone(sample);same.identidad_contrato.propietario={nombre:'MARÍA DEL CARMEN FLORES SALAZAR',dni:'00000301'};same.identidad_contrato.representante={...same.identidad_contrato.propietario};same.identidad_contrato.razon_social='COMERCIAL LOS PINOS S.A.C.';
const sameFields=camposContrato(same);assert.equal(sameFields.CLIENTE,'COMERCIAL LOS PINOS S.A.C.');assert.ok(sameFields.REPRESENTACION.includes('MARÍA DEL CARMEN FLORES SALAZAR'));assert.equal(sameFields.DOCUMENTO_FIRMA,'DNI: 00000301');assert.equal(sameFields.CALIDAD_FIRMANTE,'Representante de EL CLIENTE');
const sameXml=new PizZip(generarContratoDocx(template,same)).file('word/document.xml').asText();assert.ok(sameXml.includes('MARÍA DEL CARMEN FLORES SALAZAR'));assert.equal((sameXml.match(/<w:t>Firma<\/w:t>/g)||[]).length,1);assert.equal(/aval|fiador|codeudor/i.test(sameXml),false);
for(const identidad of [null,{...snapshot,representante:null},{...snapshot,representante:{nombre:'',dni:'00000302'}},{...snapshot,representante:{nombre:'Persona',dni:''}}])assert.throws(()=>camposContrato({...sample,identidad_contrato:identidad}),/datos completos del representante/);
const solo=structuredClone(sample);solo.identidad_contrato={nombres:'ANA LUCÍA',apellidos:'GARCÍA PÉREZ',dni:'00000401',ruc:null};solo.clientes={...solo.identidad_contrato};assert.equal(camposContrato(solo).REPRESENTACION,'');assert.equal(camposContrato(solo).CALIDAD_FIRMANTE,'EL CLIENTE');
const negocio=structuredClone(solo);negocio.identidad_contrato.ruc='10000004011';assert.equal(camposContrato(negocio).DOCUMENTO,'RUC Nº 10000004011');assert.equal(camposContrato(negocio).DOCUMENTO_FIRMA,'DNI: 00000401');
for(const [name,p] of [['ruc20-propietario-firma',same],['ruc20-representante-distinto',sample],['dni-personal',solo],['ruc10-negocio',negocio]]){
 const fields=camposContrato(p);const output=generarContratoDocx(template,p);const text=new PizZip(output).file('word/document.xml').asText();assert.ok(text.includes(fields.CALIDAD_FIRMANTE));assert.ok(text.includes(fields.FIRMANTE.split(' · ')[0]));
 if(process.env.CONTRATOS_PRUEBA_DIR){fs.mkdirSync(process.env.CONTRATOS_PRUEBA_DIR,{recursive:true});fs.writeFileSync(process.env.CONTRATOS_PRUEBA_DIR+'/'+name+'.docx',output);}
}
assert.deepEqual(sample.identidad_contrato,snapshot);
const bloques=JSON.parse(fs.readFileSync(new URL('../templates/contrato-texto.json',import.meta.url),'utf8'));assert.equal(bloques.at(-1).tipo,'tabla');assert.ok(bloques.at(-1).filas.flat().some(c=>c.includes('{{FIRMANTE}}')&&c.includes('{{CALIDAD_FIRMANTE}}')));assert.ok(bloques.at(-1).filas.flat().some(c=>c.includes('Firma')));assert.equal(/moratori|Condiciones particulares del préstamo/.test(JSON.stringify(bloques)),false);
assert.equal(Object.keys(z.files).length,Object.keys(new PizZip(template).files).length,'Conserva las partes y formato del Word');
// Descargar e imprimir recorren la misma ruta real, con la sesión y lectura RLS simuladas.
let actual=sample,autenticado=true;const filtros=[];
const routeSource=fs.readFileSync(new URL('../src/app/api/prestamos/[id]/contrato/route.ts',import.meta.url),'utf8');
const module={exports:{}};
const chain={select:()=>chain,eq:(k,v)=>{filtros.push([k,v]);return chain;},maybeSingle:async()=>({data:actual?.estado==='confirmado'?actual:null})};
const mocks={'node:fs/promises':{readFile:async()=>template},'node:path':{default:{join:(...p)=>p.join('/')}},'next/server':{NextResponse:{json:(d,init)=>Response.json(d,init)}},'@/lib/supabase/server':{createClient:async()=>({auth:{getUser:async()=>({data:{user:autenticado?{id:'asesor-prueba'}:null}})},from:()=>chain})},'@/lib/contrato':{camposContrato,completarTexto,escapar,generarContratoDocx},'../../../../../../templates/contrato-texto.json':{default:bloques}};
new Function('require','exports',ts.transpileModule(routeSource,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)((n)=>{if(!(n in mocks))throw new Error('Import no simulado '+n);return mocks[n];},module.exports);
const request=(format)=>({nextUrl:new URL('https://prueba.local/api/prestamos/'+sample.id+'/contrato'+(format?'?formato=imprimir':''))});
const get=(format)=>module.exports.GET(request(format),{params:Promise.resolve({id:sample.id})});
for(const p of [sample,same,solo,negocio]){
 actual={...p,estado:'confirmado'};const word=await get(false);assert.equal(word.status,200);assert.ok(word.headers.get('content-type').includes('wordprocessingml'));assert.ok(new PizZip(Buffer.from(await word.arrayBuffer())).file('word/document.xml').asText().includes(escapar(camposContrato(p).CLIENTE)));
 const printed=await get(true);assert.equal(printed.status,200);const html=await printed.text();assert.ok(html.includes(escapar(camposContrato(p).CLIENTE)));assert.ok(html.includes(escapar(camposContrato(p).FIRMANTE)));assert.ok(html.includes('white-space:pre-line'));assert.equal(html.includes('{{'),false);
}
assert.ok(filtros.some(([k,v])=>k==='estado'&&v==='confirmado'));
actual=null;assert.equal((await get(false)).status,404,'Una solicitud sin préstamo no tiene contrato');
actual={...sample,estado:'borrador'};assert.equal((await get(false)).status,404);
actual={...sample,estado:'confirmado',identidad_contrato:{...snapshot,representante:null}};assert.equal((await get(false)).status,409);assert.equal((await get(true)).status,409);
autenticado=false;assert.equal((await get(false)).status,401);
if(process.env.CONTRATO_PRUEBA_SALIDA)fs.writeFileSync(process.env.CONTRATO_PRUEBA_SALIDA,out);
console.log('PASS: RUC y contrato completo, XML seguro, identidad congelada, representante, agencia y Word preservado.');
