-- Incremento sin alterar montos, cronogramas o cobros anteriores.
alter table public.clientes alter column dni drop not null;
alter table public.clientes add column tipo_cliente text not null default 'natural' check(tipo_cliente in ('natural','juridica')),
 add column ruc text unique,add column razon_social text,add column estado_ruc text,add column condicion_ruc text,
 add column direccion_fiscal text,add column ruc_consultado_at timestamptz,
 add column propietario_id uuid references public.clientes(id),add column representante_id uuid references public.clientes(id),
 add column evidencia_propiedad text,add column evidencia_poder text;
alter table public.clientes add constraint identidad_tipo check(
 (tipo_cliente='natural' and dni is not null and propietario_id is null and (ruc is null or (ruc like '10%' and substring(ruc,3,8)=dni))) or
 (tipo_cliente='juridica' and dni is null and ruc like '20%' and propietario_id is not null and representante_id is not null));
create index clientes_propietario_idx on public.clientes(propietario_id);
create index clientes_representante_idx on public.clientes(representante_id);
create table private.rehabilitaciones(id uuid primary key default gen_random_uuid(),propietario_id uuid not null references public.clientes(id),motivo text not null,operador text not null default session_user,created_at timestamptz not null default now());
alter table private.rehabilitaciones enable row level security;
revoke all on private.rehabilitaciones from public,anon,authenticated;
alter table public.prestamos add column tasa_moratoria_anual numeric check(tasa_moratoria_anual>=0 and tasa_moratoria_anual<=1),
 add column base_mora integer not null default 360 check(base_mora=360),add column identidad_contrato jsonb;
alter table public.pagos_cuotas add column interes_moratorio numeric(14,2) not null default 0;
create table public.verificaciones_ruc(id uuid primary key default gen_random_uuid(),cliente_id uuid not null references public.clientes(id),ruc text not null,razon_social text not null,estado text not null,condicion text not null,direccion text,propietario_id uuid not null references public.clientes(id),representante_id uuid not null references public.clientes(id),evidencia_propiedad text not null,evidencia_poder text not null,asesor_id uuid not null references public.asesores(id),consultado_at timestamptz not null,created_at timestamptz not null default now());
alter table public.verificaciones_ruc enable row level security;
create policy ruc_agencia on public.verificaciones_ruc for select to authenticated using(private.cliente_visible(cliente_id));
revoke all on public.verificaciones_ruc from public,anon,authenticated;
grant select on public.verificaciones_ruc to authenticated;
create trigger verificaciones_ruc_inmutable before update or delete on public.verificaciones_ruc for each row execute function private.sin_edicion();
create index verificaciones_ruc_cliente_idx on public.verificaciones_ruc(cliente_id,created_at desc);
create index verificaciones_ruc_propietario_idx on public.verificaciones_ruc(propietario_id);
create index verificaciones_ruc_representante_idx on public.verificaciones_ruc(representante_id);
create index verificaciones_ruc_asesor_idx on public.verificaciones_ruc(asesor_id);
create or replace function private.validar_ruc(r text) returns boolean language plpgsql immutable set search_path='' as $$
declare total int:=0;pesos int[]:=array[5,4,3,2,7,6,5,4,3,2];d int;k int;begin
 if r is null or r!~'^(10|20)[0-9]{9}$' then return false;end if;
 for k in 1..10 loop total:=total+substring(r,k,1)::int*pesos[k];end loop;
 d:=11-total%11;d:=case when d=10 then 0 when d=11 then 1 else d end;return d=right(r,1)::int;end$$;
create or replace function private.grupo(p_cliente uuid) returns uuid language sql stable security definer set search_path='' as $$select coalesce(propietario_id,id) from public.clientes where id=p_cliente$$;
create or replace function private.mora_cuota(p_cuota uuid,p_hoy date default public.fecha_peru()) returns numeric language sql stable security definer set search_path='' as $$
 select case when p.tasa_moratoria_anual is null or q.fecha_vencimiento>=p_hoy or pc.cuota_id is not null then 0
 else round(q.amortizacion*(power(1+p.tasa_moratoria_anual,(p_hoy-q.fecha_vencimiento)::numeric/p.base_mora)-1),2) end
 from public.cuotas q join public.prestamos p on p.id=q.prestamo_id left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.id=p_cuota$$;
