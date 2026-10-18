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

Esta actualización prepara el retiro de cargos por atraso. En el proyecto existente se aplica únicamente `supabase/migrations/20261018210722_retirar_cargos_y_ajustar_contrato.sql`, coordinado con la publicación del código. No reapliques los scripts antiguos sobre la base actualizada.

Para otra instalación sobre el esquema inicial compatible:

1. Aplicar las migraciones históricas de `supabase/migrations` anteriores a `20261018`, en orden cronológico.
2. Aplicar `scripts/habilitar_modalidad_personal.sql`.
3. Aplicar `scripts/revalidacion_y_pagos_globales.sql`.
4. Aplicar `scripts/fichas_compartidas_y_grupo_pago.sql`.
5. Aplicar `scripts/control_sesiones.sql`.
6. Aplicar al final `supabase/migrations/20261018210722_retirar_cargos_y_ajustar_contrato.sql`.

Las migraciones presuponen el esquema inicial; las pruebas lo construyen explícitamente. `scripts/ACTUALIZAR_SISTEMA.sql` es una alternativa acumulada de los ajustes previos de modalidad, fichas y pagos, pero no incluye sesiones. No lo reapliques después del control de sesiones: reemplazaría su autorización central. `docs/archivo/007_no_aplicada.sql` es histórico y no se ejecuta.

El permiso `autoriza_credito` se asigna administrativamente en `private.permisos_operacion`; no es editable desde el navegador ni se concede automáticamente. No existe configuración de recargos por atraso. Las migraciones y scripts antiguos se conservan como etapas de instalación e historial; el retiro final elimina sus campos, parámetros y funciones obsoletos.

## Contrato y consultas

`docs/Contrato_profesor.docx` conserva el original; `templates/contrato.docx` y `templates/contrato-texto.json` alimentan descarga e impresión. La plantilla generada termina en las firmas, sin anexo de condiciones, y aplica únicamente el interés compensatorio del cronograma. Conserva esas plantillas. Las menciones del original a EFS/Préstamos Castillo, una cláusula décimo sexta ausente o módulos fuera del sprint no crean funciones ni cargos en la aplicación.

La consulta DNI obtiene nombres; caducidad y presencia se acreditan mediante revisión del asesor. SUNAT se actualiza al consultar y guardar, sin proceso periódico externo. Las respuestas requieren proveedor y firma configurados. Un error técnico no se guarda como rechazo de identidad.

## Publicación

El usuario publica en GitHub y la integración de Vercel despliega `main`. Vercel usa `app` como raíz y las cuatro variables del entorno correspondiente. Verifica la compilación, el login, las rutas protegidas y un recorrido autorizado. No registres operaciones reales para comprobar una edición documental.

Conserva únicamente `docs/REQUISITOS.md`, su Word, este README y `tests/README.md` como documentación del sistema. El contrato original y las plantillas permanecen. `AGENTS.md` contiene instrucciones de desarrollo generadas por Next.js y no forma parte de los tres Markdown de documentación.
