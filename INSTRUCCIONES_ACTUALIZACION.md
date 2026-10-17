# Actualizar esta versión: clientes por agencia y revalidación

Esta entrega parte de la versión publicada el 16/10/2026 (commit 9545072).
La base Supabase del proyecto ya recibió ACTUALIZAR_SISTEMA el 17/10/2026 UTC.
Los cambios nuevos de esta entrega son de aplicación: NO requieren SQL adicional,
cambiar claves ni instalar dependencias.

## Actualizar tu carpeta local

1. Detén el servidor con Ctrl+C y extrae este ZIP en una carpeta aparte.
2. Conserva app/.env.local, app/node_modules, app/templates y la carpeta .git.
3. Reemplaza app/src completo con el de este ZIP. Retira app/.next para regenerar
   la compilación. Copia app/tests si usas las pruebas; conserva sus dependencias.
4. Reemplaza docs, INSTRUCCIONES_ACTUALIZACION.md y LEEME_PRIMERO.md.
5. Desde app ejecuta npm.cmd run dev. No necesitas npm.cmd ci.

## Actualizar GitHub desde la web

1. Abre tu repositorio prestamos-parcial, rama main, y entra en app.
2. Add file → Upload files. Desde la carpeta local app arrastra SOLO src completo.
   Son menos de 100 archivos. No arrastres app dentro de app ni la carpeta del ZIP.
3. Commit changes: «Ajustar clientes por agencia y actualización de identidad y SUNAT».
4. En otra carga, actualiza docs y los dos archivos de instrucciones en la raíz.
   Commit: «Actualizar guía de publicación y pruebas manuales».
5. Si quieres mantener las pruebas del repositorio al día, dentro de app/tests
   sube servidor-pruebas.mjs. Commit: «Actualizar servidor local de pruebas».
6. No subas .env.local, node_modules, .next, .git ni .vercel. La subida web no aplica
   automáticamente las exclusiones de .gitignore.

Los archivos con la misma ruta se actualizan; no borres el repositorio.
No cambian package.json ni package-lock.json.

## Vercel y Supabase

- La integración existente de main debe generar el despliegue automáticamente.
  Espera a que aparezca Ready y comprueba que el commit sea el recién subido.
- Abre https://prestamos-parcial.vercel.app y recarga la página.
- Conserva las variables de producción que ya funcionan para DNI y RUC.
- No ejecutes SQL para esta revisión. Los scripts del ZIP se conservan para
  instalaciones que aún no recibieron los ajustes anteriores.

## Comprobaciones

1. Clientes muestra titulares con al menos un préstamo confirmado de la agencia,
   aunque el préstamo ya esté pagado. El registro o vínculo por sí solo no basta.
2. Desde la ficha siguen accesibles las personas y empresas del grupo y sus datos
   compartidos. Préstamos muestra solo la cartera local; Pagos conserva el grupo global.
3. DNI + RUC10: «Revalidar datos» se despliega en la misma ficha. DNI abre identidad
   directamente; SUNAT abre directamente la actualización del RUC. No hay selector intermedio.
4. Solo DNI abre identidad; RUC20 abre «Actualizar datos SUNAT» directamente.
5. Una persona aprobada/habilitada puede volver a revisar sus documentos. No se
   rellenan automáticamente las confirmaciones de revisión presencial.
6. SUNAT muestra datos actuales y valores anteriores si cambiaron. Sin cambios,
   «Registrar consulta SUNAT» actualiza la fecha y el historial al guardar.
7. Un fallo técnico permite reintentar sin cambiar la identidad ni guardar un rechazo.
8. Comprueba fecha de última revisión DNI y consulta SUNAT dentro del bloque de
   identificación ya existente. El domicilio fiscal debe ocupar una fila amplia.

Ver docs/OBSERVACIONES_CLIENTES_REVALIDACION.md para el detalle de esta revisión.
