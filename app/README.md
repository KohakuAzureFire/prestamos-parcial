# Aplicación de préstamos

Sistema académico para cinco agencias del Perú. Las ocho HU están en [REQUISITOS.md](../docs/REQUISITOS.md) y [su Word](../docs/Sprint_1_Sistema_Prestamos.docx). Las pruebas están en [tests/README.md](tests/README.md).

## Ejecución local

Usa Node.js 24. Desde `app`: `npm.cmd ci`, `npm.cmd run dev`. Verificación: `npm.cmd run lint` y `npm.cmd run build`. Servir compilación: `npm.cmd start`.

Configura `app/.env.local` sin versionarlo:

| Variable | Uso |
| --- | --- |
| NEXT_PUBLIC_SUPABASE_URL | URL del proyecto. |
| NEXT_PUBLIC_SUPABASE_ANON_KEY | Clave pública del cliente. |
| API_PERU_TOKEN | API Key de apiperu.pe, solo servidor. |
| DECOLECTA_API_TOKEN | DNI y datos tributarios, solo servidor. |
| IDENTITY_SIGNING_SECRET | Firma coincidente con la configuración privada de la base. |

La firma inicial usa `scripts/configurar-identidad.mjs`. No reemplaces una firma operativa por actualizar código. Ante un fallo de caché, detén el servidor y retira solo `app/.next`.

## Nuevo préstamo RUC 20

Cliente → Condiciones → Cronograma → Confirmar préstamo. Se consulta el RUC ACTIVO/HABIDO, se ingresa el DNI de quien solicita y firma y se comprueba su coincidencia completa con un representante devuelto por API Perú para esa empresa. Después se verifica identidad vigente y presencia. No se pide propietario, referencia documental, certificado ni PDF; tampoco hay envío pendiente ni evaluación posterior.

La API puede devolver varias personas. Se verifica al firmante ingresado. Respuesta sin coincidencias, caída o DNI enmascarado impide continuar. El sistema no reconstruye dígitos ni presenta la consulta como certificación del alcance de poderes.

La consulta se ejecuta al pulsar el botón, se firma por asesor y RUC y vence a los 30 minutos. El servidor repite la comprobación al confirmar. Renovarla elimina la selección; cambiar DNI exige comprobar nuevamente vínculo e identidad.

El borrador permanece en memoria hasta confirmar. La transacción registra personas y empresa cuando corresponda, préstamo, copia contractual y cuotas, o revierte todo. Los reintentos conservan la clave para evitar duplicados.

## Límite por representante

Cada préstamo RUC 20 guarda `prestamos.responsable_id` con su representante. Préstamos personales, RUC 10 y los de varias empresas suman al límite global de S/ 10 000 entre las cinco agencias. Solo amortización pagada libera cupo. Otro representante para el siguiente préstamo no cambia deuda, contrato ni responsabilidad anteriores.

La empresa mantiene ficha propia y representante actual para futuras atenciones. Clientes incorpora empresa y representante por préstamos locales; un cobro ajeno no amplía la cartera. Préstamos conserva la agencia de origen y permite buscar por DNI del responsable. Pagos por DNI/RUC 10 reúne sus operaciones; por RUC 20 muestra solo esa empresa, aunque tenga varios representantes.

Es una regla académica de límite; no constituye automáticamente garantía personal. Los registros anteriores conservan sus responsables mediante compatibilidad con el propietario histórico.

## Base de datos

Sobre la versión publicada `ddc41b2`, aplicar una vez `supabase/migrations/20261023020208_ruc20_directo_representante.sql`, coordinado con el código. Agrega origen de empresa y responsable por préstamo, ajusta saldos, cobros, relaciones y vistas y crea `confirmar_empresa_api`. Conserva datos. No requiere nuevas variables ni dependencias; API_PERU_TOKEN debe estar en Vercel.

Instalación compatible desde el esquema inicial, en orden:

1. Migraciones históricas anteriores a `20261018`.
2. `scripts/habilitar_modalidad_personal.sql`.
3. `scripts/revalidacion_y_pagos_globales.sql`.
4. `scripts/fichas_compartidas_y_grupo_pago.sql`.
5. `scripts/control_sesiones.sql`.
6. Migración `20261018210722_retirar_cargos_y_ajustar_contrato.sql`.
7. `20261019194843_revision_representacion_ruc20.sql`, con Storage disponible.
8. `20261022170855_solicitudes_prestamo_ruc20.sql`.
9. `20261022201553_propietario_ausente_pendiente.sql`.
10. `20261022205543_simplificar_evaluacion_contrato_ruc20.sql`.
11. `20261023013114_api_representantes_cuotas_30_dias.sql`.
12. `20261023020208_ruc20_directo_representante.sql`.

No reapliques scripts antiguos sobre el esquema actualizado. `scripts/ACTUALIZAR_SISTEMA.sql` no incluye sesiones; aplicarlo después sustituiría su autorización central. `docs/archivo/007_no_aplicada.sql` es histórico.

Solicitudes documentales anteriores se conservan como historial; el menú las retira y se bloquean nuevos envíos/evaluaciones para impedir eludir la validación API. No se eliminan sus tablas, archivos ni historial. Las suites históricas prueban sus versiones del esquema; la suite directa aplica las migraciones nuevas.

## Contrato y cronograma

El contrato usa empresa, RUC, nombre y DNI del representante guardados en cada préstamo, aunque la ficha cambie. Mantiene formato del profesor y termina en firmas, sin anexo. Se conservan `docs/Contrato_profesor.docx`, `templates/contrato.docx` y `templates/contrato-texto.json`. Sin copia completa del firmante se bloquea la emisión.

Cuotas nuevas: 30, 60, 90 días desde la confirmación. TEA 30 %, sistema francés, tasa por período `(1 + 0,30)^(30/360) − 1`. No se cambian cronogramas anteriores ni el umbral extrajudicial de doce meses calendario. No se cobran recargos por atraso.

## API y publicación

Proveedor: https://apiperu.pe/; contrato técnico: https://docs.apiperu.pe/openapi.json. Endpoint `POST https://api.apiperu.pe/ruc/representantes`, Bearer token, JSON con `ruc`. El ejemplo oficial tiene datos ocultos; la cuenta real debe devolver DNI completo para validar.

API_PERU_TOKEN debe ser secreto de servidor, sin NEXT_PUBLIC_. No copiar tokens a chats ni archivos versionados. Pruebas con respuestas simuladas; falta consulta autenticada con la cuenta real para comprobar cobertura y cuota.

El usuario sube a GitHub; después se verifica el commit y se coordina migración y Vercel. Raíz: `app`. No registrar operaciones ficticias en producción. Entregar ZIP no acredita publicación.

Documentación: este README, `tests/README.md`, requisitos y su Word. AGENTS.md contiene instrucciones de desarrollo de Next.js.
