-- Propietario ausente: expediente pendiente sin inventar una identidad verificada.
begin;
alter table public.solicitudes_prestamo alter column cliente_id drop not null,alter column propietario_id drop not null;
alter table public.solicitudes_prestamo drop constraint solicitudes_prestamo_estado_check;
alter table public.solicitudes_prestamo add constraint solicitudes_prestamo_estado_check check(estado in ('pendiente','pendiente_identidad','observada','rechazada','aprobada'));
alter table public.solicitudes_prestamo add constraint solicitud_identidad_completa check(
 (cliente_id is not null and propietario_id is not null) or
 (coalesce((expediente#>>'{propietario,verificacion_pendiente}')::boolean,false) and estado in ('pendiente_identidad','observada','rechazada')));
drop index public.solicitud_abierta_ruc;
create unique index solicitud_abierta_ruc on public.solicitudes_prestamo(ruc) where estado in ('pendiente','pendiente_identidad','observada');
create or replace function private.resolver_solicitud_ruc(p_ruc text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;begin a:=private.asesor();select * into s from public.solicitudes_prestamo where ruc=p_ruc and estado in ('pendiente','pendiente_identidad','observada');
 if s.id is null then return null;end if;return jsonb_build_object('id',case when s.agencia_id=a.agencia_id then s.id end,'estado',s.estado,'agencia',(select nombre from public.agencias where id=s.agencia_id));end$$;

create or replace function private.enviar_solicitud(p_datos jsonb,p_monto numeric,p_meses integer,p_clave uuid,p_payload text,p_firma text,p_id uuid default null,p_version integer default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;r public.representaciones_empresa;c public.clientes;rep uuid;cid uuid;doc jsonb;st jsonb;e jsonb;rid uuid;o public.clientes;pendiente boolean;dueno jsonb;estado_nuevo text;d jsonb;begin
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
 e:=jsonb_build_object('razon_social',r.razon_social,'propietario',dueno,'representante',(select jsonb_build_object('dni',dni,'nombres',nombres,'apellidos',apellidos) from public.clientes where id=rep),'evidencia_propiedad',p_datos->>'evidencia_propiedad','certificado',jsonb_build_object('id',r.id,'sha256',r.archivo_sha256,'emision',r.fecha_emision),'monto',p_monto,'meses',p_meses,'fecha_simulacion',public.fecha_peru());
 if p_id is null then
  insert into public.solicitudes_prestamo(clave_envio,ruc,cliente_id,propietario_id,representante_id,representacion_id,asesor_id,agencia_id,monto,plazo_meses,expediente,estado)
  values(p_clave,r.ruc,c.id,o.id,rep,r.id,a.id,a.agencia_id,p_monto,p_meses,e,estado_nuevo) returning id into rid;
 else
  update public.solicitudes_prestamo set clave_envio=p_clave,cliente_id=c.id,propietario_id=o.id,representante_id=rep,representacion_id=r.id,monto=p_monto,plazo_meses=p_meses,expediente=e,estado=estado_nuevo,motivo=null,evaluador_id=null,version=version+1,updated_at=now() where id=p_id returning id into rid;
 end if;
 insert into public.historial_solicitudes(solicitud_id,asesor_id,estado,detalle,expediente) values(rid,a.id,estado_nuevo,case when p_id is null then 'Solicitud enviada al finalizar Nuevo préstamo.' else 'Solicitud corregida y reenviada.' end,e);
 return rid;
end$$;
create or replace function private.evaluar_solicitud(p_id uuid,p_version integer,p_estado text,p_motivo text,p_consulta jsonb default null,p_referencia text default null,p_facultades boolean default false,p_individual boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;d jsonb;pid uuid;v_ruc text;begin
 a:=private.asesor();select ruc into v_ruc from public.solicitudes_prestamo where id=p_id and agencia_id=a.agencia_id;perform pg_advisory_xact_lock(hashtextextended(v_ruc,6));select * into s from public.solicitudes_prestamo where id=p_id and agencia_id=a.agencia_id for update;
 if s.id is null then raise exception 'Solicitud fuera de su agencia.' using errcode='42501';end if;
 if s.estado='aprobada' and p_estado='aprobada' then return s.prestamo_id;end if;
 if coalesce((s.expediente#>>'{propietario,verificacion_pendiente}')::boolean,false) and p_estado='aprobada' then raise exception 'Complete la verificación presencial del propietario antes de aprobar.';end if;
 if s.estado not in ('pendiente','pendiente_identidad') or s.version is distinct from p_version then raise exception 'La solicitud cambió o ya fue evaluada. Actualice.';end if;
 if p_estado is null or p_estado not in ('aprobada','observada','rechazada') or length(trim(coalesce(p_motivo,'')))<10 or length(p_motivo)>1000 then raise exception 'Seleccione el resultado y registre el sustento (10 a 1000 caracteres).';end if;
 if p_estado='aprobada' then
  if p_facultades is distinct from true or p_individual is distinct from true or length(trim(coalesce(p_referencia,'')))<8 or length(p_referencia)>500 then raise exception 'Compruebe autenticidad, facultades y firma individual, con referencia de validación.';end if;
  d:=private.comprobar_firma(p_consulta->>'payload',p_consulta->>'firma','ruc');
  if d->>'ruc' is distinct from s.ruc or d->>'estado' is distinct from 'ACTIVO' or d->>'condicion' is distinct from 'HABIDO' then raise exception 'Se requiere consulta actual del RUC ACTIVO y HABIDO.';end if;
  perform pg_advisory_xact_lock(hashtextextended(s.ruc,6));
  perform pg_advisory_xact_lock(hashtextextended(s.propietario_id::text,4));
  if (select propietario_id from public.clientes where id=s.cliente_id) is distinct from s.propietario_id then raise exception 'El vínculo del propietario cambió; requiere revisión administrativa.';end if;
  if (private.situacion_individual(s.representante_id)->>'verificacion') is distinct from 'aprobada' then raise exception 'El DNI del representante requiere revalidación.';end if;
  if not exists(select 1 from public.representaciones_empresa where id=s.representacion_id and estado='pendiente' and archivo_sha256=s.expediente#>>'{certificado,sha256}') then raise exception 'El certificado requiere una nueva presentación.';end if;
  update public.representaciones_empresa set estado='revisada',observacion=p_motivo,referencia_validacion=p_referencia,revisor_id=a.id,revisado_at=now(),valida_hasta=public.fecha_peru(),monto_maximo=s.monto,version=version+1,updated_at=now() where id=s.representacion_id;
  insert into public.historial_representaciones(representacion_id,asesor_id,estado,detalle) values(s.representacion_id,a.id,'revisada',p_motivo);
  update public.clientes set representante_id=s.representante_id,razon_social=d->>'razon_social',estado_ruc=d->>'estado',condicion_ruc=d->>'condicion',direccion_fiscal=d->>'direccion',ruc_consultado_at=(d->>'consultadoEn')::timestamptz,evidencia_propiedad=s.expediente->>'evidencia_propiedad',evidencia_poder='Certificado de vigencia de poder: '||s.representacion_id::text where id=s.cliente_id;
  perform set_config('app.ruc_validado',s.ruc,true);perform set_config('app.representacion_id',s.representacion_id::text,true);perform set_config('app.solicitud_id',s.id::text,true);
  pid:=private.crear_prestamo(s.cliente_id,s.monto,s.plazo_meses,s.id);
  update public.prestamos set identidad_contrato=identidad_contrato||jsonb_build_object('solicitud_id',s.id,'representacion_id',s.representacion_id,'representacion_sha256',s.expediente#>>'{certificado,sha256}','evaluador_id',a.id) where id=pid;
 end if;
 update public.solicitudes_prestamo set estado=p_estado,motivo=trim(p_motivo),evaluador_id=a.id,prestamo_id=pid,version=version+1,updated_at=now() where id=s.id;
 insert into public.historial_solicitudes(solicitud_id,asesor_id,estado,detalle,expediente) values(s.id,a.id,p_estado,trim(p_motivo),s.expediente);
 return pid;
end$$;

create function private.completar_propietario_solicitud(p_id uuid,p_version integer,p_propietario jsonb,p_consulta jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;v_ruc text;cid uuid;o uuid;datos jsonb;e jsonb;estado_nuevo text;begin
 a:=private.asesor();select ruc into v_ruc from public.solicitudes_prestamo where id=p_id and agencia_id=a.agencia_id;
 perform pg_advisory_xact_lock(hashtextextended(v_ruc,6));
 select * into s from public.solicitudes_prestamo where id=p_id and agencia_id=a.agencia_id for update;
 if s.id is null then raise exception 'Solicitud fuera de su agencia.' using errcode='42501';end if;
 if not coalesce((s.expediente#>>'{propietario,verificacion_pendiente}')::boolean,false) then return s.id;end if;
 if s.estado not in ('pendiente_identidad','observada') or s.version is distinct from p_version then raise exception 'La solicitud cambió o ya fue evaluada. Actualice.';end if;
 if p_propietario->>'dni' is distinct from s.expediente#>>'{propietario,dni}' or p_propietario#>'{borrador,evidencia}' is null then raise exception 'Verifique presencialmente al mismo propietario de la solicitud.';end if;
 datos:=jsonb_build_object('consulta',p_consulta,'propietario',p_propietario,'representante',s.expediente->'representante','propiedad_confirmada',true,'evidencia_propiedad',s.expediente->>'evidencia_propiedad','evidencia_poder','Certificado presentado para evaluación');
 cid:=private.preparar_empresa_solicitud(datos,s.clave_envio);
 select propietario_id into o from public.clientes where id=cid;
 e:=jsonb_set(s.expediente,'{propietario}',(select jsonb_build_object('dni',dni,'nombres',nombres,'apellidos',apellidos,'verificacion_pendiente',false) from public.clientes where id=o));
 e:=e||jsonb_build_object('verificacion_propietario',jsonb_build_object('asesor_id',a.id,'agencia_id',a.agencia_id,'fecha',now()));
 estado_nuevo:=case when s.estado='observada' then 'observada' else 'pendiente' end;
 update public.solicitudes_prestamo set cliente_id=cid,propietario_id=o,expediente=e,estado=estado_nuevo,version=version+1,updated_at=now() where id=s.id;
 insert into public.historial_solicitudes(solicitud_id,asesor_id,estado,detalle,expediente) values(s.id,a.id,estado_nuevo,'Identidad del propietario verificada presencialmente. Se conserva el certificado y no se genera préstamo.',e);
 return s.id;
end$$;
create function public.completar_propietario_solicitud(p_id uuid,p_version integer,p_propietario jsonb,p_consulta jsonb) returns uuid language sql security invoker set search_path='' as $$select private.completar_propietario_solicitud(p_id,p_version,p_propietario,p_consulta)$$;
revoke all on function private.completar_propietario_solicitud(uuid,integer,jsonb,jsonb),public.completar_propietario_solicitud(uuid,integer,jsonb,jsonb) from public,anon;
grant execute on function private.completar_propietario_solicitud(uuid,integer,jsonb,jsonb),public.completar_propietario_solicitud(uuid,integer,jsonb,jsonb) to authenticated;
commit;
