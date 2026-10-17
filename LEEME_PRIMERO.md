# Agencia de préstamos — actualización

Revisión: listado de clientes por agencia, menú Revalidar datos y actualización SUNAT.

Lee INSTRUCCIONES_ACTUALIZACION.md para copiar los cambios y publicarlos en GitHub.
Conserva tu app/.env.local y app/node_modules: este ZIP no los contiene.
No cambian dependencias; no necesitas volver a ejecutar npm.cmd ci.

La Supabase de prestamos-parcial ya se actualizó en esta conversación.
Esta revisión NO requiere SQL adicional ni cambiar claves de Vercel.
La publicación en GitHub la realiza el usuario; el ZIP no publica cambios por sí solo.

Cambios: Clientes lista únicamente titulares con préstamos confirmados de la agencia;
las fichas conservan sus vínculos compartidos; Revalidar datos despliega DNI/RUC10
sin pantalla intermedia; SUNAT compara datos y registra la nueva consulta; se añaden
fechas de revisión y consulta al bloque de identificación y mensajes diferenciados.

Los scripts SQL se conservan para instalaciones que aún no recibieron los ajustes anteriores.
