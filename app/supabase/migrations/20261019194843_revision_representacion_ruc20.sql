-- Representación de RUC 20: PDF privado, revisión manual y control antes de prestar.
-- Aplicar después del retiro de cargos del 18/10. No crea préstamos ni migra aprobaciones antiguas.
begin;
create table public.representaciones_empresa(
 id uuid primary key default gen_random_uuid(),
 ruc text not null check(ruc ~ '^20[0-9]{9}$'),razon_social text not null,
 propietario_dni text not null check(propietario_dni ~ '^[0-9]{8}$'),
 representante_dni text not null check(representante_dni ~ '^[0-9]{8}$'),
 asesor_id uuid not null references public.asesores(id),agencia_id uuid not null references public.agencias(id),
 archivo_ruta text not null unique,archivo_nombre text not null check(length(archivo_nombre) between 5 and 150),
 archivo_bytes integer not null check(archivo_bytes between 1 and 5242880),archivo_sha256 text,
 fecha_emision date not null,
 estado text not null default 'cargando' check(estado in ('cargando','pendiente','revisada','observada','descartada')),
 observacion text,referencia_validacion text,revisor_id uuid references public.asesores(id),revisado_at timestamptz,
 valida_hasta date,monto_maximo numeric(14,2),version integer not null default 1,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(estado not in ('pendiente','revisada','observada') or (archivo_sha256 is not null and archivo_sha256 ~ '^[a-f0-9]{64}$')),
 check(estado<>'revisada' or (valida_hasta is not null and monto_maximo is not null and monto_maximo>0 and revisor_id is not null))
);
create index representaciones_agencia_fecha on public.representaciones_empresa(agencia_id,created_at desc);
create index representaciones_identidad on public.representaciones_empresa(ruc,propietario_dni,representante_dni,agencia_id);
create table public.historial_representaciones(
 id uuid primary key default gen_random_uuid(),representacion_id uuid not null references public.representaciones_empresa(id),
 asesor_id uuid not null references public.asesores(id),estado text not null,detalle text not null,created_at timestamptz not null default now()
);
create index historial_representacion_fecha on public.historial_representaciones(representacion_id,created_at);
alter table public.representaciones_empresa enable row level security;
alter table public.historial_representaciones enable row level security;
revoke all on public.representaciones_empresa,public.historial_representaciones from anon,authenticated;
grant select on public.representaciones_empresa,public.historial_representaciones to authenticated;
create function private.revisa_representacion() returns boolean language plpgsql stable security definer set search_path='' as $$begin
 perform private.asesor();return coalesce((private.permisos_actuales()->>'autoriza_credito')::boolean,false);
