-- Retiro de cargos por atraso y aviso de pagos según obligaciones existentes.
-- Aplicar después de los scripts funcionales y de control_sesiones.sql.
-- No cambia importes, cuotas, pagos ni verificaciones confirmadas.
begin;
-- Impide borrar desglose económico si apareciera un cobro histórico con cargo.
do $$begin
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='pagos_cuotas' and column_name='interes_moratorio') then
 if exists(select 1 from public.pagos_cuotas where interes_moratorio<>0) then
  raise exception 'Existen cargos históricos cobrados. Revise la conciliación antes de retirar el desglose.';
 end if;
 end if;
end$$;
drop trigger if exists fijar_mora on public.prestamos;
drop function if exists public.configurar_mora(numeric,integer,text);
drop function if exists private.configurar_mora(numeric,integer,text);
drop function if exists private.fijar_mora_prestamo();
drop function if exists public.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid,numeric,integer);
drop function if exists private.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid,numeric,integer);
-- Se conserva la fecha de la cuota vencida con un nombre que expresa su uso.
do $$begin
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='clientes' and column_name='mora_desde') then
  alter table public.clientes rename column mora_desde to atraso_desde;
  alter view public.clientes_resumen rename column mora_desde to atraso_desde;
 end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='historial_condicion_pago' and column_name='mora_desde') then
  alter table public.historial_condicion_pago rename column mora_desde to atraso_desde;
 end if;
