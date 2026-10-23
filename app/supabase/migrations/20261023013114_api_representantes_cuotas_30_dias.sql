-- Solo nuevas operaciones. Conserva cuotas, pagos y contratos confirmados.
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
 if exists(select 1 from public.clientes where id=p_cliente and tipo_cliente='juridica') then
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
 end loop;return p_id;end$function$;

create or replace function private.enviar_solicitud(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid,p_payload text,p_firma text,p_id uuid default null,p_version integer default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;r public.representaciones_empresa;c public.clientes;rep uuid;cid uuid;doc jsonb;st jsonb;e jsonb;rid uuid;o public.clientes;pendiente boolean;dueno jsonb;estado_nuevo text;api jsonb;seleccion jsonb;indice integer;d jsonb;begin
 a:=private.asesor();
 perform pg_advisory_xact_lock(hashtextextended(p_datos#>>'{consulta,ruc}',6));
 select * into s from public.solicitudes_prestamo where clave_envio=p_clave;
 if s.id is not null then
  if s.agencia_id<>a.agencia_id or s.ruc is distinct from p_datos#>>'{consulta,ruc}' or s.monto is distinct from p_monto or s.plazo_meses is distinct from p_meses then raise exception 'La clave pertenece a otra solicitud.';end if;return s.id;
 end if;
 if p_clave is null or p_datos#>>'{consulta,ruc}' not like '20%' or p_monto is null or p_monto<=0 or p_monto<>round(p_monto,2) or p_monto>private.parametro('capital_maximo') or p_meses is null or p_meses not between 1 and 60 then raise exception 'Revise RUC 20, monto y plazo.';end if;
 if p_id is not null then
  select * into s from public.solicitudes_prestamo where id=p_id for update;
  if s.id is null or s.agencia_id<>a.agencia_id or s.ruc is distinct from p_datos#>>'{consulta,ruc}' then raise exception 'Solicitud no disponible.';end if;
  if s.expediente#>>'{propietario,dni}' is distinct from p_datos#>>'{propietario,dni}' then raise exception 'Conserve el propietario de la solicitud.';end if;
  if s.estado<>'observada' or s.version is distinct from p_version then raise exception 'Solo se corrige una solicitud observada en su versión actual.';end if;
 elsif exists(select 1 from public.solicitudes_prestamo where ruc=p_datos#>>'{consulta,ruc}' and estado in ('pendiente','pendiente_identidad','observada')) then raise exception 'Ya existe una solicitud pendiente u observada para este RUC. Abra esa solicitud.';
 end if;
 doc:=(p_datos->>'evidencia_propiedad')::jsonb;
 if doc->>'tipo' is null or doc->>'tipo' not in ('partida','constitucion','acto','matricula') or length(trim(coalesce(doc->>'ref','')))=0 or length(doc->>'ref')>240 or doc->>'dni' is distinct from p_datos#>>'{propietario,dni}' then raise exception 'Seleccione un documento admitido y su referencia.';end if;
 if doc->>'presente' is null or doc->>'presente' not in ('true','false') then raise exception 'Confirme la presencia del propietario.';end if;
 if doc->>'presente'='false' and (p_datos#>>'{propietario,dni}'=p_datos#>>'{representante,dni}' or p_datos#>'{propietario,borrador}' is not null) then raise exception 'El propietario ausente requiere identidad previa vigente y otro firmante presencial.';end if;
 r:=jsonb_populate_record(null::public.representaciones_empresa,private.finalizar_representacion(p_payload,p_firma));
 if r.agencia_id<>a.agencia_id or r.ruc is distinct from p_datos#>>'{consulta,ruc}' or r.propietario_dni is distinct from p_datos#>>'{propietario,dni}' or r.representante_dni is distinct from p_datos#>>'{representante,dni}' or exists(select 1 from public.solicitudes_prestamo where representacion_id=r.id) then raise exception 'Certificado no corresponde al expediente o ya fue presentado.';end if;
 select * into o from public.clientes where dni=p_datos#>>'{propietario,dni}' and tipo_cliente='natural';
 pendiente:=doc->>'presente'='false' and (o.id is null or (private.situacion_individual(o.id)->>'verificacion') is distinct from 'aprobada');
 if pendiente then
  if p_datos#>>'{propietario,dni}' is null or p_datos#>>'{propietario,dni}' !~ '^[0-9]{8}$' then raise exception 'DNI del propietario inválido.';end if;
  d:=private.comprobar_firma(p_datos#>>'{consulta,payload}',p_datos#>>'{consulta,firma}','ruc');
  if d->>'ruc' is distinct from r.ruc or d->>'estado' is distinct from 'ACTIVO' or d->>'condicion' is distinct from 'HABIDO' then raise exception 'El RUC debe estar ACTIVO y HABIDO.';end if;
  if (p_datos->>'propiedad_confirmada')::boolean is distinct from true then raise exception 'Revise la documentación del propietario.';end if;
  perform pg_advisory_xact_lock(hashtextextended(least(p_datos#>>'{propietario,dni}',p_datos#>>'{representante,dni}'),0));
  perform pg_advisory_xact_lock(hashtextextended(greatest(p_datos#>>'{propietario,dni}',p_datos#>>'{representante,dni}'),0));
  select * into c from public.clientes where ruc=r.ruc for update;
  if c.id is not null and (select dni from public.clientes where id=c.propietario_id) is distinct from p_datos#>>'{propietario,dni}' then raise exception 'La empresa está vinculada a otro propietario.';end if;
  rep:=private.persona_ruc(p_datos->'representante');
  -- Una declaración de DNI no crea cliente, verificación ni vínculo empresarial.
  dueno:=jsonb_build_object('dni',p_datos#>>'{propietario,dni}','nombres',coalesce(o.nombres,'Identidad por verificar'),'apellidos',coalesce(o.apellidos,''),'verificacion_pendiente',true);
  estado_nuevo:='pendiente_identidad';
 else
  cid:=private.preparar_empresa_solicitud(p_datos,p_clave);select * into c from public.clientes where id=cid;
  rep:=private.persona_ruc(p_datos->'representante');
  perform pg_advisory_xact_lock(hashtextextended(c.propietario_id::text,4));
  st:=private.situacion(c.id);
  if (st->>'elegible')::boolean is distinct from true or (st->>'capital_disponible')::numeric<p_monto then raise exception 'Revise identidad, atrasos, conciliación y capital disponible global.';end if;
  select * into o from public.clientes where id=c.propietario_id;
  dueno:=jsonb_build_object('dni',o.dni,'nombres',o.nombres,'apellidos',o.apellidos,'verificacion_pendiente',false);
  estado_nuevo:='pendiente';
 end if;
 if p_datos->'consulta_representantes' is not null and p_datos->'consulta_representantes'<>'null'::jsonb then
  api:=private.comprobar_firma(p_datos#>>'{consulta_representantes,payload}',p_datos#>>'{consulta_representantes,firma}','representantes');
  if api->>'ruc' is distinct from r.ruc or api->>'proveedor' is distinct from 'apiperu.pe' then raise exception 'La consulta de representantes corresponde a otra empresa.';end if;
  indice:=(p_datos#>>'{consulta_representantes,indice}')::integer;
  if indice is null or indice<0 or indice>=jsonb_array_length(api->'representantes') then raise exception 'Selecciona un representante de la consulta.';end if;
  seleccion:=api->'representantes'->indice;
  if (seleccion->>'dni_completo')::boolean and seleccion->>'documento' is distinct from p_datos#>>'{representante,dni}' then raise exception 'El DNI del firmante no coincide con el representante seleccionado.';end if;
 end if;
 e:=jsonb_build_object('periodicidad','30_dias','razon_social',r.razon_social,'propietario',dueno,'representante',(select jsonb_build_object('dni',dni,'nombres',nombres,'apellidos',apellidos) from public.clientes where id=rep),'evidencia_propiedad',p_datos->>'evidencia_propiedad','certificado',jsonb_build_object('id',r.id,'sha256',r.archivo_sha256,'emision',r.fecha_emision),'monto',p_monto,'meses',p_meses,'fecha_simulacion',public.fecha_peru());
 if seleccion is not null then e:=e||jsonb_build_object('consulta_representantes',jsonb_build_object('proveedor','apiperu.pe','consultadoEn',api->>'consultadoEn','representante',seleccion));end if;
 if p_id is null then
  insert into public.solicitudes_prestamo(clave_envio,ruc,cliente_id,propietario_id,representante_id,representacion_id,asesor_id,agencia_id,monto,plazo_meses,expediente,estado)
  values(p_clave,r.ruc,c.id,o.id,rep,r.id,a.id,a.agencia_id,p_monto,p_meses,e,estado_nuevo) returning id into rid;
 else
  update public.solicitudes_prestamo set clave_envio=p_clave,cliente_id=c.id,propietario_id=o.id,representante_id=rep,representacion_id=r.id,monto=p_monto,plazo_meses=p_meses,expediente=e,estado=estado_nuevo,motivo=null,evaluador_id=null,version=version+1,updated_at=now() where id=p_id returning id into rid;
 end if;
 insert into public.historial_solicitudes(solicitud_id,asesor_id,estado,detalle,expediente) values(rid,a.id,estado_nuevo,case when p_id is null then 'Solicitud enviada al finalizar Nuevo préstamo.' else 'Solicitud corregida y reenviada.' end,e);
 return rid;
end$$;
