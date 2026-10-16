-- El cliente nuevo y su evidencia nacen junto con el préstamo, en una transacción.
-- Revalidar una ficha existente sigue siendo una operación independiente.
create function private.revalidar_existente(p_payload text,p_firma text,p_evidencia jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare d text;begin
 perform private.asesor();d:=p_payload::jsonb->>'dni';
 if d is null or d!~'^[0-9]{8}$' then raise exception 'DNI inválido.';end if;
 perform pg_advisory_xact_lock(hashtextextended(d,0));
 if not exists(select 1 from public.clientes where dni=d) then
  raise exception 'El cliente nuevo se guarda únicamente al confirmar el préstamo en el paso 3.' using errcode='22023';
 end if;
 return private.registrar_identidad(p_payload,p_firma,p_evidencia);
end$$;
create or replace function public.registrar_identidad(p_payload text,p_firma text,p_evidencia jsonb) returns uuid
language sql security invoker set search_path='' as $$select private.revalidar_existente(p_payload,p_firma,p_evidencia)$$;

create function private.confirmar_cliente_prestamo(p_payload text,p_firma text,p_evidencia jsonb,p_monto numeric,p_meses integer,p_clave uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;datos jsonb;secreto text;d text;c_id uuid;p_id uuid;s jsonb;begin
 a:=private.asesor();datos:=p_payload::jsonb;d:=datos->>'dni';
 if d is null or d!~'^[0-9]{8}$' or p_clave is null then raise exception 'Solicitud incompleta.';end if;
 -- Serializa reintentos y solicitudes de las cinco agencias con el mismo DNI.
 perform pg_advisory_xact_lock(hashtextextended(d,0));
 select p.id into p_id from public.prestamos p join public.clientes c on c.id=p.cliente_id
 where p.clave_operacion=p_clave and p.asesor_id=a.id and c.dni=d and p.monto=p_monto and p.plazo_meses=p_meses;
 if p_id is not null then return p_id;end if;
 if exists(select 1 from public.prestamos where clave_operacion=p_clave) then raise exception 'La clave pertenece a otra operación.';end if;
 select valor into secreto from private.configuracion where clave='identity_signing_secret';
 if secreto is null or p_firma is null or p_firma<>encode(extensions.hmac(p_payload,secreto,'sha256'),'hex') then raise exception 'Consulta de identidad inválida. Vuelva al paso 1.';end if;
 if datos->>'asesor_id' is distinct from a.id::text or datos->>'consultadoEn' is null
 or (datos->>'consultadoEn')::timestamptz<now()-interval '30 minutes' or (datos->>'consultadoEn')::timestamptz>now()+interval '1 minute' then
 raise exception 'La consulta de identidad expiró. Vuelva al paso 1 para consultar de nuevo.';end if;
 select id into c_id from public.clientes where dni=d for update;
 if c_id is null then
  c_id:=private.registrar_identidad(p_payload,p_firma,p_evidencia);
 else
  -- Otra solicitud pudo registrar el DNI mientras este borrador estaba abierto.
  -- Se reutiliza la evidencia vigente y nunca se sobrescribe con un borrador anterior.
  s:=private.situacion(c_id);
  if s->>'verificacion'<>'aprobada' then raise exception 'El cliente ya existe y requiere revalidación. Vuelva al paso 1.';end if;
 end if;
 -- Si falla cualquier validación o cuota, también se revierte el alta y su evidencia.
 return private.crear_prestamo(c_id,p_monto,p_meses,p_clave);
end$$;
create function public.confirmar_cliente_prestamo(p_payload text,p_firma text,p_evidencia jsonb,p_monto numeric,p_meses integer,p_clave uuid) returns uuid
language sql security invoker set search_path='' as $$select private.confirmar_cliente_prestamo(p_payload,p_firma,p_evidencia,p_monto,p_meses,p_clave)$$;
revoke all on function private.registrar_identidad(text,text,jsonb) from authenticated;
revoke all on function private.revalidar_existente(text,text,jsonb),private.confirmar_cliente_prestamo(text,text,jsonb,numeric,integer,uuid) from public,anon;
grant execute on function private.revalidar_existente(text,text,jsonb),private.confirmar_cliente_prestamo(text,text,jsonb,numeric,integer,uuid) to authenticated;
revoke all on function public.confirmar_cliente_prestamo(text,text,jsonb,numeric,integer,uuid) from public,anon;
grant execute on function public.confirmar_cliente_prestamo(text,text,jsonb,numeric,integer,uuid) to authenticated;
notify pgrst, 'reload schema';
