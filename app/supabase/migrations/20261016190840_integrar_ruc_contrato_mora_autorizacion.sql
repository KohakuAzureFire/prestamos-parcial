-- Integra las operaciones nuevas sin cambiar cronogramas ni cobros existentes.
create table private.permisos_operacion(
 asesor_id uuid primary key references public.asesores(id),
 autoriza_credito boolean not null default false,
 configura_mora boolean not null default false
);
alter table private.permisos_operacion enable row level security;
revoke all on private.permisos_operacion from public,anon,authenticated;
create function private.permisos_actuales() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;p private.permisos_operacion;begin
 a:=private.asesor();select * into p from private.permisos_operacion where asesor_id=a.id;
 return jsonb_build_object('autoriza_credito',coalesce(p.autoriza_credito,false),'configura_mora',coalesce(p.configura_mora,false));end$$;
create function public.permisos_operacion() returns jsonb language sql stable security invoker set search_path='' as $$select private.permisos_actuales()$$;
-- No se asignan privilegios ni una tasa de negocio sin una definición del responsable.
insert into public.parametros_negocio values ('base_mora',360,'Base anual para nuevos préstamos; 360 o 365 días') on conflict do nothing;
alter table public.prestamos drop constraint prestamos_base_mora_check;
alter table public.prestamos add constraint prestamos_base_mora_check check(base_mora in (360,365));
create table private.historial_configuracion_mora(id uuid primary key default gen_random_uuid(),asesor_id uuid not null references public.asesores(id),tasa_anual numeric,base_anual integer not null,motivo text not null,created_at timestamptz not null default now());
alter table private.historial_configuracion_mora enable row level security;
revoke all on private.historial_configuracion_mora from public,anon,authenticated;
create function private.configurar_mora(p_tasa numeric,p_base integer,p_motivo text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not (private.permisos_actuales()->>'configura_mora')::boolean then raise exception 'No tiene permiso para configurar la mora.' using errcode='42501';end if;
 if p_base is null or p_base not in (360,365) or (p_tasa is not null and (p_tasa<0 or p_tasa>1)) or length(trim(coalesce(p_motivo,'')))<10 then raise exception 'Revise tasa, base y motivo de la configuración.';end if;
 perform pg_advisory_xact_lock(781563::bigint);
 if p_tasa is null then delete from public.parametros_negocio where clave='tasa_moratoria_anual';
 else insert into public.parametros_negocio values('tasa_moratoria_anual',p_tasa,'Tasa efectiva anual moratoria para nuevos préstamos') on conflict(clave) do update set valor=excluded.valor;end if;
 update public.parametros_negocio set valor=p_base where clave='base_mora';
 insert into private.historial_configuracion_mora(asesor_id,tasa_anual,base_anual,motivo) values(auth.uid(),p_tasa,p_base,p_motivo);
end$$;
create function public.configurar_mora(p_tasa numeric,p_base integer,p_motivo text) returns void language sql security invoker set search_path='' as $$select private.configurar_mora(p_tasa,p_base,p_motivo)$$;
create function private.fijar_mora_prestamo() returns trigger language plpgsql security definer set search_path='' as $$
begin
 new.tasa_moratoria_anual:=private.parametro('tasa_moratoria_anual');
 new.base_mora:=coalesce(private.parametro('base_mora'),360)::integer;
 new.identidad_contrato:=coalesce(new.identidad_contrato,'{}'::jsonb)||jsonb_build_object('version_plantilla','profesor-v1');return new;
end$$;
create trigger fijar_mora before insert on public.prestamos for each row execute function private.fijar_mora_prestamo();
-- Un autor designado solo rehabilita clientes de su agencia, con deuda vencida regularizada.
create function private.rehabilitar_cliente(p_cliente uuid,p_motivo text) returns uuid language plpgsql security definer set search_path='' as $$
declare g uuid;s jsonb;r uuid;begin
 if not (private.permisos_actuales()->>'autoriza_credito')::boolean then raise exception 'No tiene permiso para autorizar nuevos préstamos.' using errcode='42501';end if;
 if not private.cliente_visible(p_cliente) then raise exception 'Cliente fuera de su agencia.' using errcode='42501';end if;
 g:=private.grupo(p_cliente);perform pg_advisory_xact_lock(hashtextextended(g::text,4));
 perform 1 from public.clientes where coalesce(propietario_id,id)=g order by id for update;
 s:=private.situacion(p_cliente);
 if s->>'condicion_pago'<>'habilitado' or not (s->>'conciliado')::boolean then raise exception 'Primero regularice las cuotas vencidas y concilie el historial.';end if;
 if not (s->>'requiere_autorizacion')::boolean then raise exception 'El cliente no requiere una nueva autorización.';end if;
 if length(trim(coalesce(p_motivo,'')))<10 then raise exception 'Documente la evaluación de crédito.';end if;
 insert into private.rehabilitaciones(propietario_id,motivo,operador) values(g,p_motivo,auth.uid()::text) returning id into r;return r;
end$$;
create function public.rehabilitar_cliente(p_cliente uuid,p_motivo text) returns uuid language sql security invoker set search_path='' as $$select private.rehabilitar_cliente(p_cliente,p_motivo)$$;
-- Conservar identidad aprobada ante un borrador concurrente de la misma persona.
create or replace function private.persona_ruc(d jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare c uuid;v_dni text;begin
 perform private.asesor();v_dni:=d->>'dni';if v_dni is null or v_dni!~'^[0-9]{8}$' then raise exception 'DNI de la persona inválido.';end if;
 perform pg_advisory_xact_lock(hashtextextended(v_dni,0));select id into c from public.clientes where dni=v_dni and tipo_cliente='natural';
 if c is null then
 if d#>>'{borrador,consulta,dni}' is distinct from v_dni then raise exception 'La identidad no coincide.';end if;
 c:=private.registrar_identidad(d#>>'{borrador,consulta,payload}',d#>>'{borrador,consulta,firma}',d#>'{borrador,evidencia}');
 end if;
 if c is null or (private.situacion_individual(c)->>'verificacion')<>'aprobada' then raise exception 'Verifique la identidad y vigencia del DNI.';end if;return c;
end$$;
-- Fecha de cotización generada por el servidor, no por el reloj del navegador.
create or replace function private.confirmar_ruc_prestamo(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a public.asesores;d jsonb;r text;o uuid;rep uuid;c public.clientes;p_id uuid;begin
 a:=private.asesor();r:=p_datos#>>'{consulta,ruc}';if not private.validar_ruc(r) or p_clave is null then raise exception 'RUC o solicitud inválida.';end if;
 perform pg_advisory_xact_lock(hashtextextended(r,6));
 select p.id into p_id from public.prestamos p join public.clientes cc on cc.id=p.cliente_id where p.clave_operacion=p_clave and p.asesor_id=a.id and cc.ruc=r and p.monto=p_monto and p.plazo_meses=p_meses;
 if p_id is not null then return p_id;end if;
 if exists(select 1 from public.prestamos where clave_operacion=p_clave) then raise exception 'La clave pertenece a otra operación.';end if;
 d:=private.comprobar_firma(p_datos#>>'{consulta,payload}',p_datos#>>'{consulta,firma}','ruc');
 if d->>'ruc' is distinct from r or d->>'estado' is distinct from 'ACTIVO' or d->>'condicion' is distinct from 'HABIDO' or length(trim(coalesce(d->>'razon_social','')))=0 then raise exception 'El RUC debe existir, estar ACTIVO y HABIDO.';end if;
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
 return private.crear_prestamo(c.id,p_monto,p_meses,p_clave);
end$$;
create or replace function private.detalle_cobranza(p_busqueda text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;r jsonb;k text;begin
 a:=private.asesor();k:=lower(regexp_replace(trim(p_busqueda),'^PR-','','i'));
 if p_busqueda!~'^[0-9]{8}$' and not private.validar_ruc(p_busqueda) and k!~'^[a-f0-9]{8}$' and k!~'^[a-f0-9]{8}-[a-f0-9-]{27,28}$' then raise exception 'Ingrese DNI exacto o código de préstamo.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'cliente_id',p.cliente_id,'monto',p.monto,'plazo_meses',p.plazo_meses,'conciliado',p.conciliado,
 'fecha_prestamo',p.fecha_prestamo,'agencia_origen',g.nombre,'nombre',c.nombres||' '||c.apellidos,'dni',c.dni,'ruc',c.ruc,'tasa_moratoria_anual',p.tasa_moratoria_anual,'base_mora',p.base_mora,'fecha_cotizacion',public.fecha_peru(),
 'cuotas',(select coalesce(jsonb_agg(to_jsonb(q)||jsonb_build_object('pagada',pc.cuota_id is not null,'pago_id',pc.pago_id,'interes_moratorio',case when pc.cuota_id is not null then pc.interes_moratorio else private.mora_cuota(q.id) end) order by q.numero_cuota),'[]') from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id),
 'pagos',(select coalesce(jsonb_agg(jsonb_build_object('id',pa.id,'importe',pa.importe,'created_at',pa.created_at,'agencia',ga.nombre,'asesor',ad.nombre_completo,'puede_ver_constancia',(p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id)) order by pa.created_at desc),'[]') from public.pagos pa join public.agencias ga on ga.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id where pa.prestamo_id=p.id))), '[]') into r
 from public.prestamos p join public.clientes c on c.id=p.cliente_id join public.agencias g on g.id=p.agencia_id
 where p.estado='confirmado' and (case when p_busqueda~'^[0-9]{8}$' then c.dni=p_busqueda when private.validar_ruc(p_busqueda) then c.ruc=p_busqueda else left(p.id::text,8)=k or p.id::text=k end);
 return r;end$$;

revoke all on function private.permisos_actuales(),public.permisos_operacion(),private.configurar_mora(numeric,integer,text),public.configurar_mora(numeric,integer,text),private.rehabilitar_cliente(uuid,text),public.rehabilitar_cliente(uuid,text) from public,anon;
grant execute on function private.permisos_actuales(),public.permisos_operacion(),private.configurar_mora(numeric,integer,text),public.configurar_mora(numeric,integer,text),private.rehabilitar_cliente(uuid,text),public.rehabilitar_cliente(uuid,text) to authenticated;
revoke all on function private.fijar_mora_prestamo(),private.persona_ruc(jsonb) from public,anon,authenticated;
notify pgrst,'reload schema';

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
 if nullif(current_setting('app.cobro_total',true),'') is not null and (importe::numeric<>nullif(current_setting('app.cobro_total',true),'')::numeric or public.fecha_peru()::text<>current_setting('app.cobro_fecha',true)) then raise exception 'El importe o la fecha cambió. Consulte nuevamente las cuotas.';end if;
 if p.tasa_moratoria_anual is not null and nullif(current_setting('app.cobro_total',true),'') is null then raise exception 'Actualice la consulta para confirmar el importe de mora.';end if;
 perform private.actualizar_cliente(p.cliente_id);
 insert into public.pagos(prestamo_id,agencia_id,asesor_id,importe,clave_operacion,cantidad_cuotas) values(p.id,a.agencia_id,a.id,importe,p_clave,p_cantidad) returning id into p_id;
 insert into public.pagos_cuotas(cuota_id,pago_id,importe,interes_moratorio) select id,p_id,cuota_total+private.mora_cuota(id),private.mora_cuota(id) from public.cuotas where id=any(ids);
 perform private.actualizar_cliente(p.cliente_id);return p_id;end$$;

-- Confirmación de las condiciones mostradas, incluida la configuración de mora.
create function private.confirmar_prestamo_cotizado(p_tipo text,p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid,p_tasa numeric,p_base integer) returns uuid language plpgsql security definer set search_path='' as $$
begin
 perform private.asesor();perform pg_advisory_xact_lock(781563::bigint);
 if not exists(select 1 from public.prestamos where clave_operacion=p_clave) and (p_tasa is distinct from private.parametro('tasa_moratoria_anual') or p_base is distinct from coalesce(private.parametro('base_mora'),360)::integer) then raise exception 'Las condiciones de mora cambiaron. Actualice la página y revise el préstamo antes de confirmar.';end if;
 if p_tipo='ruc' then return private.confirmar_ruc_prestamo(p_datos,p_monto,p_meses,p_clave);
 elsif p_tipo='nuevo' then return private.confirmar_cliente_prestamo(p_datos->>'p_payload',p_datos->>'p_firma',p_datos->'p_evidencia',p_monto,p_meses,p_clave);
 elsif p_tipo='dni' then return private.crear_prestamo((p_datos->>'cliente_id')::uuid,p_monto,p_meses,p_clave);
 else raise exception 'Tipo de solicitud inválido.';end if;
end$$;
create function public.confirmar_prestamo_cotizado(p_tipo text,p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid,p_tasa numeric,p_base integer) returns uuid language sql security invoker set search_path='' as $$select private.confirmar_prestamo_cotizado(p_tipo,p_datos,p_monto,p_meses,p_clave,p_tasa,p_base)$$;
revoke all on function private.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid,numeric,integer),public.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid,numeric,integer) from public,anon;
grant execute on function private.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid,numeric,integer),public.confirmar_prestamo_cotizado(text,jsonb,numeric,integer,uuid,numeric,integer) to authenticated;
notify pgrst,'reload schema';
