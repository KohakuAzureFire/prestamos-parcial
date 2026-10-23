# Pruebas de operaciones

Las suites usan PostgreSQL en memoria mediante PGlite, roles, RLS y pgcrypto. Los datos de `fixtures.json` son ficticios; no conectan con Supabase real ni requieren sus claves. Se probaron con Node.js 24.

## Preparación y ejecución

Desde `app/tests`:

```powershell
npm.cmd ci
npm test
```

`npm test` ejecuta `documentos-empresa.test.mjs`, `agencias.test.mjs`, `borradores.test.mjs`, `ruc.test.mjs` , `representaciones.test.mjs` , `solicitudes.test.mjs` y `contrato.test.mjs`: cartera por agencia, identidad, alta conjunta, rollback, firmas, capital global, pagos sin recargos, atrasos e idempotencia.

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

### Referencias guiadas de documentos

`node documentos-empresa.test.mjs` (también incluido en `npm test`) comprueba los cuatro tipos, recuperación de campos al corregir, formato v1 compatible, ceros iniciales, asientos alfanuméricos, fechas de calendario, datos incompletos y conservación de referencias anteriores sin interpretación ambigua. No usa Decolecta ni la base de producción.

Revisión manual tras publicar: seleccionar cada tipo, completar sus campos, volver desde Condiciones para comprobar que se conservan, revisar una solicitud observada con referencia anterior y verificar el espaciado de Solicitudes en escritorio y móvil.

Las pruebas de documentos también verifican los límites de cada campo, rechazo de caracteres inválidos en entradas escritas o pegadas, nombres con tildes, campos vacíos y referencias antiguas más extensas. En navegador, probar pegar valores con letras en partida, signos en asiento y valores demasiado largos: el campo debe conservar el valor previo y explicar el rechazo.

Para la revisión visual, comprobar que Corregir DNI del propietario y del representante esté junto al título, con lápiz, fondo transparente y foco visible; en móvil, debajo del título. No debe aparecer Ir a clientes en Nuevo préstamo. Los filtros de Solicitudes deben quedar separados de la tabla. Estos casos forman parte de los requisitos y su Word.

## Verificación pendiente del propietario

`solicitudes.test.mjs` aplica también `20261022201553_propietario_ausente_pendiente.sql`. Cubre propietario ausente nuevo y con DNI vencido, nombres no confiables ignorados, representante nuevo registrado solo al enviar, ausencia de identidad ficticia y empresa nueva, solicitud sin deuda, estado determinado por servidor, bloqueo de aprobación directa, duplicados entre agencias, privacidad y rechazo de sustitución del propietario. Completar exige evidencia presencial, mantiene el PDF y la solicitud, evita duplicar la revisión y preserva observaciones e historial. Comprueba que anon no ejecute la nueva función y que authenticated no modifique directamente la tabla.

Revisión en navegador: con otro representante seleccionado, escribir el DNI del propietario debe mostrar un aviso bajo el campo, deshabilitar Verificar representante y no iniciar consultas. Otro DNI válido retira el aviso. Enviar con propietario ausente nuevo o vencido debe terminar en Pendiente de verificación del propietario, sin deuda. Después, con el propietario presente, completar su revisión desde Solicitudes; comprobar el mismo certificado y la evaluación posterior separada. Rechazar u observar siguen disponibles sin aprobar.

### Regresión: guardar la verificación del propietario

`solicitudes.test.mjs` ejecuta la ruta real de completar propietario con proveedor y sesión simulados, conectada a la base aislada. Comprueba la respuesta HTTP 200, la vinculación del propietario, el certificado conservado y la ausencia de un préstamo nuevo. Detecta la omisión de `p_consulta.ruc` que provocaba «RUC o solicitud inválida». La API toma ese RUC de la solicitud guardada y mantiene su comprobación contra la consulta firmada. No consulta Decolecta ni producción.

## Evaluación guiada y contratos

La suite de solicitudes aplica `20261022205543_simplificar_evaluacion_contrato_ruc20.sql`. Prueba aprobación sin observaciones por SQL y por la ruta real, motivo obligatorio al observar o rechazar, código inválido rechazado antes del proveedor, ceros iniciales, referencia del expediente conservada y registro de revisor y fecha. Conserva pruebas de agencia, sesión, verificación pendiente, facultades, firma individual, cupo e idempotencia.

`contrato.test.mjs` forma parte de `npm test`. Verifica Word e impresión, razón social, firma con nombre/DNI/calidad, ambos casos RUC 20, DNI y RUC 10, falta de copia del representante y documento hasta firmas. La suite SQL comprueba la copia contractual de préstamos aprobados con propietario que firma o representante distinto y que cambios posteriores en la ficha no alteren los campos originales.

Para generar ejemplos ficticios de revisión visual: `CONTRATOS_PRUEBA_DIR=/ruta/temporal node contrato.test.mjs`. Son archivos de QA; no se incluyen como contratos reales ni se cargan a producción.

## Representantes y cuotas de 30 días

`api-peru.test.mjs` integra normalización, cliente HTTP y ruta real con respuestas simuladas: varios representantes, DNI con ceros, enmascarados, vacíos, respuestas inválidas, cuota agotada, autorización, sesión y firma. No hace consultas externas. Comprueba fechas de 30, 60 y 90 días en cambios de mes, año y bisiestos, y conserva el modo mensual de simulaciones anteriores. Está incluido en npm test.

La suite de solicitudes aplica la migración de API y 30 días. Comprueba selección firmada, índice inválido, firma alterada, DNI seleccionado diferente al firmante y cronogramas definitivos de ambos casos RUC 20 a intervalos de 30 días. Revisión en navegador pendiente con API_PERU_TOKEN real: listado de varios, selección expresa, volver entre pasos, quitar selección, datos ocultos, caída y cuota agotada; sin generar préstamos ficticios en producción.
