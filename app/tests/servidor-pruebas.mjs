// Servidor local de verificación: PGlite aislado; nunca conecta al proyecto real.
import {db,users,asUser,rpc,secret} from './operaciones.test.mjs';import fs from 'node:fs';import http from 'node:http';import {randomUUID} from 'node:crypto';
for(const n of fs.readdirSync(new URL('../supabase/migrations/',import.meta.url)).sort().filter(n=>!n.startsWith('20261016054059')&&!n.startsWith('20261016060800')))await db.exec(fs.readFileSync(new URL('../supabase/migrations/'+n,import.meta.url),'utf8'));
await db.exec(fs.readFileSync(new URL('../scripts/habilitar_modalidad_personal.sql',import.meta.url),'utf8'));
await db.exec(fs.readFileSync(new URL('../scripts/revalidacion_y_pagos_globales.sql',import.meta.url),'utf8'));
await db.exec(fs.readFileSync(new URL('../scripts/fichas_compartidas_y_grupo_pago.sql',import.meta.url),'utf8'));
await db.query('insert into private.permisos_operacion values($1,true,true)',[users.chimbote]);
await db.exec(`create table auth.sessions(id uuid primary key,user_id uuid,created_at timestamptz);
create function auth.jwt() returns jsonb language sql stable as $$select nullif(current_setting('request.jwt.claims',true),'')::jsonb$$;
grant execute on function auth.jwt() to authenticated;`);
await db.exec(fs.readFileSync(new URL('../scripts/control_sesiones.sql',import.meta.url),'utf8'));
const jwt=(uid,sid)=>[Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({sub:uid,session_id:sid,role:'authenticated',aud:'authenticated',exp:Math.floor(Date.now()/1000)+7200})).toString('base64url'),'local-test-signature'].join('.');
const usuario=id=>({id,email:id===users.trujillo?'trujillo@test.local':'chimbote@test.local',aud:'authenticated',role:'authenticated',app_metadata:{provider:'email'},user_metadata:{},created_at:new Date().toISOString()});
const rows=async(uid,sid,sql,args=[])=> (await asUser(uid,tx=>tx.query(sql,args),sid)).rows;
const tables=new Set(['asesores','agencias','parametros_negocio','clientes','clientes_resumen','prestamos','prestamos_resumen','cuotas','verificaciones_con_agencia','verificaciones_ruc']);
http.createServer(async(req,res)=>{res.setHeader('Access-Control-Allow-Origin',req.headers.origin||'http://127.0.0.1:3001');res.setHeader('Access-Control-Allow-Headers','authorization,apikey,content-type,x-client-info,prefer,x-supabase-api-version');res.setHeader('Access-Control-Allow-Methods','GET,POST,DELETE,OPTIONS');res.setHeader('Access-Control-Expose-Headers','content-range');if(req.method==='OPTIONS'){res.end();return;}
 const url=new URL(req.url,'http://localhost:54329');let body='';for await(const chunk of req)body+=chunk;let args={};try{args=body?JSON.parse(body):{};}catch{}
 const token=(req.headers.authorization||'').replace(/^Bearer /,'');let uid=users.chimbote,sid;try{const claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url'));uid=claims.sub||uid;sid=claims.session_id;}catch{}
 const send=(status,data)=>{res.statusCode=status;res.setHeader('Content-Type','application/json');res.end(JSON.stringify(data));};
 try{
 if(url.pathname==='/auth/v1/token'){uid=args.email?.startsWith('trujillo')?users.trujillo:users.chimbote;sid=randomUUID();await db.query('insert into auth.sessions values($1,$2,clock_timestamp())',[sid,uid]);send(200,{access_token:jwt(uid,sid),refresh_token:'local-refresh',token_type:'bearer',expires_in:7200,expires_at:Math.floor(Date.now()/1000)+7200,user:usuario(uid)});return;}
 if(url.pathname==='/auth/v1/user'){send(200,usuario(uid));return;}
 if(url.pathname==='/auth/v1/logout'){await db.query('delete from auth.sessions where id=$1',[sid]);send(200,{});return;}
 if(url.pathname==='/__sesion'&&req.method==='POST'){await db.query("update private.sesiones_asesor set ultima_actividad=clock_timestamp()-($1 * interval '1 second') where asesor_id=$2",[args.segundos,users.trujillo]);send(200,{});return;}
 if(url.pathname==='/__count'){send(200,(await db.query('select count(*)::int n from public.clientes')).rows[0]);return;}
 if(url.pathname==='/__state'){send(200,(await db.query("select c.dni,c.ruc,p.id from public.clientes c join public.prestamos p on p.cliente_id=c.id where p.conciliado and c.ruc is not null order by p.created_at desc")).rows);return;}
 if(url.pathname==='/__mora'&&req.method==='POST'){await db.query('update public.prestamos set tasa_moratoria_anual=.12 where id=$1',[args.loan]);await db.query('update public.cuotas set fecha_vencimiento=public.fecha_peru()-30 where prestamo_id=$1 and numero_cuota=1',[args.loan]);send(200,{});return;}
 if(url.pathname.startsWith('/rest/v1/rpc/')){const name=url.pathname.split('/').at(-1);if(!/^[a-z_]+$/.test(name))throw new Error('RPC inválida');send(200,await rpc(name,args,uid,sid));return;}
 const table=url.pathname.split('/').at(-1);if(!tables.has(table)){send(404,{message:'Recurso de prueba no disponible'});return;}
 const params=[];const where=[];for(const [k,v] of url.searchParams){if(['select','order','limit','offset'].includes(k))continue;if(!/^[a-z_]+$/.test(k))continue;if(v.startsWith('eq.')){params.push(v.slice(3));where.push(k+'=$'+params.length);}else if(v.startsWith('in.(')){const vals=v.slice(4,-1).split(',');params.push(vals);where.push(k+'::text=any($'+params.length+'::text[])');}}
 const order=url.searchParams.get('order');const orderSql=order&&/^[a-z_]+\.(asc|desc)$/.test(order)?' order by '+order.replace('.',' '):'';
 let result=await rows(uid,sid,'select * from public.'+table+(where.length?' where '+where.join(' and '):'')+orderSql,params);
 const offset=Number(url.searchParams.get('offset')||0),limit=Number(url.searchParams.get('limit')||1000);result=result.slice(offset,offset+limit);
 const select=url.searchParams.get('select')||'*';
 if(table==='asesores'&&select.includes('agencias('))for(const a of result)a.agencias=(await rows(uid,sid,'select * from public.agencias where id=$1',[a.agencia_id]))[0];
 if((table==='prestamos'||table==='prestamos_resumen')&&select.includes('clientes('))for(const p of result){p.clientes=(await rows(uid,sid,'select * from public.clientes where id=$1',[p.cliente_id]))[0];if(select.includes('agencias('))p.agencias=(await rows(uid,sid,'select * from public.agencias where id=$1',[p.agencia_id]))[0];if(select.includes('asesores('))p.asesores={nombre_completo:'Asesor de origen'};if(select.includes('cuotas('))p.cuotas=await rows(uid,sid,'select * from public.cuotas where prestamo_id=$1',[p.id]);}
 if((req.headers.accept||'').includes('vnd.pgrst.object')){if(result.length!==1){send(406,{code:'PGRST116',details:result.length===0?'The result contains 0 rows':'Multiple rows',message:'No se encontró un único registro'});return;}result=result[0];}
 send(200,result);
 }catch(e){send(e.code==='42501'?403:400,{message:e.message,code:e.code||'TEST_ERROR'});}
}).listen(54329,'127.0.0.1',()=>console.log('Servidor de pruebas aislado listo en 54329; clave de firma local '+(secret?'configurada':'ausente')));