-- Original individual remains internal; group totals do not expose foreign portfolios.
alter function private.situacion(uuid,date) rename to situacion_individual;
revoke execute on function private.situacion_individual(uuid,date) from authenticated;
create function private.situacion(p_cliente uuid,p_hoy date default public.fecha_peru()) returns jsonb language plpgsql stable security definer set search_path='' as $$
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
 if c.ruc is not null and (c.estado_ruc is distinct from 'ACTIVO' or c.condicion_ruc is distinct from 'HABIDO') then ver:='rechazada';end if;
 return jsonb_build_object('capital_pendiente',capital,'capital_disponible',greatest(0,private.parametro('capital_maximo')-capital),'limite',private.parametro('capital_maximo'),'deuda_pendiente',deuda,'mora_desde',ven,'condicion_pago',case when conc then cond else 'por_conciliar' end,'conciliado',conc,'verificacion',ver,'antecedente_extrajudicial',inc,'requiere_autorizacion',bloq,'propietario_id',g,'elegible',conc and cond='habilitado' and ver='aprobada' and not bloq);
end$$;
grant execute on function private.situacion(uuid,date) to authenticated;
create function private.autorizar_nuevos_prestamos(p_cliente uuid,p_motivo text) returns uuid language plpgsql security definer set search_path='' as $$
declare g uuid;r uuid;begin
 if length(trim(coalesce(p_motivo,'')))<10 then raise exception 'Documente la evaluación de crédito.';end if;
 g:=private.grupo(p_cliente);if g is null then raise exception 'Cliente inexistente.';end if;
 if exists(select 1 from public.clientes c join public.prestamos p on p.cliente_id=c.id join public.cuotas q on q.prestamo_id=p.id left join public.pagos_cuotas pc on pc.cuota_id=q.id where coalesce(c.propietario_id,c.id)=g and p.estado='confirmado' and q.fecha_vencimiento<public.fecha_peru() and q.cuota_total>0 and pc.cuota_id is null) then raise exception 'Primero regularice las cuotas vencidas.';end if;
 insert into private.rehabilitaciones(propietario_id,motivo) values(g,p_motivo) returning id into r;return r;end$$;
revoke all on function private.autorizar_nuevos_prestamos(uuid,text) from public,anon,authenticated;
create or replace function private.crear_prestamo(p_cliente uuid,p_monto numeric,p_meses integer,p_clave uuid) returns uuid
 language plpgsql security definer set search_path='' as $$
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
 insert into public.prestamos(cliente_id,agencia_id,asesor_id,fecha_prestamo,monto,plazo_meses,tea,estado,confirmado_at,conciliado,clave_operacion,identidad_contrato)
 values(p_cliente,a.agencia_id,a.id,fecha,p_monto,p_meses,0.30,'confirmado',now(),true,p_clave,(select to_jsonb(c)||jsonb_build_object('propietario',(select jsonb_build_object('dni',o.dni,'nombre',o.nombres||' '||o.apellidos) from public.clientes o where o.id=coalesce(c.propietario_id,c.id)),'representante',(select jsonb_build_object('dni',r.dni,'nombre',r.nombres||' '||r.apellidos) from public.clientes r where r.id=c.representante_id)) from public.clientes c where c.id=p_cliente)) returning id into p_id;
 cuota:=round(p_monto*tem/(1-power(1+tem,-p_meses)),2);saldo:=p_monto;
 for k in 1..p_meses loop
 interes:=round(saldo*tem,2);capital:=case when k=p_meses then saldo else round(cuota-interes,2) end;
 if k=p_meses then cuota:=capital+interes;end if;saldo:=round(saldo-capital,2);
 insert into public.cuotas(prestamo_id,numero_cuota,fecha_vencimiento,cuota_total,interes,amortizacion,saldo)
 values(p_id,k,(fecha+make_interval(months=>k))::date,cuota,interes,capital,saldo);
 end loop;return p_id;end$$;
