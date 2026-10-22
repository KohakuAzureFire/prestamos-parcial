# Aplicación de préstamos

Sistema académico del Sprint 1 para cinco agencias del Perú. Reglas, flujos, ocho HU y criterios de aceptación están en [REQUISITOS.md](../docs/REQUISITOS.md) y [su Word equivalente](../docs/Sprint_1_Sistema_Prestamos.docx). Las pruebas se describen en [tests/README.md](tests/README.md).

## Ejecución local

Usa Node.js 24, versión utilizada en las pruebas. Desde `app`, instala con `npm.cmd ci` si es la primera ejecución o cambió `package-lock.json`. Conservando las mismas dependencias, una actualización documental no necesita reinstalarlas.

Crea `app/.env.local` con los valores del proyecto:

| Variable | Uso |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | URL del proyecto Supabase. |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Clave pública del cliente. |
| `DECOLECTA_API_TOKEN` | Token del proveedor de consulta; solo servidor. |
| `IDENTITY_SIGNING_SECRET` | Clave de firma de identidad, coincidente con la configuración privada de la base; solo servidor. |

No publiques `.env.local`. Los valores de prueba local no sirven para producción. La configuración inicial de firma utiliza `scripts/configurar-identidad.mjs`; no cambies una firma operativa por actualizar documentos.

Desde `app`:

```powershell
npm.cmd run dev
```

Para verificar código: `npm.cmd run lint` y `npm.cmd run build`. Para servir la compilación: `npm.cmd start`. Si la caché se daña, detén el servidor y retira solo `app/.next`; conserva `src`, plantillas, variables y dependencias.

## Base de datos

Esta actualización prepara solicitudes completas de préstamo RUC 20. En el proyecto existente, que ya tiene revisión de representación, se ejecuta una sola vez `supabase/migrations/20261022170855_solicitudes_prestamo_ruc20.sql`, coordinado con la publicación del código. Crea solicitudes e historial, RLS y funciones para enviar y evaluar; conserva clientes, préstamos y pagos existentes. No reapliques SQL antiguos sobre la base actualizada. No requiere nuevas variables ni dependencias.

Para otra instalación sobre el esquema inicial compatible:

1. Aplicar las migraciones históricas de `supabase/migrations` anteriores a `20261018`, en orden cronológico.
2. Aplicar `scripts/habilitar_modalidad_personal.sql`.
3. Aplicar `scripts/revalidacion_y_pagos_globales.sql`.
4. Aplicar `scripts/fichas_compartidas_y_grupo_pago.sql`.
5. Aplicar `scripts/control_sesiones.sql`.
6. Aplicar `supabase/migrations/20261018210722_retirar_cargos_y_ajustar_contrato.sql`.
7. Aplicar `supabase/migrations/20261019194843_revision_representacion_ruc20.sql`, con Storage disponible.
8. Aplicar `supabase/migrations/20261022170855_solicitudes_prestamo_ruc20.sql`.

Las migraciones presuponen el esquema inicial; las pruebas lo construyen explícitamente. `scripts/ACTUALIZAR_SISTEMA.sql` es una alternativa acumulada de los ajustes previos de modalidad, fichas y pagos, pero no incluye sesiones. No lo reapliques después del control de sesiones: reemplazaría su autorización central. `docs/archivo/007_no_aplicada.sql` es histórico y no se ejecuta.

Cada asesor activo puede enviar y evaluar solicitudes RUC 20 de su agencia, incluidas las suyas. No se crea un rol adicional ni se requiere conceder `autoriza_credito`; ese permiso conserva su función independiente de regularización especial. La base impide consultar expedientes o evaluar solicitudes de otras agencias. El buscador de RUC solo informa si hay una solicitud abierta en otra agencia y dónde atenderla. Las migraciones previas se conservan como historial; no hay configuración de recargos por atraso.

## Clientes y representación de empresas

En Clientes, una ficha DNI/RUC 10 aparece en Personas con DNI y en Negocios y empresas con RUC; Todos conserva una sola fila con ambos documentos. Se mantiene la cartera local y el capital global de la ficha. El filtro de titulares de Préstamos conserva su significado contractual.

RUC 20 recorre Identificación → Documentación → Condiciones → Cronograma y envío. Permite corregir DNI durante identificación y repite su verificación; nombres externos no se editan. Una empresa registrada conserva propietario para el límite; en otra solicitud puede usar otro representante verificado. Corregir personas descarta el PDF asociado. Atrás conserva el borrador, sus condiciones y el archivo seleccionado; abandonar descarta lo no enviado. DNI/RUC 10 mantiene su flujo.

