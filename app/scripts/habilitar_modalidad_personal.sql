-- Aplicar una vez en SQL Editor sobre la versión que ya incluye RUC, contrato y mora.
-- No borra datos ni altera importes o contratos de préstamos anteriores.
begin;
-- El estado SUNAT no sustituye la identidad del DNI de una persona natural.
create or replace function private.situacion(p_cliente uuid,p_hoy date default public.fecha_peru()) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare c public.clientes;g uuid;s jsonb;capital numeric;deuda numeric;ven date;conc boolean;cond text;ver text;inc date;aut timestamptz;bloq boolean;begin
 perform private.asesor();select * into c from public.clientes where id=p_cliente;if c.id is null then raise exception 'Cliente no encontrado.';end if;
 g:=coalesce(c.propietario_id,c.id);
 select coalesce(sum(q.amortizacion) filter(where pc.cuota_id is null),0),coalesce(sum(q.cuota_total+private.mora_cuota(q.id,p_hoy)) filter(where pc.cuota_id is null),0),min(q.fecha_vencimiento) filter(where pc.cuota_id is null and q.cuota_total>0 and q.fecha_vencimiento<p_hoy),coalesce(bool_and(p.conciliado),true)
 into capital,deuda,ven,conc from public.clientes gc join public.prestamos p on p.cliente_id=gc.id and p.estado='confirmado' join public.cuotas q on q.prestamo_id=p.id left join public.pagos_cuotas pc on pc.cuota_id=q.id where coalesce(gc.propietario_id,gc.id)=g;
 cond:=case when ven is null then 'habilitado' when (ven+interval '12 months')::date<=p_hoy then 'extrajudicial' else 'moroso' end;
 select max((q.fecha_vencimiento+interval '12 months')::date) into inc
 from public.clientes gc join public.prestamos p on p.cliente_id=gc.id and p.estado='confirmado' join public.cuotas q on q.prestamo_id=p.id left join public.pagos_cuotas pc on pc.cuota_id=q.id left join public.pagos pa on pa.id=pc.pago_id
 where coalesce(gc.propietario_id,gc.id)=g and q.cuota_total>0 and (q.fecha_vencimiento+interval '12 months')::date<=p_hoy
 and (pa.id is null or (pa.created_at at time zone 'America/Lima')::date>=(q.fecha_vencimiento+interval '12 months')::date);
 select max(created_at) into aut from private.rehabilitaciones where propietario_id=g;
 bloq:=inc is not null and (aut is null or (aut at time zone 'America/Lima')::date<inc);
 if c.tipo_cliente='natural' then s:=private.situacion_individual(c.id,p_hoy);ver:=s->>'verificacion';
 else
 s:=private.situacion_individual(c.propietario_id,p_hoy);ver:=s->>'verificacion';
 if (private.situacion_individual(c.representante_id,p_hoy)->>'verificacion')<>'aprobada' then ver:='pendiente';end if;
 end if;
 if c.tipo_cliente='juridica' and c.ruc is not null and (c.estado_ruc is distinct from 'ACTIVO' or c.condicion_ruc is distinct from 'HABIDO') then ver:='rechazada';end if;
 return jsonb_build_object('capital_pendiente',capital,'capital_disponible',greatest(0,private.parametro('capital_maximo')-capital),'limite',private.parametro('capital_maximo'),'deuda_pendiente',deuda,'mora_desde',ven,'condicion_pago',case when conc then cond else 'por_conciliar' end,'conciliado',conc,'verificacion',ver,'antecedente_extrajudicial',inc,'requiere_autorizacion',bloq,'propietario_id',g,'elegible',conc and cond='habilitado' and ver='aprobada' and not bloq);
end$$;
create or replace function private.confirmar_prestamo_cotizado(p_tipo text,p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid,p_tasa numeric,p_base integer) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;c public.clientes;anterior text;previo uuid;identidad jsonb;modalidad text;resultado uuid;
begin
 a:=private.asesor();perform pg_advisory_xact_lock(781563::bigint);
 modalidad:=case when p_tipo='ruc' then 'ruc' else 'dni' end;
 select id,identidad_contrato into previo,identidad from public.prestamos where clave_operacion=p_clave and asesor_id=a.id;
 if previo is not null and coalesce(identidad->>'modalidad',case when identidad->>'ruc' is not null then 'ruc' else 'dni' end)<>modalidad then
  raise exception 'La clave pertenece a otra modalidad de préstamo.';
 end if;
 if not exists(select 1 from public.prestamos where clave_operacion=p_clave) and (p_tasa is distinct from private.parametro('tasa_moratoria_anual') or p_base is distinct from coalesce(private.parametro('base_mora'),360)::integer) then
  raise exception 'Las condiciones de mora cambiaron. Actualice la página y revise el préstamo antes de confirmar.';
 end if;
 if p_tipo='ruc' then resultado:=private.confirmar_ruc_prestamo(p_datos,p_monto,p_meses,p_clave);
 elsif p_tipo='nuevo' then resultado:=private.confirmar_cliente_prestamo(p_datos->>'p_payload',p_datos->>'p_firma',p_datos->'p_evidencia',p_monto,p_meses,p_clave);
 elsif p_tipo='dni' then
  select * into c from public.clientes where id=(p_datos->>'cliente_id')::uuid;
  if c.id is null or c.tipo_cliente<>'natural' or c.dni is null or (c.ruc is not null and left(c.ruc,2)<>'10') then
   raise exception 'La modalidad personal requiere una persona natural con DNI; una empresa debe solicitar por RUC.';
  end if;
  -- Solo la modalidad DNI de una persona natural puede omitir la consulta SUNAT.
  -- crear_prestamo mantiene sus controles de identidad, pagos, cupo global y agencia.
  anterior:=current_setting('app.ruc_validado',true);
  perform set_config('app.ruc_validado',coalesce(c.ruc,''),true);
  resultado:=private.crear_prestamo(c.id,p_monto,p_meses,p_clave);
  perform set_config('app.ruc_validado',coalesce(anterior,''),true);
 else raise exception 'Tipo de solicitud inválido.';
 end if;
 if previo is null then
  if modalidad='dni' then
   update public.prestamos set identidad_contrato=identidad_contrato||jsonb_build_object('modalidad','dni','ruc_asociado',identidad_contrato->'ruc','ruc',null,'razon_social',null,'propietario',null,'representante',null) where id=resultado;
  else update public.prestamos set identidad_contrato=identidad_contrato||jsonb_build_object('modalidad','ruc') where id=resultado;
  end if;
 end if;
 return resultado;
end$$;
revoke all on function private.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid,numeric,integer) from public,anon;
grant execute on function private.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid,numeric,integer) to authenticated;
commit;
