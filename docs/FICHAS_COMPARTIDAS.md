> Actualización: el listado Clientes ahora muestra solo titulares con préstamos confirmados en tu agencia. Los accesos a fichas y vínculos del grupo siguen compartidos. Ver OBSERVACIONES_CLIENTES_REVALIDACION.md.

# Fichas compartidas y grupo de pagos

## Comportamiento

La persona conserva un único registro por DNI; su RUC10 se agrega a ese registro. Cada empresa RUC20 conserva su registro independiente y su vínculo al propietario. No se fusionan persona y empresa ni se crean copias por agencia.

Las agencias que registraron o concedieron un préstamo a un miembro del grupo pueden consultar las fichas de ese propietario y sus empresas. Comparten nombres, documentos, vínculos, verificación, historial y capital global. Las fichas de grupos ajenos no aparecen mediante sus identificadores. Una persona que solo es representante no adquiere por ese vínculo el límite ni los préstamos de la empresa; su ficha solo se enlaza si la agencia tiene acceso a ella.

Todas las fichas usan los mismos bloques: titular, identificación, condición de pago, capital, personas y empresas vinculadas, préstamos de la agencia e historial aplicable. Persona: DNI y RUC10 si tiene. Empresa: razón social, RUC20, propietario y representante. Las fichas del grupo se pueden abrir desde el bloque de vínculos.

«Préstamos en tu agencia» sigue mostrando únicamente los préstamos del titular de esa ficha en la agencia actual. Los préstamos de otra agencia no se incorporan a la cartera local al ver una ficha o registrar un pago.

Consultar para pagar por DNI, RUC10 o cualquier RUC20 del propietario devuelve los mismos préstamos pendientes de todo el grupo entre agencias. El código PR- sigue consultando solo un préstamo. Cada deuda conserva titular, documento, agencia y cuotas; el cobro sigue siendo individual.

Desde una ficha, Pagos mantiene el documento fijo y ya no ofrece Cambiar cliente. Para otra búsqueda se entra a Pagos desde el menú. La búsqueda general conserva la limpieza inmediata de resultados y de la confirmación de cobro al editar documento o tipo; descarta respuestas tardías.

Solicitar préstamo despliega Personal · DNI y Negocio · RUC10 en la propia ficha cuando existen ambos documentos. Sin RUC10, el único flujo se abre directamente. Sin capital o sin elegibilidad, la acción permanece bloqueada.

Plazo muestra 0 inicialmente y permite solo dígitos enteros hasta 60; para continuar debe ser de 1 a 60. Monto conserva soles y centavos con punto fijo, solo dígitos, mínimo operativo 0.01 y máximo del capital disponible.

## Instalar

1. Detén el servidor local (Ctrl+C).
2. Descomprime el ZIP aparte. Conserva en tu proyecto app/.env.local, app/node_modules, app/templates y .git.
3. Elimina app/src y app/.next. Copia app/src y app/scripts del ZIP. Actualiza docs, las instrucciones y app/README.md. Si utilizas las pruebas, copia app/tests conservando sus dependencias.
4. En VS Code abre app/scripts/ACTUALIZAR_SISTEMA.sql. Dentro del archivo pulsa Ctrl+A y Ctrl+C para copiar TODO el código. No copies solo el nombre ni la ruta del archivo.
5. En el SQL Editor de tu proyecto Supabase abre una consulta nueva, pega el código completo y pulsa Run. El resultado esperado es Success, sin filas devueltas. Este único archivo incluye los ajustes anteriores y la revisión actual; no hace falta ejecutar los otros scripts por separado. Es repetible y no modifica préstamos, contratos, importes ni pagos existentes. No se aplicó al proyecto real desde este chat.
6. Desde app ejecuta npm.cmd run dev. No hay dependencias ni variables nuevas; no necesitas npm.cmd ci si conservas las dependencias de la versión anterior.

## Pruebas

Con Node 24, desde app: node tests/fichas-grupo.test.mjs. Utiliza PGlite aislado y comprueba misma identidad e historial en dos agencias, vínculos compartidos, consultas equivalentes por DNI/RUC10/RUC20, cartera local, ausencia de fichas ajenas, separación de representantes y repetición segura del SQL acumulado sin cambios en operaciones anteriores.

ruc.test.mjs carga la revisión actual y selecciona el préstamo por su identificador dentro de los resultados globales. Conserva las comprobaciones de firmas, pagos, mora, capital, autorización e idempotencia.