end$$;
CREATE OR REPLACE FUNCTION private.actualizar_cliente(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s jsonb;prev text;nueva text;begin
 -- caller must be an active adviser or the internal scheduled worker.
 s:=private.situacion(p_id);select condicion_pago into prev from public.clientes where id=p_id;
 nueva:=s->>'condicion_pago';
 if nueva is distinct from prev then insert into public.historial_condicion_pago(cliente_id,condicion_anterior,condicion_nueva,atraso_desde) values(p_id,prev,nueva,(s->>'atraso_desde')::date);end if;
 update public.clientes set condicion_pago=nueva,atraso_desde=(s->>'atraso_desde')::date,situacion_actualizada_at=now() where id=p_id;
 update public.prestamos p set estado_deuda=case when exists(select 1 from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id and pc.cuota_id is null and q.cuota_total>0) then 'activo' else 'cancelado' end where p.cliente_id=p_id and p.estado='confirmado';end$function$;

CREATE OR REPLACE FUNCTION private.confirmar_prestamo_cotizado(p_tipo text, p_datos jsonb, p_monto numeric, p_meses integer, p_clave uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;c public.clientes;anterior text;previo uuid;identidad jsonb;modalidad text;resultado uuid;
begin
 a:=private.asesor();perform pg_advisory_xact_lock(781563::bigint);
 modalidad:=case when p_tipo='ruc' then 'ruc' else 'dni' end;
 select id,identidad_contrato into previo,identidad from public.prestamos where clave_operacion=p_clave and asesor_id=a.id;
 if previo is not null and coalesce(identidad->>'modalidad',case when identidad->>'ruc' is not null then 'ruc' else 'dni' end)<>modalidad then
  raise exception 'La clave pertenece a otra modalidad de préstamo.';
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
end$function$;

CREATE OR REPLACE FUNCTION private.constancia(p_pago uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;r jsonb;begin
 a:=private.asesor();
 select to_jsonb(pa)||jsonb_build_object('dni',c.dni,'ruc',c.ruc,'cliente',c.nombres||' '||c.apellidos,'agencia_origen',go.nombre,'agencia_cobro',gc.nombre,'asesor',ad.nombre_completo,
 'cuotas',(select jsonb_agg(jsonb_build_object('numero',q.numero_cuota,'importe',pc.importe,'capital',q.amortizacion,'interes',q.interes) order by q.numero_cuota) from public.pagos_cuotas pc join public.cuotas q on q.id=pc.cuota_id where pc.pago_id=pa.id)) into r
 from public.pagos pa join public.prestamos p on p.id=pa.prestamo_id join public.clientes c on c.id=p.cliente_id
 join public.agencias go on go.id=p.agencia_id join public.agencias gc on gc.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id
 where pa.id=p_pago and (p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id);
 if r is null then raise exception 'Constancia no disponible para su agencia.' using errcode='42501';end if;return r;end$function$;

CREATE OR REPLACE FUNCTION private.detalle_cobranza(p_busqueda text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;r jsonb;k text;begin
 a:=private.asesor();k:=lower(regexp_replace(trim(p_busqueda),'^PR-','','i'));
 if p_busqueda!~'^[0-9]{8}$' and not private.validar_ruc(p_busqueda) and k!~'^[a-f0-9]{8}$' and k!~'^[a-f0-9]{8}-[a-f0-9-]{27,28}$' then raise exception 'Ingrese DNI exacto o código de préstamo.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'cliente_id',p.cliente_id,'monto',p.monto,'plazo_meses',p.plazo_meses,'conciliado',p.conciliado,
 'fecha_prestamo',p.fecha_prestamo,'agencia_origen',g.nombre,'nombre',case when c.tipo_cliente='juridica' then coalesce(c.razon_social,c.nombres) else c.nombres||' '||c.apellidos end,'dni',c.dni,'ruc',c.ruc,'tipo_cliente',c.tipo_cliente,'fecha_cotizacion',public.fecha_peru(),
 'cuotas',(select coalesce(jsonb_agg(to_jsonb(q)||jsonb_build_object('pagada',pc.cuota_id is not null,'pago_id',pc.pago_id) order by q.numero_cuota),'[]') from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id),
 'pagos',(select coalesce(jsonb_agg(jsonb_build_object('id',pa.id,'importe',pa.importe,'created_at',pa.created_at,'agencia',ga.nombre,'asesor',ad.nombre_completo,'puede_ver_constancia',(p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id)) order by pa.created_at desc),'[]') from public.pagos pa join public.agencias ga on ga.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id where pa.prestamo_id=p.id))), '[]') into r
 from public.prestamos p join public.clientes c on c.id=p.cliente_id join public.agencias g on g.id=p.agencia_id
 where p.estado='confirmado' and (case when p_busqueda~'^[0-9]{8}$' then coalesce(c.propietario_id,c.id)=(select t.id from public.clientes t where t.tipo_cliente='natural' and t.dni=p_busqueda) when private.validar_ruc(p_busqueda) then coalesce(c.propietario_id,c.id)=(select coalesce(t.propietario_id,t.id) from public.clientes t where t.ruc=p_busqueda) else left(p.id::text,8)=k or p.id::text=k end);
 return r;end$function$;

CREATE OR REPLACE FUNCTION private.permisos_actuales()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;p private.permisos_operacion;begin
 a:=private.asesor();select * into p from private.permisos_operacion where asesor_id=a.id;
 return jsonb_build_object('autoriza_credito',coalesce(p.autoriza_credito,false));end$function$;

CREATE OR REPLACE FUNCTION private.registrar_pago(p_prestamo uuid, p_cantidad integer, p_clave uuid, p_primera uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;p public.prestamos;prev public.pagos;ids uuid[];importe numeric;p_id uuid;begin
 a:=private.asesor();select * into p from public.prestamos where id=p_prestamo and estado='confirmado';
 if p.id is null then raise exception 'Préstamo no encontrado.';end if;
 perform 1 from public.clientes where id=p.cliente_id for update;
 select * into prev from public.pagos where clave_operacion=p_clave;
 if prev.id is not null then
 if prev.asesor_id<>a.id or prev.prestamo_id<>p_prestamo or prev.cantidad_cuotas<>p_cantidad then raise exception 'La operación ya fue utilizada.';end if;return prev.id;end if;
 if not p.conciliado then raise exception 'El historial necesita conciliación antes del cobro.';end if;
 if p_clave is null or p_cantidad is null or p_cantidad<1 or p_cantidad>60 then raise exception 'Seleccione cuotas completas.';end if;
 select array_agg(id order by numero_cuota),sum(cuota_total) into ids,importe from
 (select q.id,q.numero_cuota,q.cuota_total from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p_prestamo and pc.cuota_id is null and q.cuota_total>0 order by q.numero_cuota limit p_cantidad) q;
 if coalesce(array_length(ids,1),0)<>p_cantidad or p_primera is null or ids[1]<>p_primera then raise exception 'Las cuotas ya fueron pagadas. Actualice la consulta.';end if;
 if nullif(current_setting('app.cobro_total',true),'') is not null and (importe::numeric<>nullif(current_setting('app.cobro_total',true),'')::numeric or public.fecha_peru()::text<>current_setting('app.cobro_fecha',true)) then raise exception 'El importe o la fecha cambió. Consulte nuevamente las cuotas.';end if;
 perform private.actualizar_cliente(p.cliente_id);
 insert into public.pagos(prestamo_id,agencia_id,asesor_id,importe,clave_operacion,cantidad_cuotas) values(p.id,a.agencia_id,a.id,importe,p_clave,p_cantidad) returning id into p_id;
 insert into public.pagos_cuotas(cuota_id,pago_id,importe) select id,p_id,cuota_total from public.cuotas where id=any(ids);
 perform private.actualizar_cliente(p.cliente_id);return p_id;end$function$;

CREATE OR REPLACE FUNCTION private.saldos_prestamo(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;p public.prestamos;s jsonb;begin
 a:=private.asesor();select * into p from public.prestamos where id=p_id and agencia_id=a.agencia_id;
 if p.id is null then raise exception 'Préstamo fuera de su agencia.' using errcode='42501';end if;
 select jsonb_build_object('total_programado',coalesce(sum(q.cuota_total),0),'interes_total',coalesce(sum(q.interes),0),
 'total_pagado',coalesce(sum(pc.importe) filter(where pc.cuota_id is not null),0),
 'capital_pendiente',coalesce(sum(q.amortizacion) filter(where pc.cuota_id is null),0),
 'deuda_pendiente',coalesce(sum(q.cuota_total) filter(where pc.cuota_id is null),0),
 'estado_deuda',case when count(*) filter(where pc.cuota_id is null and q.cuota_total>0)=0 and count(*)>0 then 'cancelado' else 'activo' end)
 into s from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p_id;
 return s;end$function$;

CREATE OR REPLACE FUNCTION private.situacion(p_cliente uuid, p_hoy date DEFAULT fecha_peru())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c public.clientes;g uuid;s jsonb;capital numeric;deuda numeric;ven date;conc boolean;cond text;ver text;inc date;aut timestamptz;bloq boolean;begin
 perform private.asesor();select * into c from public.clientes where id=p_cliente;if c.id is null then raise exception 'Cliente no encontrado.';end if;
 g:=coalesce(c.propietario_id,c.id);
 select coalesce(sum(q.amortizacion) filter(where pc.cuota_id is null),0),coalesce(sum(q.cuota_total) filter(where pc.cuota_id is null),0),min(q.fecha_vencimiento) filter(where pc.cuota_id is null and q.cuota_total>0 and q.fecha_vencimiento<p_hoy),coalesce(bool_and(p.conciliado),true)
 into capital,deuda,ven,conc from public.clientes gc join public.prestamos p on p.cliente_id=gc.id and p.estado='confirmado' join public.cuotas q on q.prestamo_id=p.id left join public.pagos_cuotas pc on pc.cuota_id=q.id where coalesce(gc.propietario_id,gc.id)=g;
 cond:=case when ven is null then 'habilitado' when (ven+interval '12 months')::date<=p_hoy then 'extrajudicial' else 'atrasado' end;
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
 return jsonb_build_object('capital_pendiente',capital,'capital_disponible',greatest(0,private.parametro('capital_maximo')-capital),'limite',private.parametro('capital_maximo'),'deuda_pendiente',deuda,'atraso_desde',ven,'condicion_pago',case when conc then cond else 'por_conciliar' end,'conciliado',conc,'verificacion',ver,'antecedente_extrajudicial',inc,'requiere_autorizacion',bloq,'propietario_id',g,'elegible',conc and cond='habilitado' and ver='aprobada' and not bloq);
end$function$;

CREATE OR REPLACE FUNCTION private.situacion_individual(p_cliente uuid, p_hoy date DEFAULT fecha_peru())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.asesores;c public.clientes;capital numeric;deuda numeric;vencimiento date;cond text;conc boolean;ver text;begin
 a:=private.asesor();select * into c from public.clientes where id=p_cliente;
 if c.id is null then raise exception 'Cliente no encontrado.';end if;
 select coalesce(sum(q.amortizacion) filter(where pc.cuota_id is null),0),
 coalesce(sum(q.cuota_total) filter(where pc.cuota_id is null),0),
 min(q.fecha_vencimiento) filter(where pc.cuota_id is null and q.cuota_total>0 and q.fecha_vencimiento<p_hoy)
 into capital,deuda,vencimiento from public.prestamos p join public.cuotas q on q.prestamo_id=p.id
 left join public.pagos_cuotas pc on pc.cuota_id=q.id where p.cliente_id=p_cliente and p.estado='confirmado';
 select coalesce(bool_and(conciliado),true) into conc from public.prestamos where cliente_id=p_cliente and estado='confirmado';
 cond:=case when vencimiento is null then 'habilitado'
 when (vencimiento+make_interval(months=>private.parametro('meses_extrajudicial')::int))::date<=p_hoy then 'extrajudicial' else 'atrasado' end;
 ver:=case when c.fallecimiento_acreditado then 'rechazada'
 when c.verificacion_resultado='aprobada' and (c.dni_caducidad is null or c.dni_caducidad<p_hoy) then 'caducada' else c.verificacion_resultado end;
 return jsonb_build_object('capital_pendiente',capital,'capital_disponible',greatest(0,private.parametro('capital_maximo')-capital),
 'limite',private.parametro('capital_maximo'),'deuda_pendiente',deuda,'atraso_desde',vencimiento,
 'condicion_pago',case when conc then cond else 'por_conciliar' end,'conciliado',conc,'verificacion',ver,
 'elegible',conc and cond='habilitado' and ver='aprobada');end$function$;

-- Respuesta mínima, exacta y global: no revela ficha ni deudas de terceros vinculados.
create or replace function private.tiene_deuda_pendiente_ruc(p_ruc text) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.asesor();
 if not private.validar_ruc(p_ruc) then raise exception 'RUC inválido.';end if;
 return exists(select 1 from public.clientes c join public.prestamos p on p.cliente_id=c.id
  join public.cuotas q on q.prestamo_id=p.id
  left join public.pagos_cuotas pc on pc.cuota_id=q.id
  where c.ruc=p_ruc and p.estado='confirmado' and q.cuota_total>0 and pc.cuota_id is null);
end$$;
create or replace function public.tiene_deuda_pendiente_ruc(p_ruc text) returns boolean
language sql stable security invoker set search_path='' as $$select private.tiene_deuda_pendiente_ruc(p_ruc)$$;
create or replace function public.confirmar_prestamo_cotizado(p_tipo text,p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid) returns uuid
language sql security invoker set search_path='' as $$select private.confirmar_prestamo_cotizado(p_tipo,p_datos,p_monto,p_meses,p_clave)$$;
revoke all on function private.tiene_deuda_pendiente_ruc(text),public.tiene_deuda_pendiente_ruc(text),private.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid),public.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid) from public,anon;
grant execute on function private.tiene_deuda_pendiente_ruc(text),public.tiene_deuda_pendiente_ruc(text),private.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid),public.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid) to authenticated;

