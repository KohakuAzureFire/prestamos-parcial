-- Evaluación guiada: conserva la referencia presentada y los controles de aprobación.
create or replace function private.evaluar_solicitud(p_id uuid,p_version integer,p_estado text,p_motivo text,p_consulta jsonb default null,p_referencia text default null,p_facultades boolean default false,p_individual boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.asesores;s public.solicitudes_prestamo;d jsonb;pid uuid;v_ruc text;begin
 a:=private.asesor();select ruc into v_ruc from public.solicitudes_prestamo where id=p_id and agencia_id=a.agencia_id;perform pg_advisory_xact_lock(hashtextextended(v_ruc,6));select * into s from public.solicitudes_prestamo where id=p_id and agencia_id=a.agencia_id for update;
 if s.id is null then raise exception 'Solicitud fuera de su agencia.' using errcode='42501';end if;
 if s.estado='aprobada' and p_estado='aprobada' then return s.prestamo_id;end if;
 if coalesce((s.expediente#>>'{propietario,verificacion_pendiente}')::boolean,false) and p_estado='aprobada' then raise exception 'Complete la verificación presencial del propietario antes de aprobar.';end if;
 if s.estado not in ('pendiente','pendiente_identidad') or s.version is distinct from p_version then raise exception 'La solicitud cambió o ya fue evaluada. Actualice.';end if;
 if p_estado is null or p_estado not in ('aprobada','observada','rechazada') then raise exception 'Seleccione un resultado válido.';end if;
 if length(coalesce(p_motivo,''))>1000 or (p_estado<>'aprobada' and length(trim(coalesce(p_motivo,'')))<10) then raise exception 'Para observar o rechazar, registre un motivo de 10 a 1000 caracteres.';end if;
 p_motivo:=coalesce(nullif(trim(p_motivo),''),'Aprobación registrada con certificado revisado, facultades suficientes y firma individual confirmadas.');
 if p_estado='aprobada' then
  p_referencia:=trim(p_referencia);
  if p_facultades is distinct from true or p_individual is distinct from true or coalesce(p_referencia,'') !~ '^[A-Za-z0-9][A-Za-z0-9/-]{0,79}$' then raise exception 'Compruebe autenticidad, facultades y firma individual, con el código de verificación del certificado (hasta 80 caracteres: letras, números, guion o barra).';end if;
  p_referencia:='Código de verificación del certificado: '||p_referencia||'; Documento de propiedad presentado: '||coalesce((s.expediente->>'evidencia_propiedad')::jsonb->>'ref','');
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

