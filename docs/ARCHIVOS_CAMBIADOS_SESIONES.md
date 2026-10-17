# Archivos exactos de esta actualización

Solo hay **16 archivos**. No se incluyen carpetas completas ni archivos sin cambios.

## Commit 1: `feat: preparar control de sesiones en base de datos`

Subir el contenido de `01_BASE_DATOS_Y_PRUEBAS` a la raíz del repositorio:

- `app/scripts/control_sesiones.sql` — nuevo.
- `app/tests/sesiones.test.mjs` — nuevo: pruebas del control de sesiones.
- `app/tests/operaciones.test.mjs` — admite identificador de sesión en el auxiliar local.
- `app/tests/servidor-pruebas.mjs` — incorpora sesiones al servidor aislado de prueba.

## Commit 2: `feat: agregar contador de inactividad y sesion unica`

Subir el contenido de `02_CODIGO` a la raíz del repositorio:

- `app/src/app/api/sesion/route.ts` — nuevo: inicio, consulta, actividad y cierre.
- `app/src/app/dashboard/layout.tsx` — contador después de la fecha.
- `app/src/app/globals.css` — indicador, diálogo y adaptación móvil.
- `app/src/app/login/page.tsx` — registra la nueva sesión y explica el motivo del cierre.
- `app/src/components/ControlSesion.tsx` — nuevo: tiempo, actividad, aviso y sincronización entre pestañas.
- `app/src/components/Sidebar.tsx` — cierre de la sesión actual.
- `app/src/lib/sesion.ts` — nuevo: cierre y mensajes comunes.
- `app/src/lib/supabase/middleware.ts` — comprueba sesión en rutas y conserva cookies renovadas.

## Commit 3: `docs: documentar activacion y pruebas de sesiones`

Subir el contenido de `03_DOCUMENTACION` a la raíz del repositorio:

- `docs/CONTROL_SESIONES.md` — nuevo.
- `docs/ARCHIVOS_CAMBIADOS_SESIONES.md` — este archivo, nuevo.
- `INSTRUCCIONES_ACTUALIZACION.md` — actualizado.
- `LEEME_PRIMERO.md` — actualizado.

Conserva los demás archivos del repositorio. En local copia el contenido de los tres grupos sobre tu proyecto, manteniendo sus rutas; no borres carpetas. No se modificaron `package.json`, `package-lock.json` ni las variables de entorno.
