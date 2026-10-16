-- Incremento compatible: los préstamos y cronogramas existentes no se recalculan.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
create table if not exists private.configuracion(clave text primary key, valor text not null);
revoke all on private.configuracion from public, anon, authenticated;
create table public.parametros_negocio(clave text primary key, valor numeric not null, descripcion text not null);
insert into public.parametros_negocio values
 ('capital_maximo',10000,'Capital pendiente global máximo'),('plazo_max_meses',60,'Plazo máximo entero'),
 ('dias_gracia_mora',0,'Mora al día siguiente del vencimiento'),('meses_extrajudicial',12,'Meses calendario de atraso');
alter table public.parametros_negocio enable row level security;
create function public.fecha_peru() returns date language sql stable set search_path='' as $$select (now() at time zone 'America/Lima')::date$$;
create function private.asesor() returns public.asesores language plpgsql stable security definer set search_path='' as $$
declare a public.asesores; begin
 select * into a from public.asesores where id=auth.uid() and activo;
 if a.id is null then raise exception 'Cuenta sin autorización de asesor.' using errcode='42501'; end if;
 return a; end$$;
create function private.agencia() returns uuid language sql stable security definer set search_path='' as $$select (private.asesor()).agencia_id$$;
create function private.parametro(k text) returns numeric language sql stable security definer set search_path='' as $$select valor from public.parametros_negocio where clave=k$$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$begin return new; end$$;
-- Las nuevas cuentas se preconfiguran por un administrador; no se autoriza desde user_metadata.
create table public.verificaciones_identidad(
 id uuid primary key default gen_random_uuid(),cliente_id uuid not null references public.clientes(id),
 resultado text not null check(resultado in ('aprobada','pendiente','rechazada')),fecha_caducidad date,
 fuente text not null,nombres_fuente text,apellidos_fuente text,evidencia_vigencia text,evidencia_supervivencia text,
 no_fallecido_acreditado boolean not null default false,documento_original_revisado boolean not null default false,
 origen text not null,detalle_legacy text,asesor_id uuid references public.asesores(id),created_at timestamptz not null default now()
);
alter table public.clientes add column verificacion_resultado text not null default 'pendiente',
 add column dni_caducidad date,add column fallecimiento_acreditado boolean not null default false,
 add column condicion_pago text not null default 'habilitado',add column mora_desde date,
 add column situacion_actualizada_at timestamptz;
alter table public.prestamos add column conciliado boolean not null default false,
 add column estado_deuda text not null default 'activo',add column clave_operacion uuid unique;
create unique index prestamos_codigo_unico on public.prestamos ((left(id::text,8)));
create table public.pagos(
 id uuid primary key default gen_random_uuid(),prestamo_id uuid not null references public.prestamos(id),
 agencia_id uuid not null references public.agencias(id),asesor_id uuid not null references public.asesores(id),
 importe numeric(14,2) not null check(importe>0),clave_operacion uuid not null unique,
 cantidad_cuotas integer not null check(cantidad_cuotas>0),created_at timestamptz not null default now()
);
create table public.pagos_cuotas(
 cuota_id uuid primary key references public.cuotas(id),pago_id uuid not null references public.pagos(id),
 importe numeric(14,2) not null check(importe>0)
);
create table public.historial_condicion_pago(
 id uuid primary key default gen_random_uuid(),cliente_id uuid not null references public.clientes(id),
 condicion_anterior text,condicion_nueva text not null,mora_desde date,created_at timestamptz not null default now()
);
create index pagos_prestamo_idx on public.pagos(prestamo_id);
create index pagos_agencia_idx on public.pagos(agencia_id);
create index pagos_asesor_idx on public.pagos(asesor_id);
create index pagos_cuotas_pago_idx on public.pagos_cuotas(pago_id);
create index verificaciones_cliente_idx on public.verificaciones_identidad(cliente_id,created_at desc);
create index verificaciones_asesor_idx on public.verificaciones_identidad(asesor_id);
create index historial_cliente_idx on public.historial_condicion_pago(cliente_id,created_at desc);
create index prestamos_agencia_fecha_idx on public.prestamos(agencia_id,confirmado_at desc);
create index prestamos_cliente_idx on public.prestamos(cliente_id);
create index cuotas_prestamo_idx on public.cuotas(prestamo_id,numero_cuota);
-- Una evidencia legada no constituye una nueva acreditación oficial.
insert into public.verificaciones_identidad(cliente_id,resultado,fecha_caducidad,fuente,origen,detalle_legacy,asesor_id,created_at)
 select id,'pendiente',case when resultado_verificacion ~ 'DNI vigente hasta [0-9]{4}-[0-9]{2}-[0-9]{2}'
 then substring(resultado_verificacion from 'DNI vigente hasta ([0-9]{4}-[0-9]{2}-[0-9]{2})')::date end,
 coalesce(fuente_verificacion,'Registro anterior'),'migracion',resultado_verificacion,asesor_id,coalesce(fecha_verificacion,created_at) from public.clientes;
