-- Aplicar después de habilitar_modalidad_personal.sql y revalidacion_y_pagos_globales.sql.
-- Comparte identidad y vínculos de grupos atendidos; no amplía la cartera de préstamos.
begin;
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
