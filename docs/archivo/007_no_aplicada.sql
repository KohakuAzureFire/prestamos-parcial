-- 007 · Parámetros centralizados, helpers de sesión e historial de verificación de identidad
-- Compatible con los datos existentes: solo agrega objetos y columnas; no borra información.

-- ---------------------------------------------------------------------------
-- Parámetros operativos (REQUISITOS.md · "Decisiones que precisan el alcance")
-- Ajustables por SQL si el profesor cambia el criterio, sin tocar código.
-- ---------------------------------------------------------------------------
create table if not exists public.parametros_negocio (
  clave text primary key,
  valor numeric not null,
  descripcion text not null,
  updated_at timestamptz not null default now()
);

insert into public.parametros_negocio (clave, valor, descripcion) values
  ('capital_maximo', 10000, 'Capital pendiente máximo por cliente entre las cinco agencias, incluido el nuevo monto (S/).'),
  ('plazo_min_meses', 1, 'Plazo mínimo en meses enteros.'),
  ('plazo_max_meses', 60, 'Plazo máximo en meses enteros.'),
  ('dias_gracia_mora', 0, 'Días posteriores al vencimiento antes de considerar la cuota vencida. 0 = mora desde el día siguiente.'),
  ('meses_extrajudicial', 12, 'Meses calendario desde el vencimiento de la cuota impaga más antigua para clasificar Extrajudicial.'),
  ('minutos_validez_consulta_identidad', 30, 'Minutos durante los que una consulta firmada a la fuente de identidad puede registrarse.')
on conflict (clave) do nothing;

alter table public.parametros_negocio enable row level security;
drop policy if exists parametros_select on public.parametros_negocio;
create policy parametros_select on public.parametros_negocio for select to authenticated using (true);
revoke insert, update, delete, truncate on public.parametros_negocio from anon, authenticated;

create or replace function public.parametro(p_clave text)
returns numeric language sql stable security definer set search_path = public as $$
  select valor from public.parametros_negocio where clave = p_clave
$$;

-- Fecha de operación en Perú (UTC-5, sin horario de verano)
create or replace function public.fecha_peru()
returns date language sql stable as $$
  select (now() at time zone 'America/Lima')::date
$$;

-- Helpers de sesión
create or replace function public.es_asesor_activo()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.asesores where id = auth.uid() and activo)
$$;

create or replace function public.mi_agencia()
returns uuid language sql stable security definer set search_path = public as $$
  select agencia_id from public.asesores where id = auth.uid() and activo
$$;

-- ---------------------------------------------------------------------------
-- Agencias: solo las cinco del negocio
-- ---------------------------------------------------------------------------
alter table public.agencias drop constraint if exists agencias_nombre_valido;
alter table public.agencias add constraint agencias_nombre_valido
  check (nombre in ('Chimbote', 'Trujillo', 'Chiclayo', 'Piura', 'Tumbes'));
alter table public.agencias drop constraint if exists agencias_nombre_unico;
alter table public.agencias add constraint agencias_nombre_unico unique (nombre);

-- Nuevas cuentas: sin agencia por defecto. Una cuenta sin agencia explícita no obtiene perfil de asesor.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_agencia uuid := nullif(new.raw_user_meta_data->>'agencia_id', '')::uuid;
begin
  if v_agencia is null or not exists (select 1 from public.agencias where id = v_agencia) then
    return new;
  end if;
  insert into public.asesores (id, agencia_id, nombre_completo)
  values (new.id, v_agencia, coalesce(new.raw_user_meta_data->>'nombre_completo', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Historial de verificación de identidad (solo inserción)
-- ---------------------------------------------------------------------------
create table if not exists public.verificaciones_identidad (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  resultado text not null check (resultado in ('aprobada', 'rechazada', 'pendiente')),
  origen text not null check (origen in ('registro', 'revalidacion', 'migracion')),
  fuente text not null,
  consultado_en timestamptz,
  nombres_fuente text,
  apellidos_fuente text,
  fecha_caducidad date,
  evidencia_vigencia_tipo text,
  evidencia_vigencia_ref text,
  evidencia_supervivencia_tipo text,
  evidencia_supervivencia_ref text,
  no_fallecido_acreditado boolean not null default false,
  fallecimiento_acreditado boolean not null default false,
  motivo text,
  asesor_id uuid references public.asesores(id),
  agencia_id uuid references public.agencias(id),
  created_at timestamptz not null default now()
);
create index if not exists verificaciones_cliente_idx on public.verificaciones_identidad (cliente_id, created_at desc);

create or replace function public.bloquear_modificacion()
returns trigger language plpgsql as $$
begin
  raise exception 'Registro de solo lectura: % no admite %', tg_table_name, tg_op using errcode = '42501';
end;
$$;

drop trigger if exists verificaciones_inmutables on public.verificaciones_identidad;
create trigger verificaciones_inmutables before update or delete on public.verificaciones_identidad
  for each row execute function public.bloquear_modificacion();

-- Clientes: estado vigente de verificación (resumen del último registro) y condición de pago automática
alter table public.clientes
  add column if not exists verificacion_id uuid references public.verificaciones_identidad(id),
  add column if not exists verificacion_resultado text not null default 'pendiente',
  add column if not exists dni_caducidad date,
  add column if not exists fallecimiento_acreditado boolean not null default false,
  add column if not exists condicion_pago text not null default 'habilitado',
  add column if not exists mora_desde date,
  add column if not exists situacion_actualizada_at timestamptz;

alter table public.clientes drop constraint if exists clientes_verificacion_resultado_chk;
alter table public.clientes add constraint clientes_verificacion_resultado_chk
  check (verificacion_resultado in ('aprobada', 'rechazada', 'pendiente'));
alter table public.clientes drop constraint if exists clientes_condicion_pago_chk;
alter table public.clientes add constraint clientes_condicion_pago_chk
  check (condicion_pago in ('habilitado', 'moroso', 'extrajudicial'));

comment on column public.clientes.condicion is
  'LEGADO (entrega anterior): condición editable manualmente. Ya no se usa ni se modifica; ver condicion_pago (automática) y verificaciones_identidad.';
comment on column public.clientes.resultado_verificacion is
  'LEGADO: texto libre de la verificación anterior. Conservado por trazabilidad; el historial vigente está en verificaciones_identidad.';

-- Estado de verificación vigente: Caducada se deriva de la fecha de Perú
create or replace function public.estado_verificacion(p_resultado text, p_caducidad date, p_fallecido boolean)
returns text language sql stable as $$
  select case
    when coalesce(p_fallecido, false) then 'rechazada'
    when p_resultado = 'aprobada' and (p_caducidad is null or p_caducidad < public.fecha_peru()) then 'caducada'
    else coalesce(p_resultado, 'pendiente')
  end
$$;

-- Historial de condición de pago (trazabilidad del atraso)
create table if not exists public.historial_condicion_pago (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  condicion_anterior text,
  condicion_nueva text not null,
  mora_desde date,
  cuotas_vencidas integer not null default 0,
  origen text not null,
  fecha_referencia date not null,
  created_at timestamptz not null default now()
);
create index if not exists historial_condicion_cliente_idx on public.historial_condicion_pago (cliente_id, created_at desc);
drop trigger if exists historial_condicion_inmutable on public.historial_condicion_pago;
create trigger historial_condicion_inmutable before update or delete on public.historial_condicion_pago
  for each row execute function public.bloquear_modificacion();
