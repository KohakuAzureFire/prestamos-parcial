-- Aplicar después de habilitar_modalidad_personal.sql. Conserva cartera y permisos por agencia.
begin;
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
commit;
