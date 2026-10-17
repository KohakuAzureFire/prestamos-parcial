# Pruebas de operaciones

Las suites usan PostgreSQL en memoria mediante PGlite, roles, RLS y pgcrypto. Los datos de `fixtures.json` y la tasa del 12 % son ficticios; no conectan con Supabase real ni requieren sus claves. Se probaron con Node.js 24.

## Preparación y ejecución

Desde `app/tests`:

```powershell
npm.cmd ci
npm test
```

`npm test` ejecuta `agencias.test.mjs`, `borradores.test.mjs` y `ruc.test.mjs`: cartera por agencia, identidad, alta conjunta, rollback, firmas, capital global, pagos, mora e idempotencia.

Las siguientes suites se ejecutan **aparte desde `app`**:

| Comando | Comprobación principal |
| --- | --- |
| `node tests/modalidad.test.mjs` | Préstamo personal por DNI con RUC 10 asociado, modalidad contractual y cupo compartido. |
| `node tests/revalidacion-pagos.test.mjs` | Revalidación RUC firmada, consulta global, cobro cruzado y exclusión del representante como propietario. |
| `node tests/fichas-grupo.test.mjs` | Identidad y vínculos compartidos, permisos, cartera local y pagos equivalentes por DNI/RUC 10/RUC 20. |
| `node tests/sesiones.test.mjs` | Inactividad, actividad válida, sondeo sin renovación, sesión reemplazada y cierre antiguo que no revoca la nueva. |
| `node tests/contrato.test.mjs` | Word, campos variables y escape XML; solo escribe salida si se configura `CONTRATO_PRUEBA_SALIDA`. |

PGlite serializa transacciones: probar selección obsoleta no equivale a una prueba de carga concurrente remota. Cada suite prepara su propia base; no se aplica el SQL de sesiones indiscriminadamente a pruebas antiguas sin identificador de sesión.

## Comprobación en navegador

Los casos funcionales están en `docs/REQUISITOS.md`, desde la raíz del repositorio: identidad, representación, pasos, límites, fichas, documentos, pagos con contexto y sesiones. Comprueba escritorio y móvil, regreso al origen, limpieza de resultados y desplazamiento al préstamo seleccionado.

Para sesiones, usa dos navegadores independientes: el segundo inicio debe bloquear al anterior; cerrar el anterior no debe cerrar el nuevo. Comprueba aviso, Continuar sesión y vencimiento. Los sondeos automáticos no deben prolongar la sesión.

Desde `app/tests`, `node servidor-pruebas.mjs --serve` levanta el servicio aislado en `127.0.0.1:54329`, con tokens y sesiones ficticios. Su ruta `/__sesion` permite simular antigüedad para pruebas; no existe en la aplicación publicada. Este servicio no sustituye al proveedor externo ni se despliega a producción.

Una edición exclusivamente documental se verifica comparando Markdown y Word, enlaces, criterios y paginación; no necesita registrar préstamos o cobros.
