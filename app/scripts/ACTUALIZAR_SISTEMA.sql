-- Copia TODO este contenido al SQL Editor de tu proyecto y pulsa Run.
-- Incluye los ajustes anteriores y las fichas compartidas; se puede volver a ejecutar.
begin;

-- habilitar_modalidad_personal.sql
-- Aplicar una vez en SQL Editor sobre la versión que ya incluye RUC, contrato y mora.
-- No borra datos ni altera importes o contratos de préstamos anteriores.
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

-- revalidacion_y_pagos_globales.sql
-- Aplicar después de habilitar_modalidad_personal.sql. Conserva cartera y permisos por agencia.
create or replace function private.detalle_cobranza(p_busqueda text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;r jsonb;k text;begin
 a:=private.asesor();k:=lower(regexp_replace(trim(p_busqueda),'^PR-','','i'));
 if p_busqueda!~'^[0-9]{8}$' and not private.validar_ruc(p_busqueda) and k!~'^[a-f0-9]{8}$' and k!~'^[a-f0-9]{8}-[a-f0-9-]{27,28}$' then raise exception 'Ingrese DNI exacto o código de préstamo.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'cliente_id',p.cliente_id,'monto',p.monto,'plazo_meses',p.plazo_meses,'conciliado',p.conciliado,
 'fecha_prestamo',p.fecha_prestamo,'agencia_origen',g.nombre,'nombre',case when c.tipo_cliente='juridica' then coalesce(c.razon_social,c.nombres) else c.nombres||' '||c.apellidos end,'dni',c.dni,'ruc',c.ruc,'tipo_cliente',c.tipo_cliente,'tasa_moratoria_anual',p.tasa_moratoria_anual,'base_mora',p.base_mora,'fecha_cotizacion',public.fecha_peru(),
 'cuotas',(select coalesce(jsonb_agg(to_jsonb(q)||jsonb_build_object('pagada',pc.cuota_id is not null,'pago_id',pc.pago_id,'interes_moratorio',case when pc.cuota_id is not null then pc.interes_moratorio else private.mora_cuota(q.id) end) order by q.numero_cuota),'[]') from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id),
 'pagos',(select coalesce(jsonb_agg(jsonb_build_object('id',pa.id,'importe',pa.importe,'created_at',pa.created_at,'agencia',ga.nombre,'asesor',ad.nombre_completo,'puede_ver_constancia',(p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id)) order by pa.created_at desc),'[]') from public.pagos pa join public.agencias ga on ga.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id where pa.prestamo_id=p.id))), '[]') into r
 from public.prestamos p join public.clientes c on c.id=p.cliente_id join public.agencias g on g.id=p.agencia_id
 where p.estado='confirmado' and (case when p_busqueda~'^[0-9]{8}$' then exists(select 1 from public.clientes titular where titular.tipo_cliente='natural' and titular.dni=p_busqueda and (c.id=titular.id or c.propietario_id=titular.id)) when private.validar_ruc(p_busqueda) then c.ruc=p_busqueda or (left(p_busqueda,2)='10' and exists(select 1 from public.clientes titular where titular.tipo_cliente='natural' and titular.ruc=p_busqueda and c.propietario_id=titular.id)) else left(p.id::text,8)=k or p.id::text=k end);
 return r;end$$;

-- Guardar una consulta SUNAT de una ficha existente sin crear préstamos ni revalidar identidad.
create or replace function private.revalidar_datos_ruc(p_cliente uuid,p_payload text,p_firma text) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;d jsonb;c public.clientes;o uuid;rep uuid;fecha timestamptz;
begin
 a:=private.asesor();
 if not private.cliente_visible(p_cliente) then raise exception 'Cliente fuera de su agencia.' using errcode='42501';end if;
 d:=private.comprobar_firma(p_payload,p_firma,'ruc');
 if not private.validar_ruc(d->>'ruc') or nullif(trim(d->>'razon_social'),'') is null or nullif(trim(d->>'estado'),'') is null or nullif(trim(d->>'condicion'),'') is null then raise exception 'Consulta de RUC incompleta.';end if;
 fecha:=(d->>'consultadoEn')::timestamptz;
 perform pg_advisory_xact_lock(hashtextextended(d->>'ruc',6));
 select * into c from public.clientes where id=p_cliente for update;
 if c.id is null or c.ruc is distinct from d->>'ruc' then raise exception 'La consulta no corresponde al RUC de esta ficha.';end if;
 if c.ruc_consultado_at>fecha then raise exception 'Hay una consulta más reciente. Vuelve a consultar el RUC.';end if;
 if exists(select 1 from public.verificaciones_ruc where cliente_id=c.id and asesor_id=a.id and consultado_at=fecha) then return c.id;end if;
 o:=coalesce(c.propietario_id,c.id);rep:=coalesce(c.representante_id,c.id);
 update public.clientes set razon_social=d->>'razon_social',estado_ruc=d->>'estado',condicion_ruc=d->>'condicion',direccion_fiscal=d->>'direccion',ruc_consultado_at=fecha where id=c.id;
 insert into public.verificaciones_ruc(cliente_id,ruc,razon_social,estado,condicion,direccion,propietario_id,representante_id,evidencia_propiedad,evidencia_poder,asesor_id,consultado_at)
 values(c.id,c.ruc,d->>'razon_social',d->>'estado',d->>'condicion',d->>'direccion',o,rep,'Consulta de datos SUNAT; no revalida propiedad ni designación.','Consulta de datos SUNAT; no revalida facultades ni presencia del representante.',a.id,fecha);
 return c.id;
