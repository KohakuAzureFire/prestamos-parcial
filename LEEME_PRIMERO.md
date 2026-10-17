# Agencia de préstamos — ficha resumida y pagos

Lee INSTRUCCIONES_ACTUALIZACION.md para copiar los cambios y los tres commits de GitHub.
Conserva tu app/.env.local y app/node_modules: no están incluidos en el ZIP.
No cambian dependencias ni claves. No necesitas npm.cmd ci ni SQL adicional sobre
la Supabase del proyecto ya sincronizada en esta conversación.

Esta entrega simplifica la ficha y separa sus historiales, retira la tabla de préstamos
locales de la ficha, añade regreso contextual en Pagos y fija el préstamo cuando se
entra desde su detalle. Al seleccionar un préstamo se desplaza hasta su titular.
La condición de pago pasa a mostrar Sin atrasos en lugar de Habilitado.

Publicación: el usuario sube los tres commits. Después verificaremos Supabase y Vercel.
Los scripts SQL se conservan para instalaciones que no recibieron los ajustes anteriores.
