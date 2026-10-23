# Pruebas de operaciones

PostgreSQL aislado en memoria con PGlite, roles, RLS y pgcrypto, en Node.js 24. Datos ficticios; sin Supabase real ni consumo del proveedor.

Desde `app/tests`:

```powershell
npm.cmd ci
npm test
```

Ejecuta nueve suites: documentos-empresa, agencias, borradores, ruc, representaciones, solicitudes, contrato, api-peru y ruc20-directo. Las migraciones históricas permanecen como regresión; sus recorridos documentales no describen el flujo vigente.

## RUC 20 directo

`ruc20-directo.test.mjs` aplica hasta `20261023020208_ruc20_directo_representante.sql` y comprueba:

- DNI completo de un representante del RUC, varios representantes, datos ocultos o ajenos.
- Firma alterada, consulta vencida, otro asesor/RUC, presencia y reversión de altas fallidas.
- Confirmación sin solicitud ni archivo y reintento idempotente.
- Dos empresas del mismo representante y límite compartido con préstamos personales.
- Otro representante para la misma empresa sin cambiar deuda ni contrato anteriores.
- Cobro por DNI/RUC, RLS por agencia y cuotas cada 30 días.
- Atraso del responsable original, cobro cruzado y liberación solo de su capital amortizado.
- RPC documental anterior bloqueado y ejecución anónima denegada.

PGlite serializa transacciones; no equivale a prueba de carga concurrente remota. No generar datos ficticios en producción.

## API y contratos

`api-peru.test.mjs`: normalización, cliente HTTP y ruta real con proveedor simulado; varios representantes, ceros iniciales, máscaras, vacíos, errores, cuota agotada, sesión y firma. Fechas cada 30 días en cambios de mes, año y bisiestos; simulaciones históricas conservadas.

`contrato.test.mjs`: campos, XML seguro, identidad congelada, firma con nombre/DNI/calidad, RUC 20, DNI/RUC 10, copia incompleta y cierre en firmas. No cambia plantilla. Ejemplos ficticios de QA: `CONTRATOS_PRUEBA_DIR=/ruta/temporal node contrato.test.mjs`.

## Regresión histórica

Documentos-empresa verifica referencias retiradas. Representaciones y solicitudes prueban sus migraciones, Storage sintético, propietario pendiente y evaluación. Esas pruebas no habilitan nuevos préstamos por esa vía; la suite directa verifica su bloqueo.

Agencias, borradores y ruc cubren identidad, firmas, altas, privacidad, capital, pagos sin recargos y reintentos. Ruc comprueba ausencia de columnas, funciones y parámetros de cargos por atraso.

Pruebas adicionales desde `app`: `node tests/modalidad.test.mjs`, `node tests/revalidacion-pagos.test.mjs`, `node tests/fichas-grupo.test.mjs`, `node tests/sesiones.test.mjs`. Cada una usa su versión del esquema; no aplicar sesiones sin su contexto.

## Comprobación en navegador

RUC 20: consultar empresa, ingresar DNI, validar vínculo e identidad/presencia, condiciones, cronograma y confirmación. Sin propietario, documentación, certificado ni evaluación posterior. Antes de confirmar no crea personas ni empresa. Atrás conserva datos; cambiar DNI exige validar nuevamente. Revisar escritorio, móvil, foco y separación de botones.

Con cuenta real, comprobar múltiples representantes y DNI completo. Sin coincidencia completa o con fallo no continúa. Esta comprobación sigue pendiente: las respuestas simuladas no prueban datos ni cuota reales.

Repetir RUC permite otro préstamo y representante elegible sin trasladar deuda. Cobrar libera cupo del responsable original. Verificar también DNI/RUC 10 y cartera local.

Sesiones: dos navegadores, reemplazo, cierre antiguo que no revoca la nueva e inactividad de 15 minutos. Los sondeos no renuevan. `node servidor-pruebas.mjs --serve` inicia servicio aislado con sesiones ficticias; nunca publicar `__sesion`.

Antes de cerrar: lint/build, pruebas apropiadas, requisitos Markdown y Word sincronizados y paginación revisada. Entregar archivos no acredita migración ni despliegue.
