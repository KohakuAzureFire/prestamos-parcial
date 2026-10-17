# Actualizar esta versión

1. Detén el servidor con Ctrl+C y extrae el ZIP en una carpeta aparte.
2. Conserva app/.env.local, app/node_modules, app/templates y .git. Elimina únicamente app/src y app/.next; copia el nuevo app/src y app/scripts. Reemplaza docs y los archivos de instrucciones/lectura. Si usas pruebas, copia app/tests conservando sus dependencias.
3. En VS Code abre app/scripts/ACTUALIZAR_SISTEMA.sql. Copia TODO SU CONTENIDO con Ctrl+A y Ctrl+C.
4. En Supabase → SQL Editor → consulta nueva, pega ese código completo y pulsa Run. Debe aparecer Success. No pegues la ruta del archivo. El script incluye los ajustes anteriores y los actuales; no es necesario ejecutar los demás por separado, y se puede repetir. No cambia importes, préstamos, contratos ni pagos existentes. No se ha ejecutado en el proyecto real desde este chat.
5. Desde app ejecuta npm.cmd run dev. No cambian dependencias ni variables: no necesitas npm.cmd ci para actualizar tu carpeta actual.

Esta revisión incorpora fichas compartidas por grupo entre agencias, diseño uniforme y navegación a los vínculos; conserva cartera local y consulta global de pagos por DNI/RUC10/RUC20; retira Cambiar cliente desde ficha; añade el desplegable de Solicitar préstamo en la ficha y limita Plazo a 1–60 con 0 inicial. El campo de monto mantiene el formato fijo de soles y centavos.

Consulta docs/FICHAS_COMPARTIDAS.md para el comportamiento, alcance de acceso y pruebas manuales. Git/Vercel no se publicaron en esta entrega. No subas .env.local, .next ni node_modules al repositorio.
