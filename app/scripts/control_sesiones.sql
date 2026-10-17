-- Ejecutar después de los scripts existentes. No modifica préstamos ni pagos.
begin;
create table if not exists private.sesiones_asesor (
 asesor_id uuid primary key references public.asesores(id) on delete cascade,
 session_id uuid not null,
 auth_created_at timestamptz not null,
 ultima_actividad timestamptz not null default clock_timestamp(),
 cerrada boolean not null default false
);
alter table private.sesiones_asesor enable row level security;
revoke all on private.sesiones_asesor from public,anon,authenticated;

create or replace function private.control_sesion(p_accion text default 'estado') returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 u uuid := auth.uid(); s uuid; ultima auth.sessions; registro private.sesiones_asesor;
 instante timestamptz := clock_timestamp(); motivo text;
begin
 if u is null then return jsonb_build_object('ok',false,'motivo','invalida'); end if;
 if not exists(select 1 from public.asesores where id=u and activo) then
  return jsonb_build_object('ok',false,'motivo','cuenta');
 end if;
 s := (auth.jwt()->>'session_id')::uuid;
 if s is null then return jsonb_build_object('ok',false,'motivo','invalida'); end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,917));
 select * into ultima from auth.sessions where user_id=u order by created_at desc,id desc limit 1;
 select * into registro from private.sesiones_asesor where asesor_id=u;
 if p_accion='cerrar' then
  update private.sesiones_asesor set cerrada=true where asesor_id=u and session_id=s;
  return jsonb_build_object('ok',true);
 end if;
 if ultima.id is distinct from s then
  return jsonb_build_object('ok',false,'motivo','reemplazada');
 end if;
 if p_accion='iniciar' and registro.session_id is distinct from s then
  if registro.auth_created_at is not null and
     (ultima.created_at,ultima.id)<=(registro.auth_created_at,registro.session_id) then
   return jsonb_build_object('ok',false,'motivo','reemplazada');
  end if;
  insert into private.sesiones_asesor values(u,s,ultima.created_at,instante,false)
   on conflict(asesor_id) do update set session_id=excluded.session_id,
   auth_created_at=excluded.auth_created_at,ultima_actividad=excluded.ultima_actividad,cerrada=false;
  select * into registro from private.sesiones_asesor where asesor_id=u;
 end if;
 if registro.session_id is distinct from s then motivo:='invalida';
 elsif registro.cerrada then motivo:='cerrada';
 elsif registro.ultima_actividad+interval '15 minutes'<=instante then motivo:='inactividad';
 end if;
 if motivo is not null then return jsonb_build_object('ok',false,'motivo',motivo); end if;
 if p_accion='actividad' then
  update private.sesiones_asesor set ultima_actividad=instante where asesor_id=u;
  registro.ultima_actividad:=instante;
 end if;
 return jsonb_build_object('ok',true,'vence',registro.ultima_actividad+interval '15 minutes','servidor',instante);
end $$;

create or replace function public.control_sesion(p_accion text default 'estado') returns jsonb
language sql security invoker set search_path='' as $$select private.control_sesion(p_accion)$$;
revoke all on function private.control_sesion(text) from public,anon;
revoke all on function public.control_sesion(text) from public,anon;
grant execute on function private.control_sesion(text),public.control_sesion(text) to authenticated;

-- La autorización central protege también el acceso directo a las operaciones de negocio.
create or replace function private.asesor() returns public.asesores
language plpgsql stable security definer set search_path='' as $$
declare a public.asesores; estado jsonb;
begin
 select * into a from public.asesores where id=auth.uid() and activo;
 if a.id is null then raise exception 'Cuenta sin autorización de asesor.' using errcode='42501'; end if;
 estado:=private.control_sesion('estado');
 if not (estado->>'ok')::boolean then
  raise exception 'Sesión no disponible: %. Vuelve a iniciar sesión.',estado->>'motivo' using errcode='42501';
 end if;
 return a;
end $$;
notify pgrst,'reload schema';
commit;
