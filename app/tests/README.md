# Pruebas de operaciones

Las suites usan PostgreSQL en memoria mediante PGlite, roles, RLS y pgcrypto. Los datos de `fixtures.json` son ficticios; no conectan con Supabase real ni requieren sus claves. Se probaron con Node.js 24.

## Preparación y ejecución

Desde `app/tests`:

```powershell
npm.cmd ci
npm test
```

`npm test` ejecuta `agencias.test.mjs`, `borradores.test.mjs`, `ruc.test.mjs` , `representaciones.test.mjs` y `solicitudes.test.mjs`: cartera por agencia, identidad, alta conjunta, rollback, firmas, capital global, pagos sin recargos, atrasos e idempotencia.

`ruc.test.mjs` aplica el retiro final y comprueba que no queden columnas, funciones o parámetros de recargos, que el importe atrasado sea la cuota original y que el aviso de Pagos dependa de deuda pendiente del RUC exacto. También comprueba la reaplicación del SQL.

`representaciones.test.mjs` añade un esquema Storage sintético y aplica la migración de revisión RUC 20. Comprueba filtros DNI/RUC 10, PDF y límites, RLS, recibo firmado por servidor, archivo inmutable, permiso de revisión, versión obsoleta, fecha e importe, presentación posterior, revocación, conservación de préstamos, reintentos y sesión vencida. Prueba S/ 2 000 personal/RUC 10 + S/ 5 000 de una empresa + S/ 3 000 de otra, en agencias distintas, y rechaza exceder S/ 10 000. No consulta Decolecta ni consume su cuota.

`solicitudes.test.mjs` aplica además la migración del 22/10. Comprueba envío completo sin préstamo ni cuotas, altas y expediente transaccionales, duplicados por RUC entre agencias, privacidad, corrección de observadas en la misma solicitud, rechazo y nueva presentación, evaluación del asesor sin permisos especiales, DNI y SUNAT vigentes, aprobación idempotente y capital revalidado si el cupo cambia mientras se espera. El RPC antiguo no debe generar RUC 20 directamente. Las suites históricas conservan su versión del esquema y excluyen esta migración.

Las siguientes suites se ejecutan **aparte desde `app`**:

| Comando | Comprobación principal |
| --- | --- |
| `node tests/modalidad.test.mjs` | Préstamo personal por DNI con RUC 10 asociado, modalidad contractual y cupo compartido. |
| `node tests/revalidacion-pagos.test.mjs` | Revalidación RUC firmada, consulta global, cobro cruzado y exclusión del representante como propietario. |
| `node tests/fichas-grupo.test.mjs` | Identidad y vínculos compartidos, permisos, cartera local y pagos equivalentes por DNI/RUC 10/RUC 20. |
| `node tests/sesiones.test.mjs` | Inactividad, actividad válida, sondeo sin renovación, sesión reemplazada y cierre antiguo que no revoca la nueva. |
| `node tests/contrato.test.mjs` | Word, campos variables y escape XML; solo escribe salida si se configura `CONTRATO_PRUEBA_SALIDA`. |

PGlite serializa transacciones: probar selección obsoleta no equivale a una prueba de carga concurrente remota. Cada suite prepara su propia base; no se aplica el SQL de sesiones indiscriminadamente a pruebas antiguas sin identificador de sesión. Las suites históricas excluyen la migración nueva de Storage; `representaciones.test.mjs` la prepara y comprueba por separado. El almacenamiento sintético no sustituye una prueba del servicio real ni de la carga HTTP en navegador.

## Comprobación en navegador

Los casos funcionales están en `docs/REQUISITOS.md`, desde la raíz del repositorio: identidad, representación, pasos, límites, fichas, documentos, pagos con contexto y sesiones. Comprueba escritorio y móvil, regreso al origen, limpieza de resultados y desplazamiento al préstamo seleccionado.

Para sesiones, usa dos navegadores independientes: el segundo inicio debe bloquear al anterior; cerrar el anterior no debe cerrar el nuevo. Comprueba aviso, Continuar sesión y vencimiento. Los sondeos automáticos no deben prolongar la sesión.

Para RUC 20, verifica cuatro pantallas y Atrás sin pérdida del borrador; corregir DNI repite identidad y descarta el PDF. No debe haber cargas ni altas antes del envío final. PDF vacío, renombrado o mayor de 5 MB impide enviar. La confirmación final muestra pendiente y salida a Préstamos, sin evaluación dentro del formulario. Luego, desde Solicitudes de préstamo, prueba aprobar, observar, corregir/reenviar y rechazar. Otra agencia no debe leer expediente ni descargar PDF. Un envío pendiente no reserva capital; consumir cupo antes de aprobar debe bloquearlo. La simulación no es cobrable y la fecha definitiva nace al aprobar. Repetir el RUC retoma su solicitud abierta. RUC 10 continúa sin certificado. En Clientes, DNI/RUC 10 aparece en ambos filtros y una sola vez en Todos.

Desde `app/tests`, `node servidor-pruebas.mjs --serve` levanta el servicio aislado en `127.0.0.1:54329`, con tokens y sesiones ficticios. Su ruta `/__sesion` permite simular antigüedad para pruebas; no existe en la aplicación publicada. Este servicio no sustituye al proveedor externo ni se despliega a producción.

Una edición exclusivamente documental se verifica comparando Markdown y Word, enlaces, criterios y paginación; no necesita registrar préstamos o cobros.
