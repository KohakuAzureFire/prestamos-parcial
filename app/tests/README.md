# Pruebas de operaciones

Desde esta carpeta ejecuta `npm install` y `npm test`. Usa PostgreSQL en memoria (PGlite) con RLS, roles y pgcrypto. No se conecta a Supabase ni requiere sus claves. Los datos del archivo fixtures.json son ficticios.

Se prueba la migración completa salvo la extensión pg_cron, las restricciones de cartera por agencia, identidad firmada, capital global, operación idempotente, cobros entre agencias, rechazo de selección obsoleta, caducidad, umbrales de mora y cierre de deuda.

PGlite serializa transacciones: el caso de selección obsoleta verifica el rechazo que protege contra dos cobros sobre la misma cuota, pero no es una prueba de carga concurrente en el proyecto remoto.

La suite también comprueba la migración de clientes por agencia: ficha única, búsqueda dirigida, revalidación compartida, pagos que no incorporan al cliente y préstamos locales que sí lo incorporan. No modifica Supabase real.

La suite borradores.test.mjs carga la migración final y verifica alta diferida, firma, rollback de errores intermedios, reintentos y revalidación independiente. Se ejecuta junto con la suite de agencias mediante npm test.
