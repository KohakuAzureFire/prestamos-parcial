import {PGlite} from '@electric-sql/pglite';
import {pgcrypto} from '@electric-sql/pglite/contrib/pgcrypto';
import fs from 'node:fs';import crypto from 'node:crypto';import assert from 'node:assert/strict';
export const db=new PGlite({extensions:{pgcrypto}});await db.waitReady;
const base=`create role anon;create role authenticated;create schema auth;create schema extensions;create extension pgcrypto with schema extensions;
create function auth.uid() returns uuid language sql stable as $$select (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid$$;
grant usage on schema auth to authenticated;grant execute on function auth.uid() to authenticated;
create table auth.users(id uuid primary key,email text);
create type public.condicion_cliente as enum('activo','restringido','fallecido','extrajudicial');create type public.estado_prestamo as enum('borrador','confirmado');
create table public.agencias(id uuid primary key default gen_random_uuid(),nombre text not null,created_at timestamptz default now());
create table public.asesores(id uuid primary key references auth.users(id),agencia_id uuid references public.agencias(id),nombre_completo text,activo boolean default true,created_at timestamptz default now(),updated_at timestamptz default now());
create table public.clientes(id uuid primary key default gen_random_uuid(),dni varchar(8) unique not null check(dni~'^[0-9]{8}$'),nombres text not null,apellidos text not null,condicion public.condicion_cliente default 'activo',fuente_verificacion text,resultado_verificacion text,fecha_verificacion timestamptz,asesor_id uuid references public.asesores(id),created_at timestamptz default now(),updated_at timestamptz default now());
create table public.prestamos(id uuid primary key default gen_random_uuid(),cliente_id uuid references public.clientes(id),agencia_id uuid references public.agencias(id),asesor_id uuid references public.asesores(id),fecha_prestamo date,monto numeric(14,2) check(monto>0),plazo_meses integer check(plazo_meses between 1 and 60),tea numeric default .3 check(tea=.3),estado public.estado_prestamo default 'borrador',confirmado_at timestamptz,created_at timestamptz default now());
create table public.cuotas(id uuid primary key default gen_random_uuid(),prestamo_id uuid references public.prestamos(id),numero_cuota integer,fecha_vencimiento date,cuota_total numeric(14,2),interes numeric(14,2),amortizacion numeric(14,2),saldo numeric(14,2),created_at timestamptz default now(),unique(prestamo_id,numero_cuota));
create function public.capital_vigente(uuid,uuid default null) returns numeric language sql as $$select 0::numeric$$;
create function public.handle_new_user() returns trigger language plpgsql as $$begin return new;end$$;
create function public.set_updated_at() returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
alter table public.agencias enable row level security;alter table public.asesores enable row level security;alter table public.clientes enable row level security;alter table public.prestamos enable row level security;alter table public.cuotas enable row level security;`;
await db.exec(base);
// Reproduce pre-migration data; no queries are sent to the real project here.
const snap=JSON.parse(fs.readFileSync(new URL('./fixtures.json',import.meta.url),'utf8'));
for(const t of ['agencias','asesores','clientes','prestamos','cuotas']){
 for(const row of snap[t]){
 if(t==='asesores')await db.query('insert into auth.users(id,email) values($1,$2)',[row.id,row.nombre_completo.startsWith('Ana Morales')?'asesor@prestamos.pe':row.id+'@test.local']);
 const keys=Object.keys(row);await db.query(`insert into public.${t}(${keys.join(',')}) values(${keys.map((_,i)=>'$'+(i+1)).join(',')})`,Object.values(row));
 }}