end$$;
create function private.ver_representacion(p_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;begin
 a:=private.asesor();return exists(select 1 from public.representaciones_empresa r where r.id=p_id and (r.agencia_id=a.agencia_id or private.revisa_representacion()));
end$$;
create policy representaciones_lectura on public.representaciones_empresa for select to authenticated using(private.ver_representacion(id));
create policy representaciones_historial_lectura on public.historial_representaciones for select to authenticated using(private.ver_representacion(representacion_id));
create trigger historial_representaciones_inmutable before update or delete on public.historial_representaciones for each row execute function private.sin_edicion();

-- Solo el servidor de la aplicación certifica el formato después de leer los bytes.
create function private.reservar_representacion(p_consulta jsonb,p_propietario text,p_representante text,p_nombre text,p_bytes integer,p_emision date) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.asesores;d jsonb;rid uuid:=gen_random_uuid();ruta text;r public.representaciones_empresa;begin
 a:=private.asesor();d:=private.comprobar_firma(p_consulta->>'payload',p_consulta->>'firma','ruc');
 if not private.validar_ruc(d->>'ruc') or left(d->>'ruc',2)<>'20' or d->>'estado'<>'ACTIVO' or d->>'condicion'<>'HABIDO' then raise exception 'La empresa debe tener RUC 20 ACTIVO y HABIDO.';end if;
 if p_propietario is null or p_propietario!~'^[0-9]{8}$' or p_representante is null or p_representante!~'^[0-9]{8}$' then raise exception 'Identifique al propietario y al representante.';end if;
 if p_nombre is null or length(p_nombre)>150 or lower(p_nombre) not like '%.pdf' or p_bytes is null or p_bytes<1 or p_bytes>5242880 then raise exception 'Solo PDF de hasta 5 MB.';end if;
 if p_emision is null or p_emision>public.fecha_peru() then raise exception 'Revise la fecha de emisión del certificado.';end if;
 if exists(select 1 from public.clientes c join public.clientes o on o.id=c.propietario_id where c.ruc=d->>'ruc' and o.dni<>p_propietario) then raise exception 'La empresa está vinculada a otro propietario; requiere revisión administrativa.';end if;
 ruta:=a.id::text||'/'||rid::text||'.pdf';
 insert into public.representaciones_empresa(id,ruc,razon_social,propietario_dni,representante_dni,asesor_id,agencia_id,archivo_ruta,archivo_nombre,archivo_bytes,fecha_emision)
 values(rid,d->>'ruc',d->>'razon_social',p_propietario,p_representante,a.id,a.agencia_id,ruta,p_nombre,p_bytes,p_emision) returning * into r;
 return to_jsonb(r);
end$$;
create function private.finalizar_representacion(p_payload text,p_firma text) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb;r public.representaciones_empresa;begin
 d:=private.comprobar_firma(p_payload,p_firma,'certificado_pdf');
 select * into r from public.representaciones_empresa where id=(d->>'id')::uuid for update;
 if r.id is null or r.asesor_id<>auth.uid() then raise exception 'Solicitud no disponible.' using errcode='42501';end if;
 if r.estado<>'cargando' then
  if r.archivo_sha256=d->>'sha256' and r.estado in ('pendiente','revisada','observada') then return to_jsonb(r);end if;
  raise exception 'El archivo ya fue procesado o descartado.';
 end if;
 if d->>'ruta' is distinct from r.archivo_ruta or (d->>'bytes')::integer is distinct from r.archivo_bytes or d->>'sha256' !~ '^[a-f0-9]{64}$' then raise exception 'Archivo verificado no coincide con la solicitud.';end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='certificados-representacion' and o.name=r.archivo_ruta and (o.metadata->>'size')::bigint=r.archivo_bytes and o.metadata->>'mimetype'='application/pdf') then raise exception 'No se encontró el PDF privado completo.';end if;
 update public.representaciones_empresa set estado='pendiente',archivo_sha256=d->>'sha256',version=version+1,updated_at=now() where id=r.id returning * into r;
 insert into public.historial_representaciones(representacion_id,asesor_id,estado,detalle) values(r.id,auth.uid(),'pendiente','PDF recibido; pendiente de revisión manual.');
 return to_jsonb(r);
