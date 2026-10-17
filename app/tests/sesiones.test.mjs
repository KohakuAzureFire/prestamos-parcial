// Ejecuta exclusivamente contra PostgreSQL local en memoria; nunca contra Supabase real.
import { db, users } from './operaciones.test.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
try {
 await db.exec(`create table auth.sessions(id uuid primary key,user_id uuid,created_at timestamptz);
 create function auth.jwt() returns jsonb language sql stable as $$select nullif(current_setting('request.jwt.claims',true),'')::jsonb$$;
 grant execute on function auth.jwt() to authenticated;`);
 const sql=fs.readFileSync(new URL('../scripts/control_sesiones.sql',import.meta.url),'utf8');
 await db.exec(sql);
 const uid=users.chimbote, sid=randomUUID(), otra=randomUUID();
 async function llamar(s,accion='estado',usuario=uid) { return db.transaction(async tx=>{
  await tx.exec('set local role authenticated');
  await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:usuario,session_id:s,role:'authenticated'})]);
  return (await tx.query('select public.control_sesion($1) result',[accion])).rows[0].result;
 }); }
 async function protegido(s) { return db.transaction(async tx=>{
  await tx.exec('set local role authenticated');
  await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:uid,session_id:s})]);
  return tx.query('select id from public.prestamos');
 }); }
 await db.query("insert into auth.sessions values($1,$2,clock_timestamp()-interval '1 minute')",[sid,uid]);
 assert.equal((await llamar(sid)).ok,false);
 assert.equal((await llamar(sid,'iniciar')).ok,true);
 await protegido(sid);
 const inicio=(await llamar(sid)).vence;
 assert.equal((await llamar(sid)).vence,inicio,'El sondeo no renueva la actividad');
 assert.equal((await llamar(sid,'iniciar')).vence,inicio,'Repetir iniciar tampoco renueva');
 await db.query("update private.sesiones_asesor set ultima_actividad=clock_timestamp()-interval '14 minutes 30 seconds' where asesor_id=$1",[uid]);
 assert.ok(Date.parse((await llamar(sid,'actividad')).vence)>Date.now()+14*60000);
 await db.query("update private.sesiones_asesor set ultima_actividad=clock_timestamp()-interval '16 minutes' where asesor_id=$1",[uid]);
 assert.equal((await llamar(sid,'actividad')).motivo,'inactividad');
 assert.equal((await llamar(sid,'iniciar')).motivo,'inactividad');
 await assert.rejects(protegido(sid),/Sesión no disponible/);
 await db.query('insert into auth.sessions values($1,$2,clock_timestamp())',[otra,uid]);
 assert.equal((await llamar(sid)).motivo,'reemplazada');
 assert.equal((await llamar(otra,'iniciar')).ok,true);
 await assert.rejects(protegido(sid),/Sesión no disponible/);
 await llamar(sid,'cerrar');
 assert.equal((await llamar(otra)).ok,true,'Cerrar sesión antigua no cierra la nueva');
 assert.equal((await llamar(otra,'iniciar',users.trujillo)).ok,false,'No se puede usar sesión de otra cuenta');
 await db.exec(sql);
 assert.equal((await llamar(otra)).ok,true,'Reaplicar SQL conserva la sesión');
 await llamar(otra,'cerrar');
 assert.equal((await llamar(otra,'iniciar')).motivo,'cerrada');
 await db.query('delete from auth.sessions where id=$1',[otra]);
 assert.equal((await llamar(sid,'iniciar')).ok,false,'Una sesión anterior no revive al borrar la más nueva');
 const numero=await db.query('select count(*)::int n from public.prestamos');
 assert.equal(numero.rows[0].n,3,'Los préstamos existentes se conservan');
 console.log('PASS: sesión única, vencimiento, actividad, sondeo, reintentos, cierre local, autorización en BD, SQL idempotente y conservación de préstamos.');
} finally { await db.close(); }
