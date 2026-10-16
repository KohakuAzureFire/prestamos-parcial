// Run locally after applying the migration; output is for the private SQL Editor only.
import fs from 'node:fs';import crypto from 'node:crypto';
const path=new URL('../.env.local',import.meta.url);let env=fs.existsSync(path)?fs.readFileSync(path,'utf8'):'';
let key=env.match(/^IDENTITY_SIGNING_SECRET=(.+)$/m)?.[1]?.trim();
if(!key){key=crypto.randomBytes(32).toString('hex');env+='\nIDENTITY_SIGNING_SECRET='+key+'\n';fs.writeFileSync(path,env);}
if(!/^[a-f0-9]{64}$/.test(key))throw Error('IDENTITY_SIGNING_SECRET debe contener 64 caracteres hexadecimales.');
console.log('-- Ejecuta únicamente en el SQL Editor del proyecto autorizado.\n-- Configura en el despliegue el mismo IDENTITY_SIGNING_SECRET de .env.local.');
console.log("insert into private.configuracion(clave,valor) values ('identity_signing_secret','"+key+"') on conflict(clave) do update set valor=excluded.valor;");
