// Base de datos aislada y archivos sintéticos: no usa Decolecta ni Supabase real.
import fs from 'node:fs';import assert from 'node:assert/strict';import crypto from 'node:crypto';
import {db,users,rpc,asUser,proof,secret} from './operaciones.test.mjs';
import {coincideTipoListado,coincideTipo,documentosListado} from '../src/lib/clientes.ts';
import {errorArchivoPdf,comprobarContenidoPdf,LIMITE_PDF} from '../src/lib/representaciones.ts';
process.argv.push('--serve');const {rucValido}=await import('./ruc.test.mjs');
try{
 const persona={dni:'60000001',ruc:rucValido('1060000001'),tipo_cliente:'natural'};
 assert.ok(coincideTipoListado(persona,'personas'));assert.ok(coincideTipoListado(persona,'empresas'));assert.equal(coincideTipo(persona,'empresas'),false,'El filtro de préstamos conserva su alcance');
 assert.deepEqual(documentosListado(persona,'personas'),['DNI 60000001']);assert.deepEqual(documentosListado(persona,'empresas'),['RUC '+persona.ruc]);assert.equal(documentosListado(persona,'todos').length,2);
 assert.equal(errorArchivoPdf('certificado.pdf',LIMITE_PDF,'application/pdf'),null);assert.ok(errorArchivoPdf('x.jpg',100,'image/jpeg'));assert.ok(errorArchivoPdf('x.pdf',LIMITE_PDF+1,'application/pdf'));assert.ok(errorArchivoPdf('x.pdf',0,'application/pdf'));
 comprobarContenidoPdf(Buffer.from('%PDF-1.7\ncontenido de prueba\n%%EOF'));assert.throws(()=>comprobarContenidoPdf(Buffer.from('PNG renombrado.pdf')),/PDF/);
 await db.exec(`create schema storage;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text not null,metadata jsonb,unique(bucket_id,name));
 alter table storage.objects enable row level security;grant usage on schema storage to authenticated;grant select,insert,delete,update on storage.objects to authenticated;`);
 await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261019194843_revision_representacion_ruc20.sql',import.meta.url),'utf8'));
 const firmado=(d,uid=users.chimbote)=>{const payload=JSON.stringify({...d,asesor_id:uid,consultadoEn:new Date().toISOString()});return {payload,firma:crypto.createHmac('sha256',secret).update(payload).digest('hex')};};
 const consulta=(ruc,uid=users.chimbote)=>({ruc,...firmado({tipo:'ruc',ruc,razon_social:'EMPRESA CERTIFICADO PRUEBA',estado:'ACTIVO',condicion:'HABIDO'},uid)});
 const person=(dni,uid=users.chimbote)=>{const p=proof(dni,uid);return {dni,borrador:{consulta:{dni,payload:p.p_payload,firma:p.p_firma},evidencia:p.p_evidencia}};};
 const owner='60000001',rep='60000002',r20=rucValido('2060000001');
 const datos=(ruc=r20,uid=users.chimbote)=>({consulta:consulta(ruc,uid),propietario:person(owner,uid),representante:person(rep,uid),evidencia_propiedad:'Partida de propiedad y designación verificadas',evidencia_poder:'Certificado privado revisado',propiedad_confirmada:true});
 const counts=async()=>(await db.query('select (select count(*) from public.clientes)::int clientes,(select count(*) from public.prestamos)::int prestamos,(select count(*) from public.pagos)::int pagos')).rows[0];
 const antes=await counts();
 await assert.rejects(rpc('confirmar_ruc_prestamo',{p_datos:datos(),p_monto:1000,p_meses:2,p_clave:crypto.randomUUID()}),/representación revisada/);assert.deepEqual(await counts(),antes);
 const hoy=(await db.query('select public.fecha_peru()::text hoy')).rows[0].hoy;
 async function reservar(ruc=r20,uid=users.chimbote){return rpc('reservar_representacion',{p_consulta:consulta(ruc,uid),p_propietario:owner,p_representante:rep,p_nombre:'certificado.pdf',p_bytes:100,p_emision:hoy},uid);}
 let r=await reservar();assert.equal(r.estado,'cargando');assert.deepEqual(await counts(),antes,'La solicitud no crea cliente ni préstamo');
 const sello=r=>firmado({tipo:'certificado_pdf',id:r.id,ruta:r.archivo_ruta,bytes:100,sha256:'a'.repeat(64)},r.asesor_id);
 await assert.rejects(rpc('finalizar_representacion',{p_payload:sello(r).payload,p_firma:'falsa'}),/inválida/);
 await assert.rejects(rpc('finalizar_representacion',{p_payload:sello(r).payload,p_firma:sello(r).firma}),/PDF privado/);
 await assert.rejects(asUser(users.trujillo,tx=>tx.query("insert into storage.objects(bucket_id,name,metadata) values('certificados-representacion',$1,'{\"size\":100,\"mimetype\":\"application/pdf\"}')",[r.archivo_ruta])),/row-level security/);
 await asUser(users.chimbote,tx=>tx.query("insert into storage.objects(bucket_id,name,metadata) values('certificados-representacion',$1,'{\"size\":100,\"mimetype\":\"application/pdf\"}')",[r.archivo_ruta]));
 async function finalizar(r){const s=sello(r);return rpc('finalizar_representacion',{p_payload:s.payload,p_firma:s.firma},r.asesor_id);}
 r=await finalizar(r);assert.equal(r.estado,'pendiente');
 const visible=(await asUser(users.chimbote,tx=>tx.query('select * from public.representaciones_resumen where id=$1',[r.id]))).rows[0];
 assert.equal(visible.agencia_nombre,'Chimbote');assert.ok(visible.asesor_nombre);
 assert.equal((await db.query("select has_function_privilege('anon','public.revisar_representacion(uuid,integer,text,text,text,date,numeric,boolean,boolean)','execute') permitido")).rows[0].permitido,false);assert.equal((await finalizar(r)).id,r.id,'Finalización idempotente');
 const revisar=(r,extra={})=>({p_id:r.id,p_version:r.version,p_estado:'revisada',p_observacion:'Se comprobó certificado y facultades de firma individual',p_referencia:'Certificado verificado en fuente registral de prueba',p_hasta:hoy,p_maximo:5000,p_facultades:true,p_individual:true,...extra});
 await assert.rejects(rpc('revisar_representacion',revisar(r),users.trujillo),/No tiene permiso/);
 await assert.rejects(rpc('revisar_representacion',revisar(r,{p_facultades:false})),/facultades/);
 await assert.rejects(rpc('revisar_representacion',revisar(r,{p_individual:false})),/firma individual/);
 await assert.rejects(rpc('revisar_representacion',revisar(r,{p_version:1})),/revisión cambió/);
 assert.equal((await asUser(users.trujillo,tx=>tx.query('select * from public.representaciones_empresa where id=$1',[r.id]))).rows.length,0);
 assert.equal((await asUser(users.trujillo,tx=>tx.query('select * from storage.objects where name=$1',[r.archivo_ruta]))).rows.length,0);
 assert.equal((await asUser(users.chimbote,tx=>tx.query('delete from storage.objects where name=$1',[r.archivo_ruta]))).affectedRows,0,'No se elimina el archivo presentado');
 await assert.rejects(rpc('revisar_representacion',revisar(r,{p_hasta:'2099-01-01'})),/30 días/);
 await assert.rejects(rpc('revisar_representacion',revisar(r,{p_maximo:10000.01})),/monto máximo/);
 r=await rpc('revisar_representacion',revisar(r));assert.equal(r.estado,'revisada');
 await db.query('update public.representaciones_empresa set valida_hasta=public.fecha_peru()-1 where id=$1',[r.id]);
 await assert.rejects(rpc('confirmar_ruc_prestamo',{p_datos:{...datos(),representacion_id:r.id},p_monto:1,p_meses:2,p_clave:crypto.randomUUID()}),/representación revisada/);
 await db.query('update public.representaciones_empresa set valida_hasta=public.fecha_peru() where id=$1',[r.id]);
 // Una nueva presentación invalida la revisión anterior para futuras colocaciones.
 let reciente=await reservar();
 await asUser(users.chimbote,tx=>tx.query("insert into storage.objects(bucket_id,name,metadata) values('certificados-representacion',$1,'{\"size\":100,\"mimetype\":\"application/pdf\"}')",[reciente.archivo_ruta]));
 assert.equal((await asUser(users.chimbote,tx=>tx.query('delete from storage.objects where name=$1',[reciente.archivo_ruta]))).affectedRows,0,'Tampoco se reemplaza el archivo durante la verificación');
 reciente=await finalizar(reciente);
 await assert.rejects(rpc('confirmar_ruc_prestamo',{p_datos:{...datos(),representacion_id:r.id},p_monto:1,p_meses:2,p_clave:crypto.randomUUID()}),/presentación posterior/);
 r=await rpc('revisar_representacion',revisar(reciente));
 await assert.rejects(rpc('confirmar_ruc_prestamo',{p_datos:{...datos(),representacion_id:r.id},p_monto:5001,p_meses:2,p_clave:crypto.randomUUID()}),/representación revisada/);
 await assert.rejects(rpc('confirmar_ruc_prestamo',{p_datos:{...datos(),representacion_id:r.id,representante:person('60000003')},p_monto:1000,p_meses:2,p_clave:crypto.randomUUID()}),/representación revisada/);
 const r10=persona.ruc;
 const d10={consulta:consulta(r10),propietario:person(owner),representante:person(owner)};
 await rpc('confirmar_ruc_prestamo',{p_datos:d10,p_monto:2000,p_meses:2,p_clave:crypto.randomUUID()});
 const args={p_datos:{...datos(),representacion_id:r.id},p_monto:5000,p_meses:2,p_clave:crypto.randomUUID()};const loan=await rpc('confirmar_ruc_prestamo',args);assert.equal(await rpc('confirmar_ruc_prestamo',args),loan);
 const identidad=(await db.query('select identidad_contrato from public.prestamos where id=$1',[loan])).rows[0].identidad_contrato;assert.equal(identidad.representacion_id,r.id);
 // Otra empresa de la misma persona, en otra agencia, usa el mismo límite global.
 const otro=rucValido('2060000002');let r2=await reservar(otro,users.trujillo);
 await asUser(users.trujillo,tx=>tx.query("insert into storage.objects(bucket_id,name,metadata) values('certificados-representacion',$1,'{\"size\":100,\"mimetype\":\"application/pdf\"}')",[r2.archivo_ruta]));r2=await finalizar(r2);
 r2=await rpc('revisar_representacion',revisar(r2));
 await rpc('confirmar_ruc_prestamo',{p_datos:{...datos(otro,users.trujillo),representacion_id:r2.id},p_monto:3000,p_meses:2,p_clave:crypto.randomUUID()},users.trujillo);
 await assert.rejects(rpc('confirmar_ruc_prestamo',{...args,p_monto:.01,p_clave:crypto.randomUUID()}),/capital disponible/);
 const cid=(await db.query('select cliente_id from public.prestamos where id=$1',[loan])).rows[0].cliente_id;const st=await rpc('resumen_cliente',{p_cliente:cid});assert.equal(Number(st.capital_pendiente),10000);
 // Una observación retira autorización para nuevas operaciones, sin tocar préstamos anteriores.
 r=await rpc('revisar_representacion',revisar(r,{p_estado:'observada',p_observacion:'Nueva información requiere revisión de las facultades'}));
 await assert.rejects(rpc('confirmar_ruc_prestamo',{...args,p_monto:1,p_clave:crypto.randomUUID()}),/representación revisada/);assert.equal(await rpc('confirmar_ruc_prestamo',args),loan);
 const pagoAntes=(await counts()).pagos;assert.equal(pagoAntes,antes.pagos);
 await assert.rejects(asUser(users.chimbote,tx=>tx.query('update public.representaciones_empresa set estado=\'revisada\' where id=$1',[r.id])),/permission denied/);
 await assert.rejects(db.query('delete from public.historial_representaciones where representacion_id=$1',[r.id]),/inmutable|No se permite|editar|históric|solo lectura/i);
 // Las nuevas rutas y políticas también dependen de la sesión única vigente.
 await db.exec(`create table auth.sessions(id uuid primary key,user_id uuid,created_at timestamptz);
 create function auth.jwt() returns jsonb language sql stable as $$select nullif(current_setting('request.jwt.claims',true),'')::jsonb$$;
 grant execute on function auth.jwt() to authenticated;`);
 await db.exec(fs.readFileSync(new URL('../scripts/control_sesiones.sql',import.meta.url),'utf8'));
 await assert.rejects(reservar(),/Sesión no disponible/);
 const sid=crypto.randomUUID();await db.query('insert into auth.sessions values($1,$2,clock_timestamp())',[sid,users.chimbote]);
 assert.equal((await rpc('control_sesion',{p_accion:'iniciar'},users.chimbote,sid)).ok,true);
 assert.ok((await asUser(users.chimbote,tx=>tx.query('select id from public.representaciones_empresa'),sid)).rows.length>0);
 await db.query("update private.sesiones_asesor set ultima_actividad=clock_timestamp()-interval '16 minutes' where asesor_id=$1",[users.chimbote]);
 await assert.rejects(asUser(users.chimbote,tx=>tx.query('select id from public.representaciones_empresa'),sid),/Sesión no disponible/);
 console.log('PASS: filtros DNI/RUC10 sin duplicar, PDF y límites, archivo privado, firma del servidor, revisión autorizada, RLS, idempotencia, poderes por firmante e importe, límite global entre agencias y conservación de operaciones.');
}finally{await db.close();}
