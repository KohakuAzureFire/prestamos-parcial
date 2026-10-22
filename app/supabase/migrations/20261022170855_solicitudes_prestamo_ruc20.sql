-- Solicitudes RUC 20 completas; pendiente no es préstamo ni reserva capital.
-- Aplicar después de revision_representacion_ruc20. Conserva toda operación previa.
begin;
create table public.solicitudes_prestamo(
 id uuid primary key default gen_random_uuid(),clave_envio uuid not null unique,
 ruc text not null check(ruc ~ '^20[0-9]{9}$'),cliente_id uuid not null references public.clientes(id),
 propietario_id uuid not null references public.clientes(id),representante_id uuid not null references public.clientes(id),
 representacion_id uuid not null unique references public.representaciones_empresa(id),
 asesor_id uuid not null references public.asesores(id),agencia_id uuid not null references public.agencias(id),
 monto numeric(14,2) not null check(monto>0 and monto<=10000),plazo_meses integer not null check(plazo_meses between 1 and 60),
 estado text not null default 'pendiente' check(estado in ('pendiente','observada','rechazada','aprobada')),
 expediente jsonb not null,version integer not null default 1,motivo text,evaluador_id uuid references public.asesores(id),
 prestamo_id uuid unique references public.prestamos(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check((estado='aprobada')=(prestamo_id is not null))
);
create unique index solicitud_abierta_ruc on public.solicitudes_prestamo(ruc) where estado in ('pendiente','observada');
create index solicitudes_agencia_fecha on public.solicitudes_prestamo(agencia_id,created_at desc);
create index solicitudes_cliente on public.solicitudes_prestamo(cliente_id);
create table public.historial_solicitudes(
 id uuid primary key default gen_random_uuid(),solicitud_id uuid not null references public.solicitudes_prestamo(id),
 asesor_id uuid not null references public.asesores(id),estado text not null,detalle text not null,expediente jsonb not null,
 created_at timestamptz not null default now()
);
create index historial_solicitud_fecha on public.historial_solicitudes(solicitud_id,created_at);
alter table public.solicitudes_prestamo enable row level security;
alter table public.historial_solicitudes enable row level security;
revoke all on public.solicitudes_prestamo,public.historial_solicitudes from public,anon,authenticated;
grant select on public.solicitudes_prestamo,public.historial_solicitudes to authenticated;
create function private.ver_solicitud(p_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;begin a:=private.asesor();return exists(select 1 from public.solicitudes_prestamo s where s.id=p_id and s.agencia_id=a.agencia_id);end$$;
create policy solicitud_lectura on public.solicitudes_prestamo for select to authenticated using(private.ver_solicitud(id));
create policy solicitud_historial_lectura on public.historial_solicitudes for select to authenticated using(private.ver_solicitud(solicitud_id));
create trigger historial_solicitudes_inmutable before update or delete on public.historial_solicitudes for each row execute function private.sin_edicion();
create function private.resolver_solicitud_ruc(p_ruc text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;begin a:=private.asesor();select * into s from public.solicitudes_prestamo where ruc=p_ruc and estado in ('pendiente','observada');
 if s.id is null then return null;end if;return jsonb_build_object('id',case when s.agencia_id=a.agencia_id then s.id end,'estado',s.estado,'agencia',(select nombre from public.agencias where id=s.agencia_id));end$$;
create function public.resolver_solicitud_ruc(p_ruc text) returns jsonb language sql stable security invoker set search_path='' as $$select private.resolver_solicitud_ruc(p_ruc)$$;
-- Solo usada dentro del envío final, en su misma transacción; sin acceso directo del cliente.
create function private.preparar_empresa_solicitud(p_datos jsonb,p_clave uuid) returns uuid language plpgsql security definer set search_path='' as $$

declare a public.asesores;d jsonb;r text;o uuid;rep uuid;c public.clientes;p_id uuid;begin
 a:=private.asesor();r:=p_datos#>>'{consulta,ruc}';if not private.validar_ruc(r) or p_clave is null then raise exception 'RUC o solicitud inválida.';end if;
 perform pg_advisory_xact_lock(hashtextextended(r,6));
 d:=private.comprobar_firma(p_datos#>>'{consulta,payload}',p_datos#>>'{consulta,firma}','ruc');
 if d->>'ruc' is distinct from r or d->>'estado' is distinct from 'ACTIVO' or d->>'condicion' is distinct from 'HABIDO' or length(trim(coalesce(d->>'razon_social','')))=0 then raise exception 'El RUC debe existir, estar ACTIVO y HABIDO.';end if;

 -- A single group mutex serializes personal and company loans across all branches.
 -- Ordered DNI locks avoid deadlock when owner and signatory differ.
 perform pg_advisory_xact_lock(hashtextextended(least(p_datos#>>'{propietario,dni}',p_datos#>>'{representante,dni}'),0));
 perform pg_advisory_xact_lock(hashtextextended(greatest(p_datos#>>'{propietario,dni}',p_datos#>>'{representante,dni}'),0));
 if p_datos#>'{propietario,borrador}' is not null and p_datos#>'{propietario,borrador}'<>'null'::jsonb then perform private.registrar_identidad(p_datos#>>'{propietario,borrador,consulta,payload}',p_datos#>>'{propietario,borrador,consulta,firma}',p_datos#>'{propietario,borrador,evidencia}');end if;
 if p_datos#>'{representante,borrador}' is not null and p_datos#>'{representante,borrador}'<>'null'::jsonb then perform private.registrar_identidad(p_datos#>>'{representante,borrador,consulta,payload}',p_datos#>>'{representante,borrador,consulta,firma}',p_datos#>'{representante,borrador,evidencia}');end if;
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
 return c.id;end$$;

create function private.enviar_solicitud(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid,p_payload text,p_firma text,p_id uuid default null,p_version integer default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;r public.representaciones_empresa;c public.clientes;rep uuid;cid uuid;doc jsonb;st jsonb;e jsonb;rid uuid;begin
 a:=private.asesor();
 perform pg_advisory_xact_lock(hashtextextended(p_datos#>>'{consulta,ruc}',6));
 select * into s from public.solicitudes_prestamo where clave_envio=p_clave;
 if s.id is not null then
  if s.agencia_id<>a.agencia_id or s.ruc is distinct from p_datos#>>'{consulta,ruc}' or s.monto is distinct from p_monto or s.plazo_meses is distinct from p_meses then raise exception 'La clave pertenece a otra solicitud.';end if;return s.id;
 end if;
 if p_clave is null or p_datos#>>'{consulta,ruc}' not like '20%' or p_monto is null or p_monto<=0 or p_monto<>round(p_monto,2) or p_monto>private.parametro('capital_maximo') or p_meses is null or p_meses not between 1 and 60 then raise exception 'Revise RUC 20, monto y plazo.';end if;
 if p_id is not null then
  select * into s from public.solicitudes_prestamo where id=p_id for update;
  if s.id is null or s.agencia_id<>a.agencia_id or s.ruc is distinct from p_datos#>>'{consulta,ruc}' then raise exception 'Solicitud no disponible.';end if;
  if s.estado<>'observada' or s.version is distinct from p_version then raise exception 'Solo se corrige una solicitud observada en su versión actual.';end if;
 elsif exists(select 1 from public.solicitudes_prestamo where ruc=p_datos#>>'{consulta,ruc}' and estado in ('pendiente','observada')) then raise exception 'Ya existe una solicitud pendiente u observada para este RUC. Abra esa solicitud.';
 end if;
 doc:=(p_datos->>'evidencia_propiedad')::jsonb;
 if doc->>'tipo' is null or doc->>'tipo' not in ('partida','constitucion','acto','matricula') or length(trim(coalesce(doc->>'ref','')))=0 or length(doc->>'ref')>240 or doc->>'dni' is distinct from p_datos#>>'{propietario,dni}' then raise exception 'Seleccione un documento admitido y su referencia.';end if;
 if doc->>'presente'='false' and (p_datos#>>'{propietario,dni}'=p_datos#>>'{representante,dni}' or p_datos#>'{propietario,borrador}' is not null) then raise exception 'El propietario ausente requiere identidad previa vigente y otro firmante presencial.';end if;
 r:=jsonb_populate_record(null::public.representaciones_empresa,private.finalizar_representacion(p_payload,p_firma));
 if r.agencia_id<>a.agencia_id or r.ruc is distinct from p_datos#>>'{consulta,ruc}' or r.propietario_dni is distinct from p_datos#>>'{propietario,dni}' or r.representante_dni is distinct from p_datos#>>'{representante,dni}' or exists(select 1 from public.solicitudes_prestamo where representacion_id=r.id) then raise exception 'Certificado no corresponde al expediente o ya fue presentado.';end if;
 cid:=private.preparar_empresa_solicitud(p_datos,p_clave);select * into c from public.clientes where id=cid;
 rep:=private.persona_ruc(p_datos->'representante');
 perform pg_advisory_xact_lock(hashtextextended(c.propietario_id::text,4));
 st:=private.situacion(c.id);
 if (st->>'elegible')::boolean is distinct from true or (st->>'capital_disponible')::numeric<p_monto then raise exception 'Revise identidad, atrasos, conciliación y capital disponible global.';end if;
 e:=jsonb_build_object('razon_social',r.razon_social,'propietario',(select jsonb_build_object('dni',dni,'nombres',nombres,'apellidos',apellidos) from public.clientes where id=c.propietario_id),'representante',(select jsonb_build_object('dni',dni,'nombres',nombres,'apellidos',apellidos) from public.clientes where id=rep),'evidencia_propiedad',p_datos->>'evidencia_propiedad','certificado',jsonb_build_object('id',r.id,'sha256',r.archivo_sha256,'emision',r.fecha_emision),'monto',p_monto,'meses',p_meses,'fecha_simulacion',public.fecha_peru());
 if p_id is null then
  insert into public.solicitudes_prestamo(clave_envio,ruc,cliente_id,propietario_id,representante_id,representacion_id,asesor_id,agencia_id,monto,plazo_meses,expediente)
  values(p_clave,r.ruc,c.id,c.propietario_id,rep,r.id,a.id,a.agencia_id,p_monto,p_meses,e) returning id into rid;
 else
  update public.solicitudes_prestamo set clave_envio=p_clave,representante_id=rep,representacion_id=r.id,monto=p_monto,plazo_meses=p_meses,expediente=e,estado='pendiente',motivo=null,evaluador_id=null,version=version+1,updated_at=now() where id=p_id returning id into rid;
 end if;
 insert into public.historial_solicitudes(solicitud_id,asesor_id,estado,detalle,expediente) values(rid,a.id,'pendiente',case when p_id is null then 'Solicitud enviada al finalizar Nuevo préstamo.' else 'Solicitud corregida y reenviada.' end,e);
 return rid;
end$$;
create function public.enviar_solicitud(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid,p_payload text,p_firma text,p_id uuid default null,p_version integer default null) returns uuid language sql security invoker set search_path='' as $$select private.enviar_solicitud(p_datos,p_monto,p_meses,p_clave,p_payload,p_firma,p_id,p_version)$$;

-- Todas las cuentas activas de asesor pueden evaluar solicitudes de su agencia.
-- No se concede autoriza_credito ni se amplían permisos de regularización especial.
create function private.evaluar_solicitud(p_id uuid,p_version integer,p_estado text,p_motivo text,p_consulta jsonb default null,p_referencia text default null,p_facultades boolean default false,p_individual boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;d jsonb;pid uuid;v_ruc text;begin
 a:=private.asesor();select ruc into v_ruc from public.solicitudes_prestamo where id=p_id and agencia_id=a.agencia_id;perform pg_advisory_xact_lock(hashtextextended(v_ruc,6));select * into s from public.solicitudes_prestamo where id=p_id and agencia_id=a.agencia_id for update;
 if s.id is null then raise exception 'Solicitud fuera de su agencia.' using errcode='42501';end if;
 if s.estado='aprobada' and p_estado='aprobada' then return s.prestamo_id;end if;
 if s.estado<>'pendiente' or s.version is distinct from p_version then raise exception 'La solicitud cambió o ya fue evaluada. Actualice.';end if;
 if p_estado is null or p_estado not in ('aprobada','observada','rechazada') or length(trim(coalesce(p_motivo,'')))<10 or length(p_motivo)>1000 then raise exception 'Seleccione el resultado y registre el sustento (10 a 1000 caracteres).';end if;
 if p_estado='aprobada' then
  if p_facultades is distinct from true or p_individual is distinct from true or length(trim(coalesce(p_referencia,'')))<8 or length(p_referencia)>500 then raise exception 'Compruebe autenticidad, facultades y firma individual, con referencia de validación.';end if;
  d:=private.comprobar_firma(p_consulta->>'payload',p_consulta->>'firma','ruc');
  if d->>'ruc' is distinct from s.ruc or d->>'estado' is distinct from 'ACTIVO' or d->>'condicion' is distinct from 'HABIDO' then raise exception 'Se requiere consulta actual del RUC ACTIVO y HABIDO.';end if;
  perform pg_advisory_xact_lock(hashtextextended(s.ruc,6));
  perform pg_advisory_xact_lock(hashtextextended(s.propietario_id::text,4));
  if (select propietario_id from public.clientes where id=s.cliente_id) is distinct from s.propietario_id then raise exception 'El vínculo del propietario cambió; requiere revisión administrativa.';end if;
  if (private.situacion_individual(s.representante_id)->>'verificacion') is distinct from 'aprobada' then raise exception 'El DNI del representante requiere revalidación.';end if;
  if not exists(select 1 from public.representaciones_empresa where id=s.representacion_id and estado='pendiente' and archivo_sha256=s.expediente#>>'{certificado,sha256}') then raise exception 'El certificado requiere una nueva presentación.';end if;
  update public.representaciones_empresa set estado='revisada',observacion=p_motivo,referencia_validacion=p_referencia,revisor_id=a.id,revisado_at=now(),valida_hasta=public.fecha_peru(),monto_maximo=s.monto,version=version+1,updated_at=now() where id=s.representacion_id;
  insert into public.historial_representaciones(representacion_id,asesor_id,estado,detalle) values(s.representacion_id,a.id,'revisada',p_motivo);
  update public.clientes set representante_id=s.representante_id,razon_social=d->>'razon_social',estado_ruc=d->>'estado',condicion_ruc=d->>'condicion',direccion_fiscal=d->>'direccion',ruc_consultado_at=(d->>'consultadoEn')::timestamptz,evidencia_propiedad=s.expediente->>'evidencia_propiedad',evidencia_poder='Certificado de vigencia de poder: '||s.representacion_id::text where id=s.cliente_id;
  perform set_config('app.ruc_validado',s.ruc,true);perform set_config('app.representacion_id',s.representacion_id::text,true);perform set_config('app.solicitud_id',s.id::text,true);
  pid:=private.crear_prestamo(s.cliente_id,s.monto,s.plazo_meses,s.id);
  update public.prestamos set identidad_contrato=identidad_contrato||jsonb_build_object('solicitud_id',s.id,'representacion_id',s.representacion_id,'representacion_sha256',s.expediente#>>'{certificado,sha256}','evaluador_id',a.id) where id=pid;
 end if;
 update public.solicitudes_prestamo set estado=p_estado,motivo=trim(p_motivo),evaluador_id=a.id,prestamo_id=pid,version=version+1,updated_at=now() where id=s.id;
 insert into public.historial_solicitudes(solicitud_id,asesor_id,estado,detalle,expediente) values(s.id,a.id,p_estado,trim(p_motivo),s.expediente);
 return pid;
end$$;
create function public.evaluar_solicitud(p_id uuid,p_version integer,p_estado text,p_motivo text,p_consulta jsonb default null,p_referencia text default null,p_facultades boolean default false,p_individual boolean default false) returns uuid language sql security invoker set search_path='' as $$select private.evaluar_solicitud(p_id,p_version,p_estado,p_motivo,p_consulta,p_referencia,p_facultades,p_individual)$$;
create or replace function private.exigir_representacion(p_id uuid,p_ruc text,p_propietario text,p_representante text,p_monto numeric) returns public.representaciones_empresa
language plpgsql security definer set search_path='' as $$
declare a public.asesores;r public.representaciones_empresa;begin
 a:=private.asesor();if not exists(select 1 from public.solicitudes_prestamo s where s.id=nullif(current_setting('app.solicitud_id',true),'')::uuid and s.representacion_id=p_id and s.estado='pendiente' and s.agencia_id=a.agencia_id and s.monto=p_monto) then raise exception 'RUC 20 requiere evaluar y aprobar una solicitud de préstamo.';end if;select * into r from public.representaciones_empresa where id=p_id for share;
 if r.id is null or r.estado<>'revisada' or r.valida_hasta<public.fecha_peru() or r.agencia_id<>a.agencia_id or r.ruc is distinct from p_ruc or r.propietario_dni is distinct from p_propietario or r.representante_dni is distinct from p_representante or p_monto>r.monto_maximo then
 raise exception 'La empresa requiere una representación revisada, vigente y suficiente para este propietario, firmante e importe.';end if;return r;
end$$;

create view public.solicitudes_resumen with(security_invoker=true) as select s.*,private.autor_revision(s.asesor_id,s.agencia_id)->>'asesor' asesor_nombre,private.autor_revision(s.asesor_id,s.agencia_id)->>'agencia' agencia_nombre from public.solicitudes_prestamo s;
revoke all on public.solicitudes_resumen from public,anon;grant select on public.solicitudes_resumen to authenticated;
revoke all on function private.preparar_empresa_solicitud(jsonb,uuid) from public,anon,authenticated;
do $$declare f record;begin
 for f in select p.oid::regprocedure firma from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname in ('ver_solicitud','resolver_solicitud_ruc','enviar_solicitud','evaluar_solicitud') loop
 execute format('revoke all on function %s from public,anon',f.firma);execute format('grant execute on function %s to authenticated',f.firma);end loop;
end$$;
notify pgrst,'reload schema';commit;
