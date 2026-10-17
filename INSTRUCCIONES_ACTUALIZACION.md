# Actualizar esta versión: ficha resumida y pagos con contexto

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

## Actualizar GitHub desde la web: tres commits

Usa el contenido extraído de este ZIP, sin mezclarlo con carpetas generadas locales.

1. En GitHub entra en app → Add file → Upload files. Desde el app del ZIP selecciona
   TODO excepto src y arrástralo. Son menos de 100 archivos en total.
   Commit: «Actualizar recursos, documentación y pruebas».
2. Mantente dentro de app y sube SOLO la carpeta src completa. También tiene menos
   de 100 archivos, contando subcarpetas.
   Commit: «Simplificar fichas y mejorar el flujo de pagos».
3. Vuelve a la raíz y sube docs, .gitignore, INSTRUCCIONES_ACTUALIZACION.md y
   LEEME_PRIMERO.md.
   Commit: «Actualizar instrucciones de instalación y publicación».

No arrastres app dentro de app. No subas la carpeta que contiene el proyecto ni el ZIP.
No borres el repositorio: los archivos con la misma ruta se actualizan. Los que no
cambiaron conservan el commit anterior; es normal.
No subas .env.local, node_modules, .next, .git ni .vercel. La subida web no aplica
las exclusiones de .gitignore automáticamente.
No cambian package.json ni package-lock.json; no hace falta npm.cmd ci.

## Vercel y Supabase

- La integración existente de main debe generar el despliegue automáticamente.
  Espera a que aparezca Ready y comprueba que el commit sea el recién subido.
- Abre https://prestamos-parcial.vercel.app y recarga la página.
- Conserva las variables de producción que ya funcionan para DNI y RUC.
- No ejecutes SQL para esta revisión. Los scripts del ZIP se conservan para
  instalaciones que aún no recibieron los ajustes anteriores.

## Comprobaciones de esta revisión

1. La ficha ya no contiene tablas de préstamos o historiales completos. Al final
   aparecen Consultar para pagar y Ver historial. Conserva identidad, capital,
   vínculos y, cuando corresponda, las alertas y autorización por antecedente.
2. Solo DNI abre su historial directamente; DNI + RUC10 despliega DNI/RUC; RUC20
   abre su historial SUNAT directamente. Todos regresan a la misma ficha.
3. Condición de pago muestra Sin atrasos en vez de Habilitado, sin cambiar reglas.
4. Desde una ficha, Consultar para pagar conserva documento fijo y muestra el grupo
   de todas las agencias. Aparece Volver a la ficha del cliente, también si era empresa.
5. La lista de préstamos no desplaza la pantalla automáticamente. Elegir préstamo
   baja hasta el nombre del titular y deja cuotas y cobro debajo. Si la consulta devuelve
   un solo préstamo, su selección automática también desplaza hasta ese encabezado.
6. Préstamos → Ver detalle → Registrar pago abre ese préstamo con código y tipo fijos,
   carga automática y Volver al detalle del préstamo. La identificación usa el UUID
   completo para evitar coincidencias de códigos cortos.
7. Cambiar la cantidad de cuotas no repite el desplazamiento. Se respeta la preferencia
   del navegador de reducir animaciones.
8. Pagos desde el menú conserva búsqueda editable, sin regreso contextual; al editar
   la búsqueda se descartan los resultados y confirmaciones anteriores.

Consulta docs/FICHA_RESUMIDA_Y_PAGOS.md para el alcance y las pruebas de esta revisión.
