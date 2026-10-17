# Actualización de la documentación del sistema

Este paquete contiene solo documentación actualizada tras contrastar GitHub y los cambios implementados hasta el código `5723a1385559f3e60d003c74395f9d3ae5edbda5`. Conserva las rutas del proyecto. No incluye cambios de aplicación, dependencias ni base de datos.

## Archivos que se actualizan

- `docs/Sprint_1_Sistema_Prestamos.docx`.
- `docs/REQUISITOS.md`, `docs/ESTADO_IMPLEMENTACION.md`, `docs/FICHAS_COMPARTIDAS.md` y `docs/REVALIDACION_Y_PAGOS.md`.
- `docs/OBSERVACIONES_CLIENTES_REVALIDACION.md`, `docs/CAMBIOS_INTERFAZ.md` y `docs/CAMPO_MONTO.md`.
- `docs/FICHA_RESUMIDA_Y_PAGOS.md`, `docs/AJUSTES_REGRESO_Y_DESPLAZAMIENTO.md`, `docs/CONTROL_SESIONES.md` y `docs/ARCHIVOS_CAMBIADOS_SESIONES.md`.
- `app/README.md` y `app/tests/README.md`.
- `LEEME_PRIMERO.md` e `INSTRUCCIONES_ACTUALIZACION.md`.

Son 16 archivos. El paquete no contiene `Contrato_profesor.docx`, plantillas ni archivos de código porque no cambian.

## Copiar a tu proyecto

1. Descomprime el ZIP aparte.
2. Copia su contenido sobre la raíz de tu proyecto, aceptando reemplazar los 16 archivos indicados.
3. Conserva los archivos no incluidos, especialmente el contrato original, las plantillas, `app/src`, `.env.local` y `node_modules`. No borres `docs` ni `app` antes de copiar: el paquete es parcial.

## GitHub web

1. Abre la raíz de `KohakuAzureFire/prestamos-parcial`, rama `main`.
2. Elige **Add file → Upload files**.
3. Arrastra las carpetas `docs` y `app` del paquete y los dos archivos Markdown de la raíz. Son carpetas parciales que conservan las rutas existentes; no arrastres la carpeta contenedora del ZIP.
4. Comprueba que las rutas comiencen por `docs/`, `app/README.md`, `app/tests/README.md` o los dos nombres de la raíz, sin duplicar `app/app` ni `docs/docs`.
5. Confirma con **`docs: sincronizar requisitos y manuales con el sistema publicado`**.

Un solo commit basta; son menos de 100 archivos. Vercel puede iniciar su proceso automático por el commit, pero esta revisión no necesita una activación nueva en Supabase ni cambios de variables. No vuelvas a aplicar SQL antiguo por una actualización documental.

## Comprobación

Abre el Word y verifica la conservación de las tablas e historias HU-01 a HU-08. Los requisitos de clientes por agencia, pagos con contexto, fichas resumidas, representación y sesiones deben coincidir con `docs/REQUISITOS.md`. Las guías técnicas describen los mismos flujos y distinguen la publicación verificada de las pruebas aisladas.