drop function if exists private.mora_cuota(uuid,date);
alter table public.prestamos drop column if exists tasa_moratoria_anual,drop column if exists base_mora;
alter table public.pagos_cuotas drop column if exists interes_moratorio;
alter table private.permisos_operacion drop column if exists configura_mora;
drop table if exists private.historial_configuracion_mora;
delete from public.parametros_negocio where clave in ('tasa_moratoria_anual','base_mora','dias_gracia_mora');
update public.clientes set condicion_pago='atrasado' where condicion_pago='moroso';
update public.historial_condicion_pago set condicion_anterior=case when condicion_anterior='moroso' then 'atrasado' else condicion_anterior end,condicion_nueva=case when condicion_nueva='moroso' then 'atrasado' else condicion_nueva end where condicion_anterior='moroso' or condicion_nueva='moroso';
update public.prestamos set identidad_contrato=identidad_contrato-'mora_desde'-'tasa_moratoria_anual'-'base_mora' where identidad_contrato ?| array['mora_desde','tasa_moratoria_anual','base_mora'];
-- Mantener identificada la plantilla de las nuevas operaciones, sin configuración financiera extra.
create or replace function private.fijar_version_contrato() returns trigger
language plpgsql security invoker set search_path='' as $$begin
 new.identidad_contrato:=coalesce(new.identidad_contrato,'{}'::jsonb)||jsonb_build_object('version_plantilla','profesor-sin-anexo-v2');return new;
end$$;
revoke all on function private.fijar_version_contrato() from public,anon,authenticated;
drop trigger if exists fijar_version_contrato on public.prestamos;
create trigger fijar_version_contrato before insert on public.prestamos for each row execute function private.fijar_version_contrato();
notify pgrst,'reload schema';
commit;
