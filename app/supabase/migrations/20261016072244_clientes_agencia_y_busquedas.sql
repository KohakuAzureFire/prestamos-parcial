-- Ficha única con listado por agencia; la búsqueda global requiere un DNI exacto.
alter table public.clientes add column agencia_registro_id uuid references public.agencias(id);
update public.clientes c set agencia_registro_id=coalesce(
 (select a.agencia_id from public.verificaciones_identidad v join public.asesores a on a.id=v.asesor_id where v.cliente_id=c.id order by v.created_at,v.id limit 1),
 (select a.agencia_id from public.asesores a where a.id=c.asesor_id));
create index clientes_agencia_registro_idx on public.clientes(agencia_registro_id);
create index if not exists prestamos_cliente_agencia_idx on public.prestamos(cliente_id,agencia_id);

create function private.cliente_visible(p_cliente uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare g uuid;begin
 g:=private.agencia();
 return exists(select 1 from public.clientes c where c.id=p_cliente and (c.agencia_registro_id=g or exists(select 1 from public.prestamos p where p.cliente_id=c.id and p.agencia_id=g and p.estado='confirmado')));
end$$;
create function private.fijar_agencia_registro() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then new.agencia_registro_id:=private.agencia();
 elsif new.agencia_registro_id is distinct from old.agencia_registro_id then raise exception 'La agencia de registro inicial no se cambia al revalidar.';end if;
 return new;
end$$;
create trigger cliente_agencia_inicial before insert or update of agencia_registro_id on public.clientes for each row execute function private.fijar_agencia_registro();

drop policy clientes_asesor on public.clientes;
create policy clientes_agencia on public.clientes for select to authenticated using(private.cliente_visible(id));
drop policy verificaciones_asesor on public.verificaciones_identidad;
create policy verificaciones_cliente_agencia on public.verificaciones_identidad for select to authenticated using(private.cliente_visible(cliente_id));
drop policy historial_asesor on public.historial_condicion_pago;
create policy historial_cliente_agencia on public.historial_condicion_pago for select to authenticated using(private.cliente_visible(cliente_id));

alter table public.verificaciones_identidad add column agencia_id uuid references public.agencias(id);
-- Solo este backfill añade la agencia a las evidencias antiguas; su contenido se conserva.
alter table public.verificaciones_identidad disable trigger verificaciones_inmutables;
update public.verificaciones_identidad v set agencia_id=a.agencia_id from public.asesores a where a.id=v.asesor_id;
alter table public.verificaciones_identidad enable trigger verificaciones_inmutables;
create index verificaciones_agencia_idx on public.verificaciones_identidad(agencia_id);

create function private.autor_revision(p_asesor uuid,p_agencia uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform private.asesor();
 return jsonb_build_object('asesor',(select nombre_completo from public.asesores where id=p_asesor),'agencia',(select nombre from public.agencias where id=p_agencia));
end$$;
create view public.verificaciones_con_agencia with(security_invoker=true) as
 select v.*,private.autor_revision(v.asesor_id,v.agencia_id)->>'asesor' as asesor_nombre,
 private.autor_revision(v.asesor_id,v.agencia_id)->>'agencia' as agencia_nombre from public.verificaciones_identidad v;

create function private.resolver_cliente(p_dni text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare c public.clientes;begin
 perform private.asesor();
 if p_dni is null or p_dni!~'^[0-9]{8}$' then raise exception 'Ingresa un DNI de exactamente 8 dígitos numéricos.' using errcode='22023';end if;
 select * into c from public.clientes where dni=p_dni;
 if c.id is null then return null;end if;
 return jsonb_build_object('cliente',jsonb_build_object('id',c.id,'dni',c.dni,'nombres',c.nombres,'apellidos',c.apellidos,'dni_caducidad',c.dni_caducidad), 'situacion',private.situacion(c.id));
end$$;
create function public.resolver_cliente(p_dni text) returns jsonb language sql stable security invoker set search_path='' as $$select private.resolver_cliente(p_dni)$$;
create or replace function public.resumen_cliente(p_cliente uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if not private.cliente_visible(p_cliente) then raise exception 'Cliente no disponible en tu agencia.' using errcode='42501';end if;
 return private.situacion(p_cliente);
end$$;

create function private.buscar_cuotas(p_busqueda text,p_tipo text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare k text;r jsonb;begin
 perform private.asesor();
 if p_tipo='dni' then
  if p_busqueda is null or p_busqueda!~'^[0-9]{8}$' then raise exception 'Ingresa un DNI de exactamente 8 dígitos numéricos.' using errcode='22023';end if;
  select coalesce(jsonb_agg(x),'[]') into r from jsonb_array_elements(private.detalle_cobranza(p_busqueda)) x
   where exists(select 1 from jsonb_array_elements(x->'cuotas') q where not (q->>'pagada')::boolean and (q->>'cuota_total')::numeric>0);
  return r;
 elsif p_tipo='id' then
  k:=upper(regexp_replace(trim(p_busqueda),'^PR-','','i'));
  if k is null or k!~'^[A-F0-9]{8}$' then raise exception 'Completa los 8 caracteres del código: números y letras de A a F.' using errcode='22023';end if;
  return private.detalle_cobranza('PR-'||k);
 else raise exception 'Selecciona DNI exacto o Código de préstamo.' using errcode='22023';end if;
end$$;
create function public.buscar_cuotas(p_busqueda text,p_tipo text) returns jsonb language sql stable security invoker set search_path='' as $$select private.buscar_cuotas(p_busqueda,p_tipo)$$;

revoke all on function private.cliente_visible(uuid),private.fijar_agencia_registro(),private.autor_revision(uuid,uuid),private.resolver_cliente(text),private.buscar_cuotas(text,text) from public,anon;
grant execute on function private.cliente_visible(uuid),private.autor_revision(uuid,uuid),private.resolver_cliente(text),private.buscar_cuotas(text,text) to authenticated;
revoke all on function public.resolver_cliente(text),public.buscar_cuotas(text,text) from public,anon;
grant execute on function public.resolver_cliente(text),public.buscar_cuotas(text,text) to authenticated;
grant select on public.verificaciones_con_agencia to authenticated;

create or replace function private.registrar_identidad(p_payload text,p_firma text,p_evidencia jsonb) returns uuid
 language plpgsql security definer set search_path='' as $$
declare a public.asesores;datos jsonb;v_secret text;c_id uuid;cad date;begin
 a:=private.asesor();select valor into v_secret from private.configuracion where clave='identity_signing_secret';
 if v_secret is null or p_firma is null or p_firma<>encode(extensions.hmac(p_payload,v_secret,'sha256'),'hex') then raise exception 'Consulta de identidad inválida. Vuelva a consultar el DNI.';end if;
 datos:=p_payload::jsonb;
 if datos->>'asesor_id'<>a.id::text or (datos->>'consultadoEn')::timestamptz<now()-interval '30 minutes' or (datos->>'consultadoEn')::timestamptz>now()+interval '1 minute' then raise exception 'La consulta de identidad expiró.';end if;
 if (datos->>'dni')!~'^[0-9]{8}$' or length(trim(datos->>'nombres'))=0 or length(trim(datos->>'apellidos'))=0 then raise exception 'Identidad incompleta.';end if;
 cad:=(p_evidencia->>'caducidad')::date;
 if cad is null or cad<public.fecha_peru() or not coalesce((p_evidencia->>'original')::boolean,false)
 or not coalesce((p_evidencia->>'no_fallecido')::boolean,false)
 or length(trim(coalesce(p_evidencia->>'vigencia','')))<4 or length(trim(coalesce(p_evidencia->>'supervivencia','')))<4 then raise exception 'Complete la revisión del documento y las dos evidencias.';end if;
 perform pg_advisory_xact_lock(hashtextextended(datos->>'dni',0));
 select id into c_id from public.clientes where dni=datos->>'dni' for update;
 if exists(select 1 from public.clientes where id=c_id and fallecimiento_acreditado) then raise exception 'La identidad requiere revisión oficial antes de continuar.';end if;
 if c_id is null then
 insert into public.clientes(dni,nombres,apellidos,asesor_id) values(datos->>'dni',datos->>'nombres',datos->>'apellidos',a.id) returning id into c_id;
 end if;
 insert into public.verificaciones_identidad(cliente_id,resultado,fecha_caducidad,fuente,nombres_fuente,apellidos_fuente,
 evidencia_vigencia,evidencia_supervivencia,no_fallecido_acreditado,documento_original_revisado,origen,asesor_id,agencia_id)
 values(c_id,'aprobada',cad,'Decolecta',datos->>'nombres',datos->>'apellidos',left(p_evidencia->>'vigencia',500),left(p_evidencia->>'supervivencia',500),true,true,'verificacion',a.id,a.agencia_id);
 update public.clientes set nombres=datos->>'nombres',apellidos=datos->>'apellidos',verificacion_resultado='aprobada',dni_caducidad=cad,
 fecha_verificacion=now(),fuente_verificacion='Decolecta' where id=c_id;
 return c_id;end$$;

create or replace function private.detalle_cobranza(p_busqueda text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;r jsonb;k text;begin
 a:=private.asesor();k:=lower(regexp_replace(trim(p_busqueda),'^PR-','','i'));
 if p_busqueda!~'^[0-9]{8}$' and k!~'^[a-f0-9]{8}$' and k!~'^[a-f0-9]{8}-[a-f0-9-]{27,28}$' then raise exception 'Ingrese DNI exacto o código de préstamo.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'cliente_id',p.cliente_id,'monto',p.monto,'plazo_meses',p.plazo_meses,'conciliado',p.conciliado,
 'fecha_prestamo',p.fecha_prestamo,'agencia_origen',g.nombre,'nombre',c.nombres||' '||c.apellidos,'dni',c.dni,
 'cuotas',(select coalesce(jsonb_agg(to_jsonb(q)||jsonb_build_object('pagada',pc.cuota_id is not null,'pago_id',pc.pago_id) order by q.numero_cuota),'[]') from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id),
 'pagos',(select coalesce(jsonb_agg(jsonb_build_object('id',pa.id,'importe',pa.importe,'created_at',pa.created_at,'agencia',ga.nombre,'asesor',ad.nombre_completo,'puede_ver_constancia',(p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id)) order by pa.created_at desc),'[]') from public.pagos pa join public.agencias ga on ga.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id where pa.prestamo_id=p.id))), '[]') into r
 from public.prestamos p join public.clientes c on c.id=p.cliente_id join public.agencias g on g.id=p.agencia_id
 where p.estado='confirmado' and (case when p_busqueda~'^[0-9]{8}$' then c.dni=p_busqueda else left(p.id::text,8)=k or p.id::text=k end);
 return r;end$$;

notify pgrst, 'reload schema';
