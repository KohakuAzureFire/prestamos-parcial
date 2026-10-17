import {db,users,rpc,asUser,proof,secret,runTests} from './operaciones.test.mjs';import fs from 'node:fs';import crypto from 'node:crypto';import assert from 'node:assert/strict';
await runTests();for(const n of fs.readdirSync(new URL('../supabase/migrations/',import.meta.url)).sort().filter(n=>!n.startsWith('20261016054059')&&!n.startsWith('20261016060800')))await db.exec(fs.readFileSync(new URL('../supabase/migrations/'+n,import.meta.url),'utf8'));
const sql=fs.readFileSync(new URL('../scripts/ACTUALIZAR_SISTEMA.sql',import.meta.url),'utf8');await db.exec(sql);
const consulta=(ruc,uid)=>{const payload=JSON.stringify({tipo:'ruc',ruc,razon_social:'EMPRESA DE PRUEBA '+ruc,estado:'ACTIVO',condicion:'HABIDO',direccion:'AV PRUEBA',asesor_id:uid,consultadoEn:new Date().toISOString()});return {ruc,payload,firma:crypto.createHmac('sha256',secret).update(payload).digest('hex')};};
const persona=(dni,uid)=>{const p=proof(dni,uid);return {dni,borrador:{consulta:{dni,payload:p.p_payload,firma:p.p_firma},evidencia:p.p_evidencia}};};
const datos=(ruc,uid,owner='40027174')=>({consulta:consulta(ruc,uid),propietario:persona(owner,uid),representante:persona(owner,uid),evidencia_propiedad:'Propiedad acreditada en partida de prueba',evidencia_poder:'Facultades acreditadas en partida de prueba',propiedad_confirmada:true});
const prestamo=async(d,uid,monto=1000)=>rpc('confirmar_prestamo_cotizado',{p_tipo:'ruc',p_datos:d,p_monto:monto,p_meses:2,p_clave:crypto.randomUUID(),p_tasa:null,p_base:360},uid);
const personal=await prestamo(datos('10400271742',users.trujillo),users.trujillo);
const owner=(await rpc('resolver_cliente',{p_dni:'40027174'},users.trujillo)).cliente;
const empresa=await prestamo(datos('20601030013',users.chimbote),users.chimbote);
const cid=(await db.query('select cliente_id from public.prestamos where id=$1',[empresa])).rows[0].cliente_id;
// Una segunda empresa del mismo propietario, sin préstamo, también forma parte de sus vínculos.
let base='2000000302';const pesos=[5,4,3,2,7,6,5,4,3,2];let dig=11-base.split('').reduce((s,n,i)=>s+Number(n)*pesos[i],0)%11;const ruc2=base+(dig===10?0:dig===11?1:dig);
const otra=await prestamo(datos(ruc2,users.chimbote),users.chimbote,500);
const a=(await asUser(users.trujillo,tx=>tx.query('select * from public.clientes_resumen where id=$1',[owner.id]))).rows[0];const b=(await asUser(users.chimbote,tx=>tx.query('select * from public.clientes_resumen where id=$1',[owner.id]))).rows[0];assert.equal(a.id,b.id);assert.equal(a.dni,b.dni);assert.equal(a.ruc,b.ruc);assert.deepEqual(a.situacion,b.situacion);
const relA=await rpc('relaciones_cliente',{p_cliente:owner.id},users.trujillo);const relB=await rpc('relaciones_cliente',{p_cliente:cid},users.chimbote);assert.deepEqual(relA.miembros,relB.miembros);assert.equal(relA.miembros.length,3);assert.ok(relA.miembros.every(m=>m.puede_ver));assert.equal(relB.propietario.id,owner.id);
for(const uid of [users.trujillo,users.chimbote])for(const [tipo,doc] of [['dni','40027174'],['ruc','10400271742'],['ruc','20601030013'],['ruc',ruc2]])assert.deepEqual(new Set((await rpc('buscar_cuotas',{p_tipo:tipo,p_busqueda:doc},uid)).map(p=>p.id)),new Set([personal,empresa,otra]));
assert.equal((await rpc('buscar_cuotas',{p_tipo:'id',p_busqueda:empresa.slice(0,8)},users.trujillo)).length,1,'El código consulta solo el préstamo elegido');
const cartera=async(uid)=>(await asUser(uid,tx=>tx.query('select id from public.prestamos where id=any($1::uuid[])',[[personal,empresa,otra]]))).rows.map(p=>p.id);
assert.deepEqual(await cartera(users.trujillo),[personal]);assert.deepEqual(new Set(await cartera(users.chimbote)),new Set([empresa,otra]));
// Revalidar desde una agencia actualiza el mismo registro y el historial compartido.
await rpc('registrar_identidad',proof('40027174',users.chimbote),users.chimbote);const historia=async(uid)=>(await asUser(uid,tx=>tx.query('select id from public.verificaciones_con_agencia where cliente_id=$1 order by created_at,id',[owner.id]))).rows;assert.deepEqual(await historia(users.trujillo),await historia(users.chimbote));
// Un grupo ajeno no aparece por UUID y la consulta de su representante no hereda el grupo.
const aislado=await rpc('confirmar_cliente_prestamo',{...proof('00000888',users.trujillo),p_monto:100,p_meses:2,p_clave:crypto.randomUUID()},users.trujillo);const otro=(await rpc('resolver_cliente',{p_dni:'00000888'},users.trujillo)).cliente;
assert.equal((await asUser(users.chimbote,tx=>tx.query('select id from public.clientes where id=$1',[otro.id]))).rows.length,0);await assert.rejects(rpc('relaciones_cliente',{p_cliente:otro.id},users.chimbote),/fuera de su agencia/);
await db.query('update public.clientes set representante_id=$2 where id=$1',[cid,otro.id]);assert.deepEqual((await rpc('buscar_cuotas',{p_tipo:'dni',p_busqueda:'00000888'},users.chimbote)).map(p=>p.id),[aislado]);assert.equal((await rpc('relaciones_cliente',{p_cliente:cid},users.chimbote)).representante.puede_ver,false);
const antes=(await db.query('select id,identidad_contrato,monto from public.prestamos order by id')).rows;await db.exec(sql);assert.deepEqual((await db.query('select id,identidad_contrato,monto from public.prestamos order by id')).rows,antes,'Actualizar SQL no cambia contratos, capital ni crea duplicados');
console.log('PASS: misma ficha e historial entre agencias, vínculos compartidos, DNI/RUC10/RUC20 con mismo grupo de pagos, cartera local, aislamiento de grupos ajenos y representantes, SQL acumulado repetible sin modificar préstamos.');await db.close();