El selector admite copia literal de la empresa, escritura pública de constitución, acto constitutivo de SACS y copia certificada de matrícula de acciones, según el vínculo que debe acreditarse. La referencia identifica el documento; no acredita propiedad por sí misma. El certificado de vigencia de poder SUNARP corresponde al firmante y se presenta aparte como PDF de hasta 5 MB. Los documentos cumplen fines diferentes; el asesor revisa pertinencia, autenticidad y contenido. Este flujo admite firma individual.

Antes del envío no hay cargas ni nuevas altas desde el borrador RUC 20. Al pulsar Enviar solicitud de préstamo comienza la carga privada y la reserva técnica del archivo; el servidor comprueba formato básico y SHA-256 y firma el recibo con `IDENTITY_SIGNING_SECRET`. Una transacción valida identidad, registra personas y empresa cuando corresponde, finaliza el PDF y guarda la solicitud pendiente con monto, plazo y simulación. Un fallo revierte el expediente y las altas; una carga técnica incompleta no aparece como solicitud ni préstamo. Reintentar conserva la clave para evitar duplicados. No se crean préstamos, cuotas cobrables o contratos definitivos al enviar, ni se reserva capital.

La pantalla final informa el envío y regresa a Préstamos. La evaluación se abre después desde Solicitudes de préstamo: el asesor contrasta documentos y facultades, registra referencia, firma individual y sustento y aprueba, observa o rechaza. Solo aprobar genera el préstamo y el cronograma desde la fecha de aprobación. Antes consulta nuevamente SUNAT y comprueba identidad vigente, atrasos, conciliación y capital global de S/ 10 000. Un fallo conserva la solicitud pendiente y revierte la aprobación. No se atribuye un plazo legal de caducidad al certificado.

Solo puede existir una solicitud pendiente u observada por RUC 20 entre agencias. Al repetir la consulta se abre su detalle, o se informa la agencia que la atiende. Observada se corrige y reenvía con la misma identidad de solicitud y un nuevo PDF; el historial conserva cada presentación y certificado. Rechazada permite una nueva solicitud; aprobada conserva su préstamo y permite otra si hay elegibilidad y cupo. No se modifica ni se elimina ninguna operación anterior.

Las rutas antiguas de representación quedan para consulta histórica; el listado redirige a Solicitudes de préstamo. Las nuevas colocaciones RUC 20 requieren evaluar una solicitud, incluso si se intenta llamar directamente al RPC antiguo.

## Contrato y consultas

`docs/Contrato_profesor.docx` conserva el original; `templates/contrato.docx` y `templates/contrato-texto.json` alimentan descarga e impresión. La plantilla generada termina en las firmas, sin anexo de condiciones, y aplica únicamente el interés compensatorio del cronograma. Conserva esas plantillas. Las menciones del original a EFS/Préstamos Castillo, una cláusula décimo sexta ausente o módulos fuera del sprint no crean funciones ni cargos en la aplicación.

La consulta DNI obtiene nombres; caducidad y presencia se acreditan mediante revisión del asesor. SUNAT se actualiza al consultar y guardar, sin proceso periódico externo. Las respuestas requieren proveedor y firma configurados. Un error técnico no se guarda como rechazo de identidad.

## Publicación

El usuario publica en GitHub y la integración de Vercel despliega `main`. Vercel usa `app` como raíz y las cuatro variables del entorno correspondiente. Verifica la compilación, el login, las rutas protegidas y un recorrido autorizado. No registres operaciones reales para comprobar una edición documental.

Prepara estos commits en una rama de trabajo. La migración y la publicación de `main` requieren coordinación: el código de representación necesita las nuevas tablas y el bucket. La entrega del ZIP no implica haber aplicado SQL ni haber desplegado en Supabase o Vercel.

Conserva únicamente `docs/REQUISITOS.md`, su Word, este README y `tests/README.md` como documentación del sistema. El contrato original y las plantillas permanecen. `AGENTS.md` contiene instrucciones de desarrollo generadas por Next.js y no forma parte de los tres Markdown de documentación.

### Ajustes de interfaz del 22/10/2026

- Documentación de empresa: campos por tipo (partida y asiento; escritura, fecha y notaría; partida y fecha del acto SACS; libro, folio y asiento de matrícula). La referencia se arma automáticamente. Los números conservan ceros iniciales y los asientos admiten letras y números.
- Las referencias existentes se recuperan en campos solo si la conversión es exacta; las demás se conservan y muestran una opción explícita para corregirlas. Se mantiene el formato v1 de la evidencia, sin migración de base de datos.
- Nuevo préstamo ya no muestra el enlace «Ir a clientes». Se conservan la navegación interna y la advertencia al salir con un borrador.
- Los filtros de Solicitudes tienen separación de la tabla, también en pantallas pequeñas.
