# Pruebas de operaciones

Desde esta carpeta ejecuta `npm install` y `npm test`. Usa PostgreSQL en memoria (PGlite) con RLS, roles y pgcrypto. No se conecta a Supabase ni requiere sus claves. Los datos del archivo fixtures.json son ficticios.

Se prueba la migración completa salvo la extensión pg_cron, las restricciones de cartera por agencia, identidad firmada, capital global, operación idempotente, cobros entre agencias, rechazo de selección obsoleta, caducidad, umbrales de mora y cierre de deuda.

PGlite serializa transacciones: el caso de selección obsoleta verifica el rechazo que protege contra dos cobros sobre la misma cuota, pero no es una prueba de carga concurrente en el proyecto remoto.

La suite también comprueba la migración de clientes por agencia: ficha única, búsqueda dirigida, revalidación compartida, pagos que no incorporan al cliente y préstamos locales que sí lo incorporan. No modifica Supabase real.

La suite borradores.test.mjs carga la migración final y verifica alta diferida, firma, rollback de errores intermedios, reintentos y revalidación independiente. Se ejecuta junto con la suite de agencias mediante npm test.


## Ampliación por RUC

`npm test` incluye `ruc.test.mjs`: DNI/RUC10, RUC20 y propietario, firmas, rollback, límite compartido, mora por días, configuración congelada, cotización, regularización y rehabilitación con permisos. Usa PGlite aislado, sin escribir en Supabase real. La tasa del 12 % de los ejemplos es ficticia y se usa solo en pruebas.

Desde `app`, `node tests/contrato.test.mjs` con Node 24 comprueba el Word y el escape de caracteres. Solo escribe un archivo si se indica `CONTRATO_PRUEBA_SALIDA`.


## Modalidad personal con RUC10

Con Node 24, desde `app`, ejecuta `node tests/modalidad.test.mjs`. Carga el ajuste de `scripts/habilitar_modalidad_personal.sql` en PGlite. Verifica modalidad DNI con RUC10 observado, contrato DNI, capital compartido entre agencias, rechazo de empresas por DNI, idempotencia por modalidad y permisos anon. `ruc.test.mjs` también carga este ajuste para verificar la regresión del flujo de negocio. Ninguna prueba modifica Supabase real.


## Revalidación y pagos globales

Con Node 24, desde `app`, ejecuta `node tests/revalidacion-pagos.test.mjs`. Comprueba consulta global por propietario entre agencias, cartera local, cobro cruzado, exclusión del representante, revalidación RUC firmada e idempotente sin préstamo, permisos y validación de importes. `ruc.test.mjs` también carga el ajuste nuevo como regresión.


## Fichas compartidas y grupo

Con Node 24, desde app: `node tests/fichas-grupo.test.mjs`. Carga el SQL acumulado y prueba la misma ficha e historial entre agencias, acceso al grupo atendido sin exponer grupos ajenos, cartera local, equivalencia de pagos por DNI/RUC10/RUC20, separación de representantes y repetición del SQL sin modificar contratos o préstamos.