end$$;
create or replace function public.revalidar_datos_ruc(p_cliente uuid,p_payload text,p_firma text) returns uuid
language sql security invoker set search_path='' as $$select private.revalidar_datos_ruc(p_cliente,p_payload,p_firma)$$;
revoke all on function private.revalidar_datos_ruc(uuid,text,text),public.revalidar_datos_ruc(uuid,text,text) from public,anon;
grant execute on function private.revalidar_datos_ruc(uuid,text,text),public.revalidar_datos_ruc(uuid,text,text) to authenticated;

-- fichas_compartidas_y_grupo_pago.sql
-- Aplicar después de habilitar_modalidad_personal.sql y revalidacion_y_pagos_globales.sql.
-- Comparte identidad y vínculos de grupos atendidos; no amplía la cartera de préstamos.
create or replace function private.cliente_visible(p_cliente uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare agencia uuid;grupo uuid;
begin
 agencia:=private.agencia();
 select coalesce(c.propietario_id,c.id) into grupo from public.clientes c where c.id=p_cliente;
 if grupo is null then return false;end if;
 return exists(select 1 from public.clientes miembro where coalesce(miembro.propietario_id,miembro.id)=grupo
  and (miembro.agencia_registro_id=agencia or exists(select 1 from public.prestamos p where p.cliente_id=miembro.id and p.agencia_id=agencia and p.estado='confirmado')));
end$$;
create or replace function private.relaciones_cliente(p_cliente uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare resultado jsonb;grupo uuid;
begin
 perform private.asesor();if not private.cliente_visible(p_cliente) then raise exception 'Cliente fuera de su agencia.' using errcode='42501';end if;
 select coalesce(propietario_id,id) into grupo from public.clientes where id=p_cliente;
 select jsonb_build_object(
 'propietario',jsonb_build_object('id',o.id,'dni',o.dni,'nombre',o.nombres||' '||o.apellidos,'puede_ver',private.cliente_visible(o.id)),
 'representante',case when r.id is not null then jsonb_build_object('id',r.id,'dni',r.dni,'nombre',r.nombres||' '||r.apellidos,'puede_ver',private.cliente_visible(r.id)) else null end,
 'miembros',(select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'dni',m.dni,'ruc',m.ruc,'tipo_cliente',m.tipo_cliente,'nombre',case when m.tipo_cliente='juridica' then coalesce(m.razon_social,m.nombres) else m.nombres||' '||m.apellidos end,'puede_ver',private.cliente_visible(m.id)) order by m.tipo_cliente desc,m.created_at,m.id),'[]') from public.clientes m where coalesce(m.propietario_id,m.id)=grupo)) into resultado
 from public.clientes c join public.clientes o on o.id=grupo left join public.clientes r on r.id=c.representante_id where c.id=p_cliente;
 return resultado;
end$$;

create or replace function private.detalle_cobranza(p_busqueda text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;r jsonb;k text;begin
 a:=private.asesor();k:=lower(regexp_replace(trim(p_busqueda),'^PR-','','i'));
 if p_busqueda!~'^[0-9]{8}$' and not private.validar_ruc(p_busqueda) and k!~'^[a-f0-9]{8}$' and k!~'^[a-f0-9]{8}-[a-f0-9-]{27,28}$' then raise exception 'Ingrese DNI exacto o código de préstamo.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'cliente_id',p.cliente_id,'monto',p.monto,'plazo_meses',p.plazo_meses,'conciliado',p.conciliado,
 'fecha_prestamo',p.fecha_prestamo,'agencia_origen',g.nombre,'nombre',case when c.tipo_cliente='juridica' then coalesce(c.razon_social,c.nombres) else c.nombres||' '||c.apellidos end,'dni',c.dni,'ruc',c.ruc,'tipo_cliente',c.tipo_cliente,'tasa_moratoria_anual',p.tasa_moratoria_anual,'base_mora',p.base_mora,'fecha_cotizacion',public.fecha_peru(),
 'cuotas',(select coalesce(jsonb_agg(to_jsonb(q)||jsonb_build_object('pagada',pc.cuota_id is not null,'pago_id',pc.pago_id,'interes_moratorio',case when pc.cuota_id is not null then pc.interes_moratorio else private.mora_cuota(q.id) end) order by q.numero_cuota),'[]') from public.cuotas q left join public.pagos_cuotas pc on pc.cuota_id=q.id where q.prestamo_id=p.id),
 'pagos',(select coalesce(jsonb_agg(jsonb_build_object('id',pa.id,'importe',pa.importe,'created_at',pa.created_at,'agencia',ga.nombre,'asesor',ad.nombre_completo,'puede_ver_constancia',(p.agencia_id=a.agencia_id or pa.agencia_id=a.agencia_id)) order by pa.created_at desc),'[]') from public.pagos pa join public.agencias ga on ga.id=pa.agencia_id join public.asesores ad on ad.id=pa.asesor_id where pa.prestamo_id=p.id))), '[]') into r
 from public.prestamos p join public.clientes c on c.id=p.cliente_id join public.agencias g on g.id=p.agencia_id
 where p.estado='confirmado' and (case when p_busqueda~'^[0-9]{8}$' then coalesce(c.propietario_id,c.id)=(select t.id from public.clientes t where t.tipo_cliente='natural' and t.dni=p_busqueda) when private.validar_ruc(p_busqueda) then coalesce(c.propietario_id,c.id)=(select coalesce(t.propietario_id,t.id) from public.clientes t where t.ruc=p_busqueda) else left(p.id::text,8)=k or p.id::text=k end);
 return r;end$$;


-- Se conservan los permisos de las funciones sustituidas y las políticas de préstamos.
notify pgrst, 'reload schema';
commit;