end$$;
create function private.descartar_representacion(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare a public.asesores;begin
 a:=private.asesor();update public.representaciones_empresa set estado='descartada',version=version+1,updated_at=now() where id=p_id and asesor_id=a.id and estado='cargando';
end$$;
create function private.revisar_representacion(p_id uuid,p_version integer,p_estado text,p_observacion text,p_referencia text,p_hasta date,p_maximo numeric,p_facultades boolean,p_individual boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.representaciones_empresa;begin
 if not private.revisa_representacion() then raise exception 'No tiene permiso para revisar representaciones.' using errcode='42501';end if;
 select * into r from public.representaciones_empresa where id=p_id for update;
 if r.id is null or r.estado not in ('pendiente','revisada') then raise exception 'La solicitud no está disponible para revisión.';end if;
 if p_version is distinct from r.version then raise exception 'La revisión cambió. Actualice antes de resolver.';end if;
 if p_estado not in ('revisada','observada') or p_estado is null or length(trim(coalesce(p_observacion,'')))<10 or length(p_observacion)>1000 then raise exception 'Seleccione el resultado y documente la revisión.';end if;
 if p_estado='revisada' then
  if r.estado<>'pendiente' or p_facultades is distinct from true or p_individual is distinct from true or length(trim(coalesce(p_referencia,'')))<8 or length(p_referencia)>500 then raise exception 'Compruebe autenticidad, facultades y firma individual, con referencia de validación.';end if;
  if p_hasta is null or p_hasta<public.fecha_peru() or p_hasta>public.fecha_peru()+30 then raise exception 'La revisión debe vencer entre hoy y los próximos 30 días, según la política académica.';end if;
  if p_maximo is null or p_maximo<=0 or p_maximo<>round(p_maximo,2) or p_maximo>private.parametro('capital_maximo') then raise exception 'Registre el monto máximo autorizado por las facultades, hasta el límite del sistema.';end if;
 end if;
 update public.representaciones_empresa set estado=p_estado,observacion=trim(p_observacion),referencia_validacion=case when p_estado='revisada' then trim(p_referencia) else referencia_validacion end,
 revisor_id=auth.uid(),revisado_at=now(),valida_hasta=case when p_estado='revisada' then p_hasta else null end,monto_maximo=case when p_estado='revisada' then p_maximo else null end,version=version+1,updated_at=now() where id=p_id returning * into r;
 insert into public.historial_representaciones(representacion_id,asesor_id,estado,detalle) values(r.id,auth.uid(),p_estado,trim(p_observacion));return to_jsonb(r);
end$$;
create function private.exigir_representacion(p_id uuid,p_ruc text,p_propietario text,p_representante text,p_monto numeric) returns public.representaciones_empresa
language plpgsql security definer set search_path='' as $$
declare a public.asesores;r public.representaciones_empresa;begin
 a:=private.asesor();select * into r from public.representaciones_empresa where id=p_id for share;
 if exists(select 1 from public.representaciones_empresa nueva where nueva.ruc=r.ruc and nueva.propietario_dni=r.propietario_dni and nueva.representante_dni=r.representante_dni and nueva.agencia_id=r.agencia_id and nueva.estado in ('pendiente','revisada','observada') and (nueva.created_at,nueva.id)>(r.created_at,r.id)) then raise exception 'Hay una presentación posterior; revise el certificado más reciente.';end if;
 if r.id is null or r.estado<>'revisada' or r.valida_hasta<public.fecha_peru() or r.agencia_id<>a.agencia_id or r.ruc is distinct from p_ruc or r.propietario_dni is distinct from p_propietario or r.representante_dni is distinct from p_representante or p_monto>r.monto_maximo then
 raise exception 'La empresa requiere una representación revisada, vigente y suficiente para este propietario, firmante e importe.';end if;return r;
end$$;
-- Envoltorios públicos sin privilegios adicionales.
create function public.reservar_representacion(p_consulta jsonb,p_propietario text,p_representante text,p_nombre text,p_bytes integer,p_emision date) returns jsonb language sql security invoker set search_path='' as $$select private.reservar_representacion(p_consulta,p_propietario,p_representante,p_nombre,p_bytes,p_emision)$$;
create function public.finalizar_representacion(p_payload text,p_firma text) returns jsonb language sql security invoker set search_path='' as $$select private.finalizar_representacion(p_payload,p_firma)$$;
create function public.descartar_representacion(p_id uuid) returns void language sql security invoker set search_path='' as $$select private.descartar_representacion(p_id)$$;
create function public.revisar_representacion(p_id uuid,p_version integer,p_estado text,p_observacion text,p_referencia text,p_hasta date,p_maximo numeric,p_facultades boolean,p_individual boolean) returns jsonb language sql security invoker set search_path='' as $$select private.revisar_representacion(p_id,p_version,p_estado,p_observacion,p_referencia,p_hasta,p_maximo,p_facultades,p_individual)$$;

-- Sin URL pública ni sustitución de un PDF ya presentado.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('certificados-representacion','certificados-representacion',false,5242880,array['application/pdf']);
create function private.archivo_representacion(p_ruta text,p_accion text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;begin
 a:=private.asesor();return exists(select 1 from public.representaciones_empresa r where r.archivo_ruta=p_ruta and
 case when p_accion='leer' then r.estado<>'descartada' and private.ver_representacion(r.id)
 when p_accion='subir' then r.asesor_id=a.id and r.agencia_id=a.agencia_id and r.estado='cargando' else false end);
end$$;
create policy certificado_insert on storage.objects for insert to authenticated with check(bucket_id='certificados-representacion' and private.archivo_representacion(name,'subir'));
create policy certificado_select on storage.objects for select to authenticated using(bucket_id='certificados-representacion' and private.archivo_representacion(name,'leer'));
-- El archivo no se sustituye ni se borra, tampoco durante la verificación del servidor.
-- Permisos explícitos: ningún RPC nuevo es ejecutable por anon o PUBLIC.
do $$declare f record;begin
 for f in select p.oid::regprocedure firma,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname in ('revisa_representacion','ver_representacion','reservar_representacion','finalizar_representacion','descartar_representacion','revisar_representacion','exigir_representacion','archivo_representacion') loop
 execute format('revoke all on function %s from public,anon,authenticated',f.firma);
 if f.firma::text not like 'private.exigir_representacion%' then execute format('grant execute on function %s to authenticated',f.firma);end if;
 end loop;
end$$;
-- Las funciones de creación se actualizan a continuación conservando sus validaciones previas.

CREATE OR REPLACE FUNCTION private.confirmar_ruc_prestamo(p_datos jsonb, p_monto numeric, p_meses integer, p_clave uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;d jsonb;r text;o uuid;rep uuid;c public.clientes;p_id uuid;revision public.representaciones_empresa;begin
 a:=private.asesor();r:=p_datos#>>'{consulta,ruc}';if not private.validar_ruc(r) or p_clave is null then raise exception 'RUC o solicitud inválida.';end if;
 perform pg_advisory_xact_lock(hashtextextended(r,6));
 select p.id into p_id from public.prestamos p join public.clientes cc on cc.id=p.cliente_id where p.clave_operacion=p_clave and p.asesor_id=a.id and cc.ruc=r and p.monto=p_monto and p.plazo_meses=p_meses;
 if p_id is not null then return p_id;end if;
 if exists(select 1 from public.prestamos where clave_operacion=p_clave) then raise exception 'La clave pertenece a otra operación.';end if;
 d:=private.comprobar_firma(p_datos#>>'{consulta,payload}',p_datos#>>'{consulta,firma}','ruc');
 if d->>'ruc' is distinct from r or d->>'estado' is distinct from 'ACTIVO' or d->>'condicion' is distinct from 'HABIDO' or length(trim(coalesce(d->>'razon_social','')))=0 then raise exception 'El RUC debe existir, estar ACTIVO y HABIDO.';end if;
 if r like '20%' then revision:=private.exigir_representacion((p_datos->>'representacion_id')::uuid,r,p_datos#>>'{propietario,dni}',p_datos#>>'{representante,dni}',p_monto);end if;
 -- A single group mutex serializes personal and company loans across all branches.
 -- Ordered DNI locks avoid deadlock when owner and signatory differ.
 perform pg_advisory_xact_lock(hashtextextended(least(p_datos#>>'{propietario,dni}',p_datos#>>'{representante,dni}'),0));
 perform pg_advisory_xact_lock(hashtextextended(greatest(p_datos#>>'{propietario,dni}',p_datos#>>'{representante,dni}'),0));
 o:=private.persona_ruc(p_datos->'propietario');if p_datos#>>'{representante,dni}'=p_datos#>>'{propietario,dni}' then rep:=o;else rep:=private.persona_ruc(p_datos->'representante');end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text,4));
 if r like '10%' then
 if substring(r,3,8) is distinct from (select dni from public.clientes where id=o) or o<>rep then raise exception 'El RUC 10 debe corresponder al DNI de su titular.';end if;
 select * into c from public.clientes where id=o for update;
 if c.ruc is not null and c.ruc<>r then raise exception 'El titular ya tiene otro RUC asociado.';end if;
 else
 if coalesce((p_datos->>'propiedad_confirmada')::boolean,false) is not true or length(trim(coalesce(p_datos->>'evidencia_propiedad','')))<10 or length(trim(coalesce(p_datos->>'evidencia_poder','')))<10 then raise exception 'Registre evidencia de propiedad y facultades del representante.';end if;
 select * into c from public.clientes where ruc=r for update;
 if c.id is not null and c.propietario_id<>o then raise exception 'El RUC ya está vinculado a otro propietario. Requiere revisión administrativa; no se reasigna capital.';end if;
 if c.id is null then
 insert into public.clientes(dni,nombres,apellidos,tipo_cliente,ruc,propietario_id,representante_id,asesor_id,verificacion_resultado)
 values(null,d->>'razon_social','','juridica',r,o,rep,a.id,'aprobada') returning * into c;
 end if;
 end if;
 update public.clientes set ruc=r,razon_social=d->>'razon_social',estado_ruc=d->>'estado',condicion_ruc=d->>'condicion',direccion_fiscal=d->>'direccion',ruc_consultado_at=(d->>'consultadoEn')::timestamptz,representante_id=case when tipo_cliente='juridica' then rep else null end,evidencia_propiedad=left(p_datos->>'evidencia_propiedad',500),evidencia_poder=left(p_datos->>'evidencia_poder',500) where id=c.id;
 insert into public.verificaciones_ruc(cliente_id,ruc,razon_social,estado,condicion,direccion,propietario_id,representante_id,evidencia_propiedad,evidencia_poder,asesor_id,consultado_at)
 values(c.id,r,d->>'razon_social',d->>'estado',d->>'condicion',d->>'direccion',o,rep,coalesce(left(p_datos->>'evidencia_propiedad',500),'Titular RUC 10'),coalesce(left(p_datos->>'evidencia_poder',500),'Titular RUC 10'),a.id,(d->>'consultadoEn')::timestamptz);
 perform set_config('app.ruc_validado',r,true);
 perform set_config('app.representacion_id',coalesce(revision.id::text,''),true);
 p_id:=private.crear_prestamo(c.id,p_monto,p_meses,p_clave);
 if revision.id is not null then update public.prestamos set identidad_contrato=identidad_contrato||jsonb_build_object('representacion_id',revision.id,'representacion_sha256',revision.archivo_sha256,'representacion_revisor',revision.revisor_id,'representacion_revisada_at',revision.revisado_at) where id=p_id;end if;
 return p_id;
end$function$;

CREATE OR REPLACE FUNCTION private.crear_prestamo(p_cliente uuid, p_monto numeric, p_meses integer, p_clave uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;s jsonb;p_id uuid;tem numeric:=power(1.3::numeric,1.0/12)-1;cuota numeric;interes numeric;capital numeric;saldo numeric;fecha date:=public.fecha_peru();k int;begin
 a:=private.asesor();perform pg_advisory_xact_lock(hashtextextended(private.grupo(p_cliente)::text,4));perform 1 from public.clientes where id=p_cliente for update;
 select id into p_id from public.prestamos where clave_operacion=p_clave and asesor_id=a.id;
 if p_id is not null then
 if not exists(select 1 from public.prestamos where id=p_id and cliente_id=p_cliente and monto=p_monto and plazo_meses=p_meses) then raise exception 'La clave pertenece a otra operación.';end if;return p_id;end if;
 if exists(select 1 from public.clientes where id=p_cliente and ruc is not null and ruc is distinct from current_setting('app.ruc_validado',true)) then raise exception 'Vuelva al paso 1 para consultar y validar el RUC.';end if;
 s:=private.situacion(p_cliente);
 if not (s->>'elegible')::boolean then raise exception 'Cliente no elegible: revise DNI, condición de pago y conciliación.';end if;
 if p_clave is null or p_monto is null or p_monto<=0 or p_monto<>round(p_monto,2) or p_meses is null or p_meses<1 or p_meses>private.parametro('plazo_max_meses') then raise exception 'Monto o plazo inválido.';end if;
 if (s->>'capital_pendiente')::numeric+p_monto>private.parametro('capital_maximo') then raise exception 'El monto excede el capital disponible global.';end if;
 if exists(select 1 from public.clientes where id=p_cliente and tipo_cliente='juridica') then
  perform private.exigir_representacion(nullif(current_setting('app.representacion_id',true),'')::uuid,(select ruc from public.clientes where id=p_cliente),(select o.dni from public.clientes c join public.clientes o on o.id=c.propietario_id where c.id=p_cliente),(select r.dni from public.clientes c join public.clientes r on r.id=c.representante_id where c.id=p_cliente),p_monto);
 end if;
 insert into public.prestamos(cliente_id,agencia_id,asesor_id,fecha_prestamo,monto,plazo_meses,tea,estado,confirmado_at,conciliado,clave_operacion,identidad_contrato)
 values(p_cliente,a.agencia_id,a.id,fecha,p_monto,p_meses,0.30,'confirmado',now(),true,p_clave,(select to_jsonb(c)||jsonb_build_object('propietario',(select jsonb_build_object('dni',o.dni,'nombre',o.nombres||' '||o.apellidos) from public.clientes o where o.id=coalesce(c.propietario_id,c.id)),'representante',(select jsonb_build_object('dni',r.dni,'nombre',r.nombres||' '||r.apellidos) from public.clientes r where r.id=c.representante_id)) from public.clientes c where c.id=p_cliente)) returning id into p_id;
 cuota:=round(p_monto*tem/(1-power(1+tem,-p_meses)),2);saldo:=p_monto;
 for k in 1..p_meses loop
 interes:=round(saldo*tem,2);capital:=case when k=p_meses then saldo else round(cuota-interes,2) end;
 if k=p_meses then cuota:=capital+interes;end if;saldo:=round(saldo-capital,2);
 insert into public.cuotas(prestamo_id,numero_cuota,fecha_vencimiento,cuota_total,interes,amortizacion,saldo)
 values(p_id,k,(fecha+make_interval(months=>k))::date,cuota,interes,capital,saldo);
 end loop;return p_id;end$function$;

create view public.representaciones_resumen with(security_invoker=true) as
 select r.*,(private.autor_revision(r.asesor_id,r.agencia_id)->>'asesor') asesor_nombre,
 (private.autor_revision(r.asesor_id,r.agencia_id)->>'agencia') agencia_nombre,
 case when r.revisor_id is not null then private.autor_revision(r.revisor_id,r.agencia_id)->>'asesor' end revisor_nombre
 from public.representaciones_empresa r;
revoke all on public.representaciones_resumen from anon;
grant select on public.representaciones_resumen to authenticated;
notify pgrst,'reload schema';
commit;