update public.clientes c set dni_caducidad=v.fecha_caducidad from public.verificaciones_identidad v where v.cliente_id=c.id;
-- Solo cronogramas completos y sin vencimientos anteriores al corte pueden arrancar sin pagos previos.
update public.prestamos p set conciliado=true where estado='confirmado'
 and (select count(*) from public.cuotas q where q.prestamo_id=p.id)=p.plazo_meses
 and (select sum(amortizacion) from public.cuotas q where q.prestamo_id=p.id)=p.monto
 and (select min(fecha_vencimiento) from public.cuotas q where q.prestamo_id=p.id)>=public.fecha_peru();
create function private.situacion(p_cliente uuid,p_hoy date default public.fecha_peru()) returns jsonb
 language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;c public.clientes;capital numeric;deuda numeric;vencimiento date;cond text;conc boolean;ver text;begin
 a:=private.asesor();select * into c from public.clientes where id=p_cliente;
 if c.id is null then raise exception 'Cliente no encontrado.';end if;
 select coalesce(sum(q.amortizacion) filter(where pc.cuota_id is null),0),
 coalesce(sum(q.cuota_total) filter(where pc.cuota_id is null),0),
 min(q.fecha_vencimiento) filter(where pc.cuota_id is null and q.cuota_total>0 and q.fecha_vencimiento+private.parametro('dias_gracia_mora')::int<p_hoy)
 into capital,deuda,vencimiento from public.prestamos p join public.cuotas q on q.prestamo_id=p.id
 left join public.pagos_cuotas pc on pc.cuota_id=q.id where p.cliente_id=p_cliente and p.estado='confirmado';
 select coalesce(bool_and(conciliado),true) into conc from public.prestamos where cliente_id=p_cliente and estado='confirmado';
 cond:=case when vencimiento is null then 'habilitado'
 when (vencimiento+make_interval(months=>private.parametro('meses_extrajudicial')::int))::date<=p_hoy then 'extrajudicial' else 'moroso' end;
 ver:=case when c.fallecimiento_acreditado then 'rechazada'
 when c.verificacion_resultado='aprobada' and (c.dni_caducidad is null or c.dni_caducidad<p_hoy) then 'caducada' else c.verificacion_resultado end;
 return jsonb_build_object('capital_pendiente',capital,'capital_disponible',greatest(0,private.parametro('capital_maximo')-capital),
 'limite',private.parametro('capital_maximo'),'deuda_pendiente',deuda,'mora_desde',vencimiento,
 'condicion_pago',case when conc then cond else 'por_conciliar' end,'conciliado',conc,'verificacion',ver,
 'elegible',conc and cond='habilitado' and ver='aprobada');end$$;
