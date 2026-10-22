import assert from 'node:assert/strict';
import {documentoConCampos,documentoCompleto,guardarDocumento,leerDocumento,resumenDocumento} from '../src/lib/documentosEmpresa.ts';
const persona={dni:'00000301',presente:true};
const muestras=[
 ['partida',{partida:'0012345678',asiento:'A00001'},'Partida 0012345678, asiento A00001'],
 ['constitucion',{escritura:'245',fecha:'2024-02-29',notaria:'Pérez'},'Escritura 245, 29/02/2024, Notaría Pérez'],
 ['acto',{partida:'12345678',fecha:'2026-03-15'},'Acto constitutivo SACS, partida 12345678, 15/03/2026'],
 ['matricula',{libro:'1',folio:'12',asiento:'B00002'},'Libro 1, folio 12, asiento B00002'],
];
for(const [tipo,campos,ref] of muestras){
 const d=documentoConCampos(tipo,campos);assert.equal(documentoCompleto(d),true);assert.equal(d.referencia,ref);
 const texto=guardarDocumento(d,persona);const json=JSON.parse(texto);
 assert.equal(json.v,1);assert.equal(json.ref,ref);assert.equal(json.dni,persona.dni);assert.equal(json.presente,true);assert.ok(texto.length<=500);
 assert.deepEqual(leerDocumento(texto),d,'La corrección de una solicitud recupera los mismos datos');
 assert.ok(resumenDocumento(texto).includes(ref));
 for(const id of Object.keys(campos)){
  const incompleto=documentoConCampos(tipo,{...campos,[id]:''});
  assert.equal(documentoCompleto(incompleto),false);assert.throws(()=>guardarDocumento(incompleto,persona));
 }
}
for(const campos of [{partida:'123A',asiento:'A00001'},{partida:'12345678',asiento:'A/001'},{partida:'12345678',asiento:'A'.repeat(21)}])assert.equal(documentoCompleto(documentoConCampos('partida',campos)),false);
for(const fecha of ['2026-02-29','2024-02-30','0000-01-01','15/03/2026'])assert.equal(documentoCompleto(documentoConCampos('constitucion',{escritura:'245',fecha,notaria:'Pérez'})),false);
const anterior=JSON.stringify({v:1,tipo:'matricula',ref:'Libro 1, folio 12, asiento de titularidad',...persona});
const recuperado=leerDocumento(anterior);assert.equal(recuperado.campos,undefined);assert.equal(documentoCompleto(recuperado),true);assert.equal(JSON.parse(guardarDocumento(recuperado,persona)).ref,JSON.parse(anterior).ref,'Una referencia anterior no se interpreta ni se pierde');
const cambio=documentoConCampos('constitucion');assert.equal(cambio.referencia,'');assert.equal(documentoCompleto(cambio),false,'Cambiar de tipo exige los datos del nuevo documento');
console.log('PASS: referencias guiadas, fechas reales, ceros iniciales, campos incompletos, compatibilidad v1 y recuperación sin pérdida.');
