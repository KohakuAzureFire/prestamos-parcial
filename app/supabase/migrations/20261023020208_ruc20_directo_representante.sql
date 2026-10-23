-- El responsable queda fijado por préstamo; no se traslada deuda al cambiar representante.
alter table public.clientes add column origen_empresa_api boolean not null default false;
alter table public.prestamos add column responsable_id uuid references public.clientes(id);
create index prestamos_responsable_idx on public.prestamos(responsable_id);
alter table public.clientes drop constraint identidad_tipo;
alter table public.clientes add constraint identidad_tipo check(
 (tipo_cliente='natural' and dni is not null and propietario_id is null and not origen_empresa_api and (ruc is null or (ruc like '10%' and substring(ruc,3,8)=dni))) or
 (tipo_cliente='juridica' and dni is null and ruc like '20%' and representante_id is not null and (origen_empresa_api or propietario_id is not null)));


CREATE OR REPLACE FUNCTION private.grupo(p_cliente uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$select case when origen_empresa_api then representante_id else coalesce(propietario_id,id) end from public.clientes where id=p_cliente$function$;


CREATE OR REPLACE FUNCTION private.situacion(p_cliente uuid, p_hoy date DEFAULT fecha_peru())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c public.clientes;g uuid;s jsonb;capital numeric;deuda numeric;ven date;conc boolean;cond text;ver text;inc date;aut timestamptz;bloq boolean;begin
 perform private.asesor();select * into c from public.clientes where id=p_cliente;if c.id is null then raise exception 'Cliente no encontrado.';end if;
 g:=private.grupo(c.id);
 select coalesce(sum(q.amortizacion) filter(where pc.cuota_id is null),0),coalesce(sum(q.cuota_total) filter(where pc.cuota_id is null),0),min(q.fecha_vencimiento) filter(where pc.cuota_id is null and q.cuota_total>0 and q.fecha_vencimiento<p_hoy),coalesce(bool_and(p.conciliado),true)
 into capital,deuda,ven,conc from public.clientes gc join public.prestamos p on p.cliente_id=gc.id and p.estado='confirmado' join public.cuotas q on q.prestamo_id=p.id left join public.pagos_cuotas pc on pc.cuota_id=q.id where coalesce(p.responsable_id,gc.propietario_id,gc.id)=g;
 cond:=case when ven is null then 'habilitado' when (ven+interval '12 months')::date<=p_hoy then 'extrajudicial' else 'atrasado' end;
 select max((q.fecha_vencimiento+interval '12 months')::date) into inc
 from public.clientes gc join public.prestamos p on p.cliente_id=gc.id and p.estado='confirmado' join public.cuotas q on q.prestamo_id=p.id left join public.pagos_cuotas pc on pc.cuota_id=q.id left join public.pagos pa on pa.id=pc.pago_id
 where coalesce(p.responsable_id,gc.propietario_id,gc.id)=g and q.cuota_total>0 and (q.fecha_vencimiento+interval '12 months')::date<=p_hoy
 and (pa.id is null or (pa.created_at at time zone 'America/Lima')::date>=(q.fecha_vencimiento+interval '12 months')::date);
 select max(created_at) into aut from private.rehabilitaciones where propietario_id=g;
 bloq:=inc is not null and (aut is null or (aut at time zone 'America/Lima')::date<inc);
 if c.tipo_cliente='natural' then s:=private.situacion_individual(c.id,p_hoy);ver:=s->>'verificacion';
 else
 s:=private.situacion_individual(g,p_hoy);ver:=s->>'verificacion';
 if (private.situacion_individual(c.representante_id,p_hoy)->>'verificacion')<>'aprobada' then ver:='pendiente';end if;
 end if;
 if c.tipo_cliente='juridica' and c.ruc is not null and (c.estado_ruc is distinct from 'ACTIVO' or c.condicion_ruc is distinct from 'HABIDO') then ver:='rechazada';end if;
 return jsonb_build_object('capital_pendiente',capital,'capital_disponible',greatest(0,private.parametro('capital_maximo')-capital),'limite',private.parametro('capital_maximo'),'deuda_pendiente',deuda,'atraso_desde',ven,'condicion_pago',case when conc then cond else 'por_conciliar' end,'conciliado',conc,'verificacion',ver,'antecedente_extrajudicial',inc,'requiere_autorizacion',bloq,'propietario_id',g,'elegible',conc and cond='habilitado' and ver='aprobada' and not bloq);
end$function$;


CREATE OR REPLACE FUNCTION private.crear_prestamo(p_cliente uuid, p_monto numeric, p_meses integer, p_clave uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 if exists(select 1 from public.clientes where id=p_cliente and tipo_cliente='juridica') and current_setting('app.empresa_api_validada',true) is distinct from p_cliente::text then
  perform private.exigir_representacion(nullif(current_setting('app.representacion_id',true),'')::uuid,(select ruc from public.clientes where id=p_cliente),(select o.dni from public.clientes c join public.clientes o on o.id=c.propietario_id where c.id=p_cliente),(select r.dni from public.clientes c join public.clientes r on r.id=c.representante_id where c.id=p_cliente),p_monto);
 end if;
 insert into public.prestamos(cliente_id,agencia_id,asesor_id,fecha_prestamo,monto,plazo_meses,tea,estado,confirmado_at,conciliado,clave_operacion,identidad_contrato)
 values(p_cliente,a.agencia_id,a.id,fecha,p_monto,p_meses,0.30,'confirmado',now(),true,p_clave,(select to_jsonb(c)||jsonb_build_object('periodicidad','30_dias','propietario',(select jsonb_build_object('dni',o.dni,'nombre',o.nombres||' '||o.apellidos) from public.clientes o where o.id=coalesce(c.propietario_id,c.id)),'representante',(select jsonb_build_object('dni',r.dni,'nombre',r.nombres||' '||r.apellidos) from public.clientes r where r.id=c.representante_id)) from public.clientes c where c.id=p_cliente)) returning id into p_id;
 cuota:=round(p_monto*tem/(1-power(1+tem,-p_meses)),2);saldo:=p_monto;
 for k in 1..p_meses loop
 interes:=round(saldo*tem,2);capital:=case when k=p_meses then saldo else round(cuota-interes,2) end;
 if k=p_meses then cuota:=capital+interes;end if;saldo:=round(saldo-capital,2);
 insert into public.cuotas(prestamo_id,numero_cuota,fecha_vencimiento,cuota_total,interes,amortizacion,saldo)
 values(p_id,k,fecha+30*k,cuota,interes,capital,saldo);
 end loop;
 if current_setting('app.empresa_api_validada',true)=p_cliente::text then update public.prestamos set responsable_id=(select representante_id from public.clientes where id=p_cliente),identidad_contrato=identidad_contrato||jsonb_build_object('modalidad','ruc','origen','empresa_api','propietario',null) where id=p_id;end if;
 return p_id;end$function$;


CREATE OR REPLACE FUNCTION private.cliente_visible(p_cliente uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare agencia uuid;grupo uuid;
begin
 agencia:=private.agencia();
 select coalesce(c.propietario_id,c.id) into grupo from public.clientes c where c.id=p_cliente;
 if grupo is null then return false;end if;
 return exists(select 1 from public.prestamos p where p.estado='confirmado' and p.agencia_id=agencia and (p.cliente_id=p_cliente or p.responsable_id=p_cliente)) or exists(select 1 from public.clientes miembro where coalesce(miembro.propietario_id,miembro.id)=grupo
  and (miembro.agencia_registro_id=agencia or exists(select 1 from public.prestamos p where p.cliente_id=miembro.id and p.agencia_id=agencia and p.estado='confirmado')));
end$function$;


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
 where p.estado='confirmado' and (case when p_busqueda~'^[0-9]{8}$' then coalesce(p.responsable_id,c.propietario_id,c.id)=(select t.id from public.clientes t where t.tipo_cliente='natural' and t.dni=p_busqueda) when private.validar_ruc(p_busqueda) then case when exists(select 1 from public.clientes t where t.ruc=p_busqueda and t.origen_empresa_api) then c.ruc=p_busqueda else coalesce(p.responsable_id,c.propietario_id,c.id)=(select coalesce(t.propietario_id,t.id) from public.clientes t where t.ruc=p_busqueda) end else left(p.id::text,8)=k or p.id::text=k end);
 return r;end$function$;


CREATE OR REPLACE FUNCTION private.relaciones_cliente(p_cliente uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare resultado jsonb;grupo uuid;
begin
 perform private.asesor();if not private.cliente_visible(p_cliente) then raise exception 'Cliente fuera de su agencia.' using errcode='42501';end if;
 grupo:=private.grupo(p_cliente);
 select jsonb_build_object(
 'origen_empresa_api',c.origen_empresa_api,'propietario',case when c.origen_empresa_api then null else jsonb_build_object('id',o.id,'dni',o.dni,'nombre',o.nombres||' '||o.apellidos,'puede_ver',private.cliente_visible(o.id)) end,
 'representante',case when r.id is not null then jsonb_build_object('id',r.id,'dni',r.dni,'nombre',r.nombres||' '||r.apellidos,'puede_ver',private.cliente_visible(r.id)) else null end,
 'miembros',(select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'dni',m.dni,'ruc',m.ruc,'tipo_cliente',m.tipo_cliente,'nombre',case when m.tipo_cliente='juridica' then coalesce(m.razon_social,m.nombres) else m.nombres||' '||m.apellidos end,'puede_ver',private.cliente_visible(m.id)) order by m.tipo_cliente desc,m.created_at,m.id),'[]') from public.clientes m where m.id=grupo or (not m.origen_empresa_api and coalesce(m.propietario_id,m.id)=grupo) or exists(select 1 from public.prestamos p where p.cliente_id=m.id and p.responsable_id=grupo))) into resultado
 from public.clientes c join public.clientes o on o.id=grupo left join public.clientes r on r.id=c.representante_id where c.id=p_cliente;
 return resultado;
end$function$;


CREATE OR REPLACE FUNCTION private.autorizar_nuevos_prestamos(p_cliente uuid, p_motivo text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare g uuid;r uuid;begin
 if length(trim(coalesce(p_motivo,'')))<10 then raise exception 'Documente la evaluación de crédito.';end if;
 g:=private.grupo(p_cliente);if g is null then raise exception 'Cliente inexistente.';end if;
 if exists(select 1 from public.clientes c join public.prestamos p on p.cliente_id=c.id join public.cuotas q on q.prestamo_id=p.id left join public.pagos_cuotas pc on pc.cuota_id=q.id where coalesce(p.responsable_id,c.propietario_id,c.id)=g and p.estado='confirmado' and q.fecha_vencimiento<public.fecha_peru() and q.cuota_total>0 and pc.cuota_id is null) then raise exception 'Primero regularice las cuotas vencidas.';end if;
 insert into private.rehabilitaciones(propietario_id,motivo) values(g,p_motivo) returning id into r;return r;end$function$;


create or replace view public.clientes_resumen with(security_invoker=true) as  SELECT id,
    dni,
    nombres,
    apellidos,
    condicion,
    fuente_verificacion,
    resultado_verificacion,
    fecha_verificacion,
    asesor_id,
    created_at,
    updated_at,
    verificacion_resultado,
    dni_caducidad,
    fallecimiento_acreditado,
    condicion_pago,
    atraso_desde,
    situacion_actualizada_at,
    agencia_registro_id,
    tipo_cliente,
    ruc,
    razon_social,
    estado_ruc,
    condicion_ruc,
    direccion_fiscal,
    ruc_consultado_at,
    propietario_id,
    representante_id,
    evidencia_propiedad,
    evidencia_poder,
    private.situacion(id) AS situacion, c.origen_empresa_api
   FROM clientes c;


create function private.confirmar_empresa_api(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a public.asesores;d jsonb;api jsonb;persona jsonb;rep uuid;c public.clientes;prev public.prestamos;pid uuid;r text;dni text;coincide jsonb;begin
 a:=private.asesor();perform pg_advisory_xact_lock(781563::bigint);
 r:=p_datos#>>'{consulta,ruc}';dni:=p_datos#>>'{representante,dni}';
 if p_clave is null or r is null or r not like '20%' or not private.validar_ruc(r) or dni is null or dni!~'^[0-9]{8}$' then raise exception 'RUC 20 o DNI del representante inválido.';end if;
 select * into prev from public.prestamos where clave_operacion=p_clave;
 if prev.id is not null then
  if prev.asesor_id=a.id and prev.monto=p_monto and prev.plazo_meses=p_meses and prev.identidad_contrato->>'origen'='empresa_api' and prev.identidad_contrato->>'ruc'=r and prev.identidad_contrato#>>'{representante,dni}'=dni then return prev.id;end if;
  raise exception 'La clave pertenece a otra operación.';
 end if;
 d:=private.comprobar_firma(p_datos#>>'{consulta,payload}',p_datos#>>'{consulta,firma}','ruc');
 if d->>'ruc' is distinct from r or d->>'estado' is distinct from 'ACTIVO' or d->>'condicion' is distinct from 'HABIDO' or length(trim(coalesce(d->>'razon_social','')))=0 then raise exception 'Se requiere RUC ACTIVO y HABIDO.';end if;
 api:=private.comprobar_firma(p_datos#>>'{consulta_representantes,payload}',p_datos#>>'{consulta_representantes,firma}','representantes');
 if api->>'ruc' is distinct from r or api->>'proveedor' is distinct from 'apiperu.pe' or jsonb_typeof(api->'representantes') is distinct from 'array' then raise exception 'Consulta de representantes no válida para esta empresa.';end if;
 select x into coincide from jsonb_array_elements(api->'representantes') x where x->>'tipo_documento'='DNI' and x->>'documento'=dni and x->>'documento'~'^[0-9]{8}$' limit 1;
 if coincide is null then raise exception 'El DNI completo no figura como representante de este RUC. Datos ocultos o un fallo de API no permiten validar.';end if;
 if (p_datos->>'firmante_presente')::boolean is distinct from true then raise exception 'Confirme DNI original y presencia del representante.';end if;
 perform pg_advisory_xact_lock(hashtextextended(r,6));
 rep:=private.persona_ruc(p_datos->'representante');perform pg_advisory_xact_lock(hashtextextended(rep::text,4));
 select * into c from public.clientes where ruc=r for update;
 if c.id is null then
  insert into public.clientes(dni,nombres,apellidos,tipo_cliente,ruc,representante_id,asesor_id,verificacion_resultado,origen_empresa_api)
  values(null,d->>'razon_social','','juridica',r,rep,a.id,'aprobada',true) returning * into c;
 end if;
 update public.clientes set origen_empresa_api=true,representante_id=rep,nombres=d->>'razon_social',razon_social=d->>'razon_social',estado_ruc=d->>'estado',condicion_ruc=d->>'condicion',direccion_fiscal=d->>'direccion',ruc_consultado_at=(d->>'consultadoEn')::timestamptz where id=c.id;
 perform set_config('app.ruc_validado',r,true);perform set_config('app.empresa_api_validada',c.id::text,true);
 pid:=private.crear_prestamo(c.id,p_monto,p_meses,p_clave);
 update public.prestamos set identidad_contrato=identidad_contrato||jsonb_build_object('consulta_representantes',jsonb_build_object('proveedor','apiperu.pe','fecha',api->>'consultadoEn','representante',coincide),'responsable_id',rep) where id=pid;
 perform set_config('app.empresa_api_validada','',true);
 return pid;
end$$;
create function public.confirmar_empresa_api(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid) returns uuid language sql security invoker set search_path='' as $$select private.confirmar_empresa_api(p_datos,p_monto,p_meses,p_clave)$$;
revoke all on function private.confirmar_empresa_api(jsonb,numeric,integer,uuid),public.confirmar_empresa_api(jsonb,numeric,integer,uuid) from public,anon;
grant execute on function private.confirmar_empresa_api(jsonb,numeric,integer,uuid),public.confirmar_empresa_api(jsonb,numeric,integer,uuid) to authenticated;
create or replace view public.prestamos_resumen with(security_invoker=true) as  SELECT id,
    cliente_id,
    agencia_id,
    asesor_id,
    fecha_prestamo,
    monto,
    plazo_meses,
    tea,
    estado,
    confirmado_at,
    created_at,
    conciliado,
    estado_deuda,
    clave_operacion,
    private.saldos_prestamo(id) AS saldos, p.responsable_id
   FROM prestamos p;


CREATE OR REPLACE FUNCTION private.enviar_solicitud(p_datos jsonb, p_monto numeric, p_meses integer, p_clave uuid, p_payload text, p_firma text, p_id uuid DEFAULT NULL::uuid, p_version integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$begin perform private.asesor();raise exception 'Use Nuevo préstamo con RUC 20 y valide al representante por API; ya no se registran solicitudes documentales.';end$function$;


CREATE OR REPLACE FUNCTION private.evaluar_solicitud(p_id uuid, p_version integer, p_estado text, p_motivo text, p_consulta jsonb DEFAULT NULL::jsonb, p_referencia text DEFAULT NULL::text, p_facultades boolean DEFAULT false, p_individual boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$begin perform private.asesor();raise exception 'Use Nuevo préstamo con RUC 20 y valide al representante por API; ya no se registran solicitudes documentales.';end$function$;