create function public.resumen_cliente(p_cliente uuid) returns jsonb language sql stable security invoker set search_path='' as $$select private.situacion(p_cliente)$$;
create view public.clientes_resumen with(security_invoker=true) as select c.*,private.situacion(c.id) as situacion from public.clientes c;
create function private.saldos_prestamo(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;p public.prestamos;s jsonb;begin
 a:=private.asesor();select * into p from public.prestamos where id=p_id and agencia_id=a.agencia_id;
 if p.id is null then raise exception 'Préstamo fuera de su agencia.' using errcode='42501';end if;
 select jsonb_build_object('total_programado',coalesce(sum(q.cuota_total),0),'interes_total',coalesce(sum(q.interes),0),
 'total_pagado',coalesce(sum(q.cuota_total) filter(where pc.cuota_id is not null),0),
 'capital_pendiente',coalesce(sum(q.amortizacion) filter(where pc.cuota_id is null),0),
 'deuda_pendiente',coalesce(sum(q.cuota_total) filter(where pc.cuota_id is null),0),
 'estado_deuda',case when count(*) filter(where pc.cuota_id is null and q.cuota_total>0)=0 and count(*)>0 then 'cancelado' else 'activo' end)
 into s from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p_id;
 return s;end$$;
create view public.prestamos_resumen with(security_invoker=true) as select p.*,private.saldos_prestamo(p.id) as saldos from public.prestamos p;
create function private.sin_edicion() returns trigger language plpgsql set search_path='' as $$begin raise exception 'La operación confirmada es de solo lectura.' using errcode='42501';end$$;
create trigger pagos_inmutables before update or delete on public.pagos for each row execute function private.sin_edicion();
create trigger aplicaciones_inmutables before update or delete on public.pagos_cuotas for each row execute function private.sin_edicion();
create trigger verificaciones_inmutables before update or delete on public.verificaciones_identidad for each row execute function private.sin_edicion();
-- Public wrappers are SECURITY INVOKER. Privileged implementation stays out of exposed schemas.
create function private.registrar_identidad(p_payload text,p_firma text,p_evidencia jsonb) returns uuid
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
 evidencia_vigencia,evidencia_supervivencia,no_fallecido_acreditado,documento_original_revisado,origen,asesor_id)
 values(c_id,'aprobada',cad,'Decolecta',datos->>'nombres',datos->>'apellidos',left(p_evidencia->>'vigencia',500),left(p_evidencia->>'supervivencia',500),true,true,'verificacion',a.id);
 update public.clientes set nombres=datos->>'nombres',apellidos=datos->>'apellidos',verificacion_resultado='aprobada',dni_caducidad=cad,
 fecha_verificacion=now(),fuente_verificacion='Decolecta',asesor_id=a.id where id=c_id;
 return c_id;end$$;
create function public.registrar_identidad(p_payload text,p_firma text,p_evidencia jsonb) returns uuid language sql security invoker set search_path='' as $$select private.registrar_identidad(p_payload,p_firma,p_evidencia)$$;
create function private.crear_prestamo(p_cliente uuid,p_monto numeric,p_meses integer,p_clave uuid) returns uuid
 language plpgsql security definer set search_path='' as $$
