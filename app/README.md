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

Esta actualización prepara la revisión de representación de RUC 20. En el proyecto existente, que ya tiene aplicado el retiro de cargos, se ejecuta una sola vez `supabase/migrations/20261019194843_revision_representacion_ruc20.sql`, coordinado con la publicación del código. Crea las solicitudes, su historial y el bucket privado `certificados-representacion` con sus políticas; no requiere crear un bucket público ni cambiar variables. No reapliques los scripts antiguos sobre la base actualizada.

Para otra instalación sobre el esquema inicial compatible:

1. Aplicar las migraciones históricas de `supabase/migrations` anteriores a `20261018`, en orden cronológico.
2. Aplicar `scripts/habilitar_modalidad_personal.sql`.
3. Aplicar `scripts/revalidacion_y_pagos_globales.sql`.
4. Aplicar `scripts/fichas_compartidas_y_grupo_pago.sql`.
5. Aplicar `scripts/control_sesiones.sql`.
6. Aplicar `supabase/migrations/20261018210722_retirar_cargos_y_ajustar_contrato.sql`.
7. Aplicar `supabase/migrations/20261019194843_revision_representacion_ruc20.sql`, con Storage disponible.

Las migraciones presuponen el esquema inicial; las pruebas lo construyen explícitamente. `scripts/ACTUALIZAR_SISTEMA.sql` es una alternativa acumulada de los ajustes previos de modalidad, fichas y pagos, pero no incluye sesiones. No lo reapliques después del control de sesiones: reemplazaría su autorización central. `docs/archivo/007_no_aplicada.sql` es histórico y no se ejecuta.

El permiso `autoriza_credito` se asigna administrativamente en `private.permisos_operacion`; también habilita la revisión documental de las cinco agencias. No es editable desde el navegador ni se concede automáticamente. Los demás asesores ven las solicitudes de su agencia. No existe configuración de recargos por atraso. Las migraciones y scripts antiguos se conservan como etapas de instalación e historial; el retiro final elimina sus campos, parámetros y funciones obsoletos.

## Clientes y representación de empresas

En Clientes, una ficha DNI/RUC 10 aparece en Personas con DNI y en Negocios y empresas con RUC; Todos conserva una sola fila con ambos documentos. Se mantiene la cartera local y el capital global de la ficha. El filtro de titulares de Préstamos conserva su significado contractual.

RUC 20 exige identificar al propietario del grupo y al representante que firma, revisar propiedad/designación y presentar un certificado de vigencia de poder de SUNARP. Solo admite PDF de hasta 5 MB, con comprobación de extensión, tipo, tamaño y formato básico en el servidor. La carga va directamente al almacenamiento privado; el servidor registra una huella SHA-256 y firma el recibo con `IDENTITY_SIGNING_SECRET`. El PDF presentado no se puede sustituir ni borrar desde el navegador y se descarga con autorización; no tiene URL pública. Esta comprobación técnica no acredita autenticidad.

Enviar guarda una solicitud pendiente, sin crear cliente ni préstamo. Desde Representación de empresas, un asesor autorizado contrasta autenticidad y facultades, anota referencia y sustento, y deja el resultado Revisada u Observada. Para Revisada registra importe máximo, firma individual y fecha de revisión válida hasta 30 días por política académica; ese plazo no constituye caducidad legal del certificado. Las firmas conjuntas quedan fuera de este flujo. Una observación o nueva presentación retira la revisión anterior para préstamos futuros; el historial permanece.

Al retomar se consultan datos vigentes. Solo la última presentación revisada de la agencia, para el mismo RUC, propietario y firmante, permite continuar dentro del importe revisado. La base repite esos controles al confirmar. Revisar representación no aprueba crédito: siguen identidad, elegibilidad y el límite de S/ 10 000 compartido entre persona y todas sus empresas en las cinco agencias. RUC 10 no exige certificado. Los préstamos y pagos anteriores permanecen.

## Contrato y consultas

`docs/Contrato_profesor.docx` conserva el original; `templates/contrato.docx` y `templates/contrato-texto.json` alimentan descarga e impresión. La plantilla generada termina en las firmas, sin anexo de condiciones, y aplica únicamente el interés compensatorio del cronograma. Conserva esas plantillas. Las menciones del original a EFS/Préstamos Castillo, una cláusula décimo sexta ausente o módulos fuera del sprint no crean funciones ni cargos en la aplicación.

La consulta DNI obtiene nombres; caducidad y presencia se acreditan mediante revisión del asesor. SUNAT se actualiza al consultar y guardar, sin proceso periódico externo. Las respuestas requieren proveedor y firma configurados. Un error técnico no se guarda como rechazo de identidad.

## Publicación

El usuario publica en GitHub y la integración de Vercel despliega `main`. Vercel usa `app` como raíz y las cuatro variables del entorno correspondiente. Verifica la compilación, el login, las rutas protegidas y un recorrido autorizado. No registres operaciones reales para comprobar una edición documental.

Prepara estos commits en una rama de trabajo. La migración y la publicación de `main` requieren coordinación: el código de representación necesita las nuevas tablas y el bucket. La entrega del ZIP no implica haber aplicado SQL ni haber desplegado en Supabase o Vercel.

Conserva únicamente `docs/REQUISITOS.md`, su Word, este README y `tests/README.md` como documentación del sistema. El contrato original y las plantillas permanecen. `AGENTS.md` contiene instrucciones de desarrollo generadas por Next.js y no forma parte de los tres Markdown de documentación.