create function private.comprobar_firma(p_payload text,p_firma text,p_tipo text) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb;k text;a public.asesores;begin
 a:=private.asesor();select valor into k from private.configuracion where clave='identity_signing_secret';
 if k is null or p_firma is null or p_payload is null or p_firma<>encode(extensions.hmac(p_payload,k,'sha256'),'hex') then raise exception 'Consulta firmada inválida.';end if;
 d:=p_payload::jsonb;if d->>'tipo' is distinct from p_tipo or d->>'asesor_id' is distinct from a.id::text or d->>'consultadoEn' is null or (d->>'consultadoEn')::timestamptz<now()-interval '30 minutes' or (d->>'consultadoEn')::timestamptz>now()+interval '1 minute' then raise exception 'La consulta expiró. Vuelva al paso 1.';end if;return d;end$$;
create function private.persona_ruc(d jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare c uuid;s jsonb;v_dni text;begin
 v_dni:=d->>'dni';if v_dni is null or v_dni!~'^[0-9]{8}$' then raise exception 'DNI de la persona inválido.';end if;
 perform pg_advisory_xact_lock(hashtextextended(v_dni,0));select id into c from public.clientes where public.clientes.dni=v_dni and tipo_cliente='natural';
 if d->'borrador' is not null and d->'borrador'<>'null'::jsonb then
 if d#>>'{borrador,consulta,dni}' is distinct from v_dni then raise exception 'La identidad no coincide.';end if;
 c:=private.registrar_identidad(d#>>'{borrador,consulta,payload}',d#>>'{borrador,consulta,firma}',d#>'{borrador,evidencia}');
 end if;
 if c is null or (private.situacion_individual(c)->>'verificacion')<>'aprobada' then raise exception 'Verifique la identidad y vigencia del DNI.';end if;
 return c;end$$;
create function private.confirmar_ruc_prestamo(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a public.asesores;d jsonb;r text;o uuid;rep uuid;c public.clientes;p_id uuid;begin
 a:=private.asesor();r:=p_datos#>>'{consulta,ruc}';if not private.validar_ruc(r) or p_clave is null then raise exception 'RUC o solicitud inválida.';end if;
 perform pg_advisory_xact_lock(hashtextextended(r,6));
 select p.id into p_id from public.prestamos p join public.clientes cc on cc.id=p.cliente_id where p.clave_operacion=p_clave and p.asesor_id=a.id and cc.ruc=r and p.monto=p_monto and p.plazo_meses=p_meses;
 if p_id is not null then return p_id;end if;
 if exists(select 1 from public.prestamos where clave_operacion=p_clave) then raise exception 'La clave pertenece a otra operación.';end if;
 d:=private.comprobar_firma(p_datos#>>'{consulta,payload}',p_datos#>>'{consulta,firma}','ruc');
 if d->>'ruc' is distinct from r or d->>'estado'<>'ACTIVO' or d->>'condicion'<>'HABIDO' or length(trim(coalesce(d->>'razon_social','')))=0 then raise exception 'El RUC debe existir, estar ACTIVO y HABIDO.';end if;
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
 if length(trim(coalesce(p_datos->>'evidencia_propiedad','')))<10 or length(trim(coalesce(p_datos->>'evidencia_poder','')))<10 then raise exception 'Registre evidencia de propiedad y facultades del representante.';end if;
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
 return private.crear_prestamo(c.id,p_monto,p_meses,p_clave);
end$$;
create function public.confirmar_ruc_prestamo(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid) returns uuid language sql security invoker set search_path='' as $$select private.confirmar_ruc_prestamo(p_datos,p_monto,p_meses,p_clave)$$;
revoke all on function private.comprobar_firma(text,text,text),private.persona_ruc(jsonb),private.validar_ruc(text),private.grupo(uuid),private.mora_cuota(uuid,date),private.confirmar_ruc_prestamo(jsonb,numeric,integer,uuid),public.confirmar_ruc_prestamo(jsonb,numeric,integer,uuid) from public,anon,authenticated;
grant execute on function private.confirmar_ruc_prestamo(jsonb,numeric,integer,uuid),public.confirmar_ruc_prestamo(jsonb,numeric,integer,uuid) to authenticated;
-- App uses the already reviewed view access policy, now with company columns.
drop view public.clientes_resumen;
create view public.clientes_resumen with(security_invoker=true) as select c.*,private.situacion(c.id) as situacion from public.clientes c;
revoke all on public.clientes_resumen from public,anon;grant select on public.clientes_resumen to authenticated;
create or replace function private.resolver_cliente(p_dni text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare c public.clientes;begin
 perform private.asesor();
 if p_dni is null or p_dni!~'^[0-9]{8}$' then raise exception 'Ingresa un DNI de exactamente 8 dígitos numéricos.' using errcode='22023';end if;
 select * into c from public.clientes where dni=p_dni;
 if c.id is null then return null;end if;
 return jsonb_build_object('cliente',jsonb_build_object('id',c.id,'dni',c.dni,'nombres',c.nombres,'apellidos',c.apellidos,'dni_caducidad',c.dni_caducidad,'ruc',c.ruc,'tipo_cliente',c.tipo_cliente), 'verificacion_identidad',private.situacion_individual(c.id)->>'verificacion','situacion',private.situacion(c.id));
end$$;
create or replace function private.detalle_cobranza(p_busqueda text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;r jsonb;k text;begin
 a:=private.asesor();k:=lower(regexp_replace(trim(p_busqueda),'^PR-','','i'));
 if p_busqueda!~'^[0-9]{8}$' and not private.validar_ruc(p_busqueda) and k!~'^[a-f0-9]{8}$' and k!~'^[a-f0-9]{8}-[a-f0-9-]{27,28}$' then raise exception 'Ingrese DNI exacto o código de préstamo.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'cliente_id',p.cliente_id,'monto',p.monto,'plazo_meses',p.plazo_meses,'conciliado',p.conciliado,
 'fecha_prestamo',p.fecha_prestamo,'agencia_origen',g.nombre,'nombre',c.nombres||' '||c.apellidos,'dni',c.dni,'ruc',c.ruc,'tasa_moratoria_anual',p.tasa_moratoria_anual,
 'cuotas',(select coalesce(jsonb_agg(to_jsonb(q)||jsonb_build_object('pagada',pc.cuota_id is not null,'pago_id',pc.pago_id,'interes_moratorio',case when pc.cuota_id is not null then pc.interes_moratorio else private.mora_cuota(q.id) end) order by q.numero_cuota),'[]') from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id),
 'pagos',(select coalesce(jsonb_agg(jsonb_build_object('id',pa.id,'importe',pa.importe,'created_at',pa.created_at,'agencia',ga.nombre,'asesor',ad.nombre_completo,'puede_ver_constancia',(p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id)) order by pa.created_at desc),'[]') from public.pagos pa join public.agencias ga on ga.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id where pa.prestamo_id=p.id))), '[]') into r
 from public.prestamos p join public.clientes c on c.id=p.cliente_id join public.agencias g on g.id=p.agencia_id
 where p.estado='confirmado' and (case when p_busqueda~'^[0-9]{8}$' then c.dni=p_busqueda when private.validar_ruc(p_busqueda) then c.ruc=p_busqueda else left(p.id::text,8)=k or p.id::text=k end);
 return r;end$$;
create or replace function private.buscar_cuotas(p_busqueda text,p_tipo text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare k text;r jsonb;begin
 perform private.asesor();
 if p_tipo='ruc' then
 if not private.validar_ruc(p_busqueda) then raise exception 'RUC inválido.';end if;
 return (select coalesce(jsonb_agg(x),'[]') from jsonb_array_elements(private.detalle_cobranza(p_busqueda)) x where exists(select 1 from jsonb_array_elements(x->'cuotas') q where not (q->>'pagada')::boolean and (q->>'cuota_total')::numeric>0));
 elsif p_tipo='dni' then
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
create or replace function private.registrar_pago(p_prestamo uuid,p_cantidad integer,p_clave uuid,p_primera uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a public.asesores;p public.prestamos;prev public.pagos;ids uuid[];importe numeric;p_id uuid;begin
 a:=private.asesor();select * into p from public.prestamos where id=p_prestamo and estado='confirmado';
 if p.id is null then raise exception 'Préstamo no encontrado.';end if;
 perform 1 from public.clientes where id=p.cliente_id for update;
 select * into prev from public.pagos where clave_operacion=p_clave;
 if prev.id is not null then
 if prev.asesor_id<>a.id or prev.prestamo_id<>p_prestamo or prev.cantidad_cuotas<>p_cantidad then raise exception 'La operación ya fue utilizada.';end if;return prev.id;end if;
 if not p.conciliado then raise exception 'El historial necesita conciliación antes del cobro.';end if;
 if p_clave is null or p_cantidad is null or p_cantidad<1 or p_cantidad>60 then raise exception 'Seleccione cuotas completas.';end if;
 select array_agg(id order by numero_cuota),sum(cuota_total+private.mora_cuota(id)) into ids,importe from
 (select q.id,q.numero_cuota,q.cuota_total from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p_prestamo and pc.cuota_id is null and q.cuota_total>0 order by q.numero_cuota limit p_cantidad) q;
 if coalesce(array_length(ids,1),0)<>p_cantidad or p_primera is null or ids[1]<>p_primera then raise exception 'Las cuotas ya fueron pagadas. Actualice la consulta.';end if;
 if current_setting('app.cobro_total',true) is not null and (importe::numeric<>(current_setting('app.cobro_total',true))::numeric or public.fecha_peru()::text<>current_setting('app.cobro_fecha',true)) then raise exception 'El importe o la fecha cambió. Consulte nuevamente las cuotas.';end if;
 if p.tasa_moratoria_anual is not null and nullif(current_setting('app.cobro_total',true),'') is null then raise exception 'Actualice la consulta para confirmar el importe de mora.';end if;
 perform private.actualizar_cliente(p.cliente_id);
 insert into public.pagos(prestamo_id,agencia_id,asesor_id,importe,clave_operacion,cantidad_cuotas) values(p.id,a.agencia_id,a.id,importe,p_clave,p_cantidad) returning id into p_id;
 insert into public.pagos_cuotas(cuota_id,pago_id,importe,interes_moratorio) select id,p_id,cuota_total+private.mora_cuota(id),private.mora_cuota(id) from public.cuotas where id=any(ids);
 perform private.actualizar_cliente(p.cliente_id);return p_id;end$$;
create or replace function private.constancia(p_pago uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;r jsonb;begin
 a:=private.asesor();
 select to_jsonb(pa)||jsonb_build_object('dni',c.dni,'ruc',c.ruc,'cliente',c.nombres||' '||c.apellidos,'agencia_origen',go.nombre,'agencia_cobro',gc.nombre,'asesor',ad.nombre_completo,
 'cuotas',(select jsonb_agg(jsonb_build_object('numero',q.numero_cuota,'importe',pc.importe,'interes_moratorio',pc.interes_moratorio,'capital',q.amortizacion,'interes',q.interes) order by q.numero_cuota) from public.pagos_cuotas pc join public.cuotas q on q.id=pc.cuota_id where pc.pago_id=pa.id)) into r
 from public.pagos pa join public.prestamos p on p.id=pa.prestamo_id join public.clientes c on c.id=p.cliente_id
 join public.agencias go on go.id=p.agencia_id join public.agencias gc on gc.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id
 where pa.id=p_pago and (p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id);
 if r is null then raise exception 'Constancia no disponible para su agencia.' using errcode='42501';end if;return r;end$$;
notify pgrst, 'reload schema';

create function private.registrar_pago_cotizado(p_prestamo uuid,p_cantidad integer,p_clave uuid,p_primera uuid,p_total numeric,p_fecha date) returns uuid language plpgsql security definer set search_path='' as $$begin
 perform private.asesor();if p_total is null or p_total<=0 or p_fecha is null then raise exception 'Confirme el importe consultado.';end if;
 perform set_config('app.cobro_total',p_total::text,true);perform set_config('app.cobro_fecha',p_fecha::text,true);
 return private.registrar_pago(p_prestamo,p_cantidad,p_clave,p_primera);end$$;
create function public.registrar_pago_cotizado(p_prestamo uuid,p_cantidad integer,p_clave uuid,p_primera uuid,p_total numeric,p_fecha date) returns uuid language sql security invoker set search_path='' as $$select private.registrar_pago_cotizado(p_prestamo,p_cantidad,p_clave,p_primera,p_total,p_fecha)$$;
revoke all on function private.registrar_pago_cotizado(uuid,integer,uuid,uuid,numeric,date),public.registrar_pago_cotizado(uuid,integer,uuid,uuid,numeric,date) from public,anon;
grant execute on function private.registrar_pago_cotizado(uuid,integer,uuid,uuid,numeric,date),public.registrar_pago_cotizado(uuid,integer,uuid,uuid,numeric,date) to authenticated;
notify pgrst, 'reload schema';

create or replace function private.saldos_prestamo(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;p public.prestamos;s jsonb;begin
 a:=private.asesor();select * into p from public.prestamos where id=p_id and agencia_id=a.agencia_id;
 if p.id is null then raise exception 'Préstamo fuera de su agencia.' using errcode='42501';end if;
 select jsonb_build_object('total_programado',coalesce(sum(q.cuota_total),0),'interes_total',coalesce(sum(q.interes),0),
 'total_pagado',coalesce(sum(pc.importe) filter(where pc.cuota_id is not null),0),
 'capital_pendiente',coalesce(sum(q.amortizacion) filter(where pc.cuota_id is null),0),
 'deuda_pendiente',coalesce(sum(q.cuota_total+private.mora_cuota(q.id)) filter(where pc.cuota_id is null),0),
 'estado_deuda',case when count(*) filter(where pc.cuota_id is null and q.cuota_total>0)=0 and count(*)>0 then 'cancelado' else 'activo' end)
 into s from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p_id;
 return s;end$$;
create function private.relaciones_cliente(p_cliente uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;begin
 perform private.asesor();if not private.cliente_visible(p_cliente) then raise exception 'Cliente fuera de su agencia.' using errcode='42501';end if;
 select jsonb_build_object('propietario',jsonb_build_object('dni',o.dni,'nombre',o.nombres||' '||o.apellidos),'representante',case when r.id is not null then jsonb_build_object('dni',r.dni,'nombre',r.nombres||' '||r.apellidos) else null end) into v_result
 from public.clientes c join public.clientes o on o.id=coalesce(c.propietario_id,c.id) left join public.clientes r on r.id=c.representante_id where c.id=p_cliente;return v_result;end$$;
create function public.relaciones_cliente(p_cliente uuid) returns jsonb language sql stable security invoker set search_path='' as $$select private.relaciones_cliente(p_cliente)$$;
revoke all on function private.relaciones_cliente(uuid),public.relaciones_cliente(uuid) from public,anon;
grant execute on function private.relaciones_cliente(uuid),public.relaciones_cliente(uuid) to authenticated;
notify pgrst, 'reload schema';