declare a public.asesores;s jsonb;p_id uuid;tem numeric:=power(1.3::numeric,1.0/12)-1;cuota numeric;interes numeric;capital numeric;saldo numeric;fecha date:=public.fecha_peru();k int;begin
 a:=private.asesor();perform 1 from public.clientes where id=p_cliente for update;
 select id into p_id from public.prestamos where clave_operacion=p_clave and asesor_id=a.id;
 if p_id is not null then
 if not exists(select 1 from public.prestamos where id=p_id and cliente_id=p_cliente and monto=p_monto and plazo_meses=p_meses) then raise exception 'La clave pertenece a otra operación.';end if;return p_id;end if;
 s:=private.situacion(p_cliente);
 if not (s->>'elegible')::boolean then raise exception 'Cliente no elegible: revise DNI, condición de pago y conciliación.';end if;
 if p_clave is null or p_monto is null or p_monto<=0 or p_monto<>round(p_monto,2) or p_meses is null or p_meses<1 or p_meses>private.parametro('plazo_max_meses') then raise exception 'Monto o plazo inválido.';end if;
 if (s->>'capital_pendiente')::numeric+p_monto>private.parametro('capital_maximo') then raise exception 'El monto excede el capital disponible global.';end if;
 insert into public.prestamos(cliente_id,agencia_id,asesor_id,fecha_prestamo,monto,plazo_meses,tea,estado,confirmado_at,conciliado,clave_operacion)
 values(p_cliente,a.agencia_id,a.id,fecha,p_monto,p_meses,0.30,'confirmado',now(),true,p_clave) returning id into p_id;
 cuota:=round(p_monto*tem/(1-power(1+tem,-p_meses)),2);saldo:=p_monto;
 for k in 1..p_meses loop
 interes:=round(saldo*tem,2);capital:=case when k=p_meses then saldo else round(cuota-interes,2) end;
 if k=p_meses then cuota:=capital+interes;end if;saldo:=round(saldo-capital,2);
 insert into public.cuotas(prestamo_id,numero_cuota,fecha_vencimiento,cuota_total,interes,amortizacion,saldo)
 values(p_id,k,(fecha+make_interval(months=>k))::date,cuota,interes,capital,saldo);
 end loop;return p_id;end$$;
create function public.crear_prestamo(p_cliente uuid,p_monto numeric,p_meses integer,p_clave uuid) returns uuid language sql security invoker set search_path='' as $$select private.crear_prestamo(p_cliente,p_monto,p_meses,p_clave)$$;
create function private.actualizar_cliente(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare s jsonb;prev text;nueva text;begin
 -- caller must be an active adviser or the internal scheduled worker.
 s:=private.situacion(p_id);select condicion_pago into prev from public.clientes where id=p_id;
 nueva:=s->>'condicion_pago';
 if nueva is distinct from prev then insert into public.historial_condicion_pago(cliente_id,condicion_anterior,condicion_nueva,mora_desde) values(p_id,prev,nueva,(s->>'mora_desde')::date);end if;
 update public.clientes set condicion_pago=nueva,mora_desde=(s->>'mora_desde')::date,situacion_actualizada_at=now() where id=p_id;
 update public.prestamos p set estado_deuda=case when exists(select 1 from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id and pc.cuota_id is null and q.cuota_total>0) then 'activo' else 'cancelado' end where p.cliente_id=p_id and p.estado='confirmado';end$$;
create function private.registrar_pago(p_prestamo uuid,p_cantidad integer,p_clave uuid,p_primera uuid) returns uuid language plpgsql security definer set search_path='' as $$
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
 perform private.actualizar_cliente(p.cliente_id);
 insert into public.pagos(prestamo_id,agencia_id,asesor_id,importe,clave_operacion,cantidad_cuotas) values(p.id,a.agencia_id,a.id,importe,p_clave,p_cantidad) returning id into p_id;
 insert into public.pagos_cuotas(cuota_id,pago_id,importe) select id,p_id,cuota_total from public.cuotas where id=any(ids);
 perform private.actualizar_cliente(p.cliente_id);return p_id;end$$;
create function public.registrar_pago(p_prestamo uuid,p_cantidad integer,p_clave uuid,p_primera uuid) returns uuid language sql security invoker set search_path='' as $$select private.registrar_pago(p_prestamo,p_cantidad,p_clave,p_primera)$$;
create function private.detalle_cobranza(p_busqueda text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;r jsonb;k text;begin
 a:=private.asesor();k:=lower(regexp_replace(trim(p_busqueda),'^PR-','','i'));
 if p_busqueda!~'^[0-9]{8}$' and k!~'^[a-f0-9]{8}$' and k!~'^[a-f0-9]{8}-[a-f0-9-]{27,28}$' then raise exception 'Ingrese DNI exacto o código de préstamo.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'cliente_id',p.cliente_id,'monto',p.monto,'plazo_meses',p.plazo_meses,'conciliado',p.conciliado,
 'fecha_prestamo',p.fecha_prestamo,'agencia_origen',g.nombre,'nombre',c.nombres||' '||c.apellidos,'dni',c.dni,
 'cuotas',(select coalesce(jsonb_agg(to_jsonb(q)||jsonb_build_object('pagada',pc.cuota_id is not null,'pago_id',pc.pago_id) order by q.numero_cuota),'[]') from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id),
 'pagos',(select coalesce(jsonb_agg(jsonb_build_object('id',pa.id,'importe',pa.importe,'created_at',pa.created_at,'agencia',ga.nombre,'asesor',ad.nombre_completo,'puede_ver_constancia',(p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id)) order by pa.created_at desc),'[]') from public.pagos pa join public.agencias ga on ga.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id where pa.prestamo_id=p.id))), '[]') into r
 from public.prestamos p join public.clientes c on c.id=p.cliente_id join public.agencias g on g.id=p.agencia_id
 where p.estado='confirmado' and (c.dni=p_busqueda or left(p.id::text,8)=k or p.id::text=k);
 return r;end$$;