const sql=fs.readFileSync(new URL('../supabase/migrations/20261016054059_prestamos_pagos_agencias.sql',import.meta.url),'utf8').replace(/-- BEGIN CRON[\s\S]*?-- END CRON/,'');
await db.exec(sql);
export const users={chimbote:snap.asesores.find(a=>a.nombre_completo.startsWith('Carlos')).id,trujillo:snap.asesores.find(a=>a.nombre_completo.startsWith('Lucía')).id};
export const secret='solo-pruebas-locales-clave-de-firma';await db.query('insert into private.configuracion values($1,$2)',['identity_signing_secret',secret]);
export async function asUser(uid,fn){return db.transaction(async tx=>{await tx.exec('set local role authenticated');await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:uid,role:'authenticated'})]);return fn(tx);});}
export async function rpc(name,args,uid=users.chimbote){const keys=Object.keys(args);return asUser(uid,async tx=>(await tx.query(`select public.${name}(${keys.map((k,i)=>k+'=> $'+(i+1)).join(',')}) as result`,Object.values(args))).rows[0].result);}
export function proof(dni,uid=users.chimbote){const payload=JSON.stringify({dni,nombres:'CLIENTE',apellidos:'PRUEBA',asesor_id:uid,consultadoEn:new Date().toISOString()});return {p_payload:payload,p_firma:crypto.createHmac('sha256',secret).update(payload).digest('hex'),p_evidencia:{caducidad:'2030-12-31',original:true,no_fallecido:true,vigencia:'DNI original local',supervivencia:'Constancia oficial de prueba'}};}
export async function runTests(){
assert.equal((await db.query('select count(*)::int n from public.prestamos')).rows[0].n,3);
assert.equal((await db.query('select count(*)::int n from public.cuotas')).rows[0].n,57);
assert.equal((await db.query("select count(*)::int n from public.asesores where nombre_completo like 'Ana Morales%'")).rows[0].n,0);
const own=await asUser(users.chimbote,tx=>tx.query('select id from public.prestamos'));assert.equal(own.rows.length,1);
const loanTrujillo=snap.prestamos.find(p=>p.agencia_id===snap.asesores.find(a=>a.id===users.trujillo).agencia_id);
assert.equal((await asUser(users.chimbote,tx=>tx.query('select * from public.prestamos where id=$1',[loanTrujillo.id]))).rows.length,0);
await assert.rejects(asUser(users.chimbote,tx=>tx.query("update public.clientes set condicion='activo'")),/permission denied/);
await assert.rejects(rpc('registrar_identidad',{...proof('00000009'),p_firma:'falsa'}),/inválida/);
const id=await rpc('registrar_identidad',proof('00000009'));
const clave=crypto.randomUUID();const loan=await rpc('crear_prestamo',{p_cliente:id,p_monto:1000,p_meses:6,p_clave:clave});
assert.equal(await rpc('crear_prestamo',{p_cliente:id,p_monto:1000,p_meses:6,p_clave:clave}),loan);
await assert.rejects(rpc('crear_prestamo',{p_cliente:id,p_monto:1001,p_meses:6,p_clave:clave}),/otra operación/);
await assert.rejects(rpc('crear_prestamo',{p_cliente:id,p_monto:9500,p_meses:6,p_clave:crypto.randomUUID()}),/capital disponible/);
const schedule=(await db.query('select * from public.cuotas where prestamo_id=$1 order by numero_cuota',[loan])).rows;
assert.deepEqual(schedule.map(c=>Number(c.cuota_total)),[179.80,179.80,179.80,179.80,179.80,179.77]);
const key=crypto.randomUUID(),params={p_prestamo:loan,p_cantidad:1,p_clave:key,p_primera:schedule[0].id};
const pay=await rpc('registrar_pago',params,users.trujillo);assert.equal(await rpc('registrar_pago',params,users.trujillo),pay);
await assert.rejects(rpc('registrar_pago',{...params,p_clave:crypto.randomUUID()},users.chimbote),/ya fueron pagadas/);
const rec=await rpc('constancia_pago',{p_pago:pay},users.trujillo);assert.equal(rec.agencia_origen,'Chimbote');assert.equal(rec.agencia_cobro,'Trujillo');
let status=await rpc('resumen_cliente',{p_cliente:id});assert.equal(Number(status.capital_pendiente),842.30);assert.equal(status.verificacion,'aprobada');
// Date thresholds use the original due date, independent of identity.
let dates=await asUser(users.chimbote,tx=>tx.query('select private.situacion($1,$2::date) s',[id,schedule[1].fecha_vencimiento]));assert.equal(dates.rows[0].s.condicion_pago,'habilitado');
const due=schedule[1].fecha_vencimiento;dates=await asUser(users.chimbote,tx=>tx.query("select private.situacion($1,($2::date+1)) s, private.situacion($1,($2::date+interval '12 months')::date) e",[id,due]));assert.equal(dates.rows[0].s.condicion_pago,'moroso');assert.equal(dates.rows[0].e.condicion_pago,'extrajudicial');
await db.query("update public.clientes set dni_caducidad=public.fecha_peru()-1 where id=$1",[id]);status=await rpc('resumen_cliente',{p_cliente:id});assert.equal(status.verificacion,'caducada');assert.equal(status.elegible,false);
await assert.rejects(rpc('crear_prestamo',{p_cliente:id,p_monto:10,p_meses:1,p_clave:crypto.randomUUID()}),/no elegible/);
const final=await rpc('registrar_pago',{p_prestamo:loan,p_cantidad:5,p_clave:crypto.randomUUID(),p_primera:schedule[1].id},users.trujillo);
status=await rpc('resumen_cliente',{p_cliente:id});assert.equal(Number(status.capital_pendiente),0);assert.equal(status.verificacion,'caducada');
assert.equal((await db.query('select estado_deuda from public.prestamos where id=$1',[loan])).rows[0].estado_deuda,'cancelado');assert.ok(final);
const vida=(await db.query('select count(*)::int n from public.verificaciones_identidad where cliente_id=$1',[id])).rows[0].n;assert.equal(vida,1);
await assert.rejects(asUser(users.trujillo,tx=>tx.query('delete from public.pagos where id=$1',[pay])),/permission denied/);

await rpc('registrar_identidad',proof('00000009'));
const tiny=await rpc('crear_prestamo',{p_cliente:id,p_monto:.01,p_meses:60,p_clave:crypto.randomUUID()});
const positive=(await db.query('select id from public.cuotas where prestamo_id=$1 and cuota_total>0 order by numero_cuota',[tiny])).rows;
assert.equal(positive.length,1);
await rpc('registrar_pago',{p_prestamo:tiny,p_cantidad:1,p_clave:crypto.randomUUID(),p_primera:positive[0].id});
assert.equal((await db.query('select estado_deuda from public.prestamos where id=$1',[tiny])).rows[0].estado_deuda,'cancelado');
await assert.rejects(rpc('registrar_identidad',proof('00000019',users.chimbote),users.trujillo),/expiró/);
await db.exec('select private.corte_diario()');
console.log('PASS: migration, preserved data, RLS, identity signatures, atomic creation, global capital, cross-agency payment, retry idempotency, stale concurrent quote rejection, mora and 12-month boundary, expired DNI, final settlement and immutable audit.');
}
if(process.argv.includes('--test')){try{await runTests()}finally{await db.close()}}
