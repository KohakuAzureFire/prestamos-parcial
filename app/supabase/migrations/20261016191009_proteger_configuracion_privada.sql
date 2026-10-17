-- Acceso directo denegado; las funciones comprueban asesor activo y permisos.
create policy permisos_solo_operaciones on private.permisos_operacion
for all to authenticated using(false) with check(false);
create policy configuracion_solo_operaciones on private.historial_configuracion_mora
for all to authenticated using(false) with check(false);