create function public.buscar_cobranza(p_busqueda text) returns jsonb language sql stable security invoker set search_path='' as $$select private.detalle_cobranza(p_busqueda)$$;
create function private.constancia(p_pago uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;r jsonb;begin
 a:=private.asesor();
 select to_jsonb(pa)||jsonb_build_object('dni',c.dni,'cliente',c.nombres||' '||c.apellidos,'agencia_origen',go.nombre,'agencia_cobro',gc.nombre,'asesor',ad.nombre_completo,
 'cuotas',(select jsonb_agg(jsonb_build_object('numero',q.numero_cuota,'importe',q.cuota_total,'capital',q.amortizacion,'interes',q.interes) order by q.numero_cuota) from public.pagos_cuotas pc join public.cuotas q on q.id=pc.cuota_id where pc.pago_id=pa.id)) into r
 from public.pagos pa join public.prestamos p on p.id=pa.prestamo_id join public.clientes c on c.id=p.cliente_id
 join public.agencias go on go.id=p.agencia_id join public.agencias gc on gc.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id
 where pa.id=p_pago and (p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id);
 if r is null then raise exception 'Constancia no disponible para su agencia.' using errcode='42501';end if;return r;end$$;
create function public.constancia_pago(p_pago uuid) returns jsonb language sql stable security invoker set search_path='' as $$select private.constancia(p_pago)$$;
-- Remove all older permissive policies before adding scoped access.
do $$declare r record;begin for r in select tablename,policyname from pg_policies where schemaname='public' and tablename in ('agencias','asesores','clientes','prestamos','cuotas') loop execute format('drop policy %I on public.%I',r.policyname,r.tablename);end loop;end$$;
create policy asesor_propio on public.asesores for select to authenticated using(id=(select auth.uid()) and activo);
create policy agencias_asesor on public.agencias for select to authenticated using((select private.agencia()) is not null);
create policy clientes_asesor on public.clientes for select to authenticated using((select private.agencia()) is not null);
create policy cartera_propia on public.prestamos for select to authenticated using(agencia_id=(select private.agencia()));
create policy cuotas_cartera on public.cuotas for select to authenticated using(exists(select 1 from public.prestamos p where p.id=prestamo_id and p.agencia_id=(select private.agencia())));
create policy parametros_asesor on public.parametros_negocio for select to authenticated using((select private.agencia()) is not null);
alter table public.verificaciones_identidad enable row level security;
alter table public.pagos enable row level security;
alter table public.pagos_cuotas enable row level security;
alter table public.historial_condicion_pago enable row level security;
create policy verificaciones_asesor on public.verificaciones_identidad for select to authenticated using((select private.agencia()) is not null);
create policy historial_asesor on public.historial_condicion_pago for select to authenticated using((select private.agencia()) is not null);
create policy pagos_agencia on public.pagos for select to authenticated using(agencia_id=(select private.agencia()) or exists(select 1 from public.prestamos p where p.id=prestamo_id));
create policy aplicaciones_agencia on public.pagos_cuotas for select to authenticated using(exists(select 1 from public.pagos p where p.id=pago_id));
revoke all on public.clientes,public.prestamos,public.cuotas,public.asesores,public.agencias,public.pagos,public.pagos_cuotas,public.verificaciones_identidad,public.historial_condicion_pago,public.parametros_negocio from anon,authenticated;
grant select on public.clientes,public.prestamos,public.cuotas,public.asesores,public.agencias,public.pagos,public.pagos_cuotas,public.verificaciones_identidad,public.historial_condicion_pago,public.parametros_negocio,public.clientes_resumen,public.prestamos_resumen to authenticated;
revoke all on public.clientes_resumen,public.prestamos_resumen from anon;
revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function private.agencia(),private.situacion(uuid,date),private.saldos_prestamo(uuid),private.registrar_identidad(text,text,jsonb),private.crear_prestamo(uuid,numeric,integer,uuid),private.registrar_pago(uuid,integer,uuid,uuid),private.detalle_cobranza(text),private.constancia(uuid) to authenticated;
revoke all on function public.resumen_cliente(uuid),public.registrar_identidad(text,text,jsonb),public.crear_prestamo(uuid,numeric,integer,uuid),public.registrar_pago(uuid,integer,uuid,uuid),public.buscar_cobranza(text),public.constancia_pago(uuid) from public,anon;
grant execute on function public.resumen_cliente(uuid),public.registrar_identidad(text,text,jsonb),public.crear_prestamo(uuid,numeric,integer,uuid),public.registrar_pago(uuid,integer,uuid,uuid),public.buscar_cobranza(text),public.constancia_pago(uuid) to authenticated;
-- Retire the old bypass aggregate endpoint.
revoke all on function public.capital_vigente(uuid,uuid) from public,anon,authenticated;
alter function public.capital_vigente(uuid,uuid) set search_path='public';
alter function public.set_updated_at() set search_path='public';
-- Daily snapshot; dynamic queries always calculate current states even if Cron is late.
create function private.corte_diario() returns void language plpgsql security definer set search_path='' as $$
declare r record;operador uuid;begin
 select id into operador from public.asesores where activo order by created_at limit 1;
 if operador is null then return;end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',operador,'role','authenticated')::text,true);
 for r in select id from public.clientes loop perform 1 from public.clientes where id=r.id for update;perform private.actualizar_cliente(r.id);end loop;
 end$$;
revoke all on function private.corte_diario() from public,anon,authenticated;
-- Depuración autorizada: la cuenta de demostración solo se elimina si no tiene operaciones.
do $$declare u uuid;begin
 select a.id into u from public.asesores a join auth.users au on au.id=a.id where au.email='asesor@prestamos.pe' and a.nombre_completo='Ana Morales Delgado';
 if u is not null then
 if exists(select 1 from public.prestamos where asesor_id=u) or exists(select 1 from public.clientes where asesor_id=u) or exists(select 1 from public.pagos where asesor_id=u) or exists(select 1 from public.verificaciones_identidad where asesor_id=u) then
 update public.asesores set activo=false where id=u;
 else delete from public.asesores where id=u;delete from auth.users where id=u;end if;
 end if;
 delete from public.agencias g where lower(nombre)='general' and not exists(select 1 from public.asesores a where a.agencia_id=g.id) and not exists(select 1 from public.prestamos p where p.agencia_id=g.id);
end$$;
alter table public.agencias add constraint agencias_cinco_nombres check(nombre in ('Chimbote','Trujillo','Chiclayo','Piura','Tumbes'));
-- BEGIN CRON (Supabase supports pg_cron; local test runner omits only this extension block).
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('prestamos-corte-peru','5 5 * * *','select private.corte_diario()');
-- END CRON
notify pgrst,'reload schema';
