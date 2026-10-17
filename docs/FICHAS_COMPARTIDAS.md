# Fichas compartidas y grupo de pagos

## Comportamiento

La persona conserva un único registro por DNI; su RUC10 se agrega a ese registro. Cada empresa RUC20 conserva su registro independiente y su vínculo al propietario. No se fusionan persona y empresa ni se crean copias por agencia.

Las agencias que registraron o concedieron un préstamo a un miembro del grupo pueden consultar las fichas de ese propietario y sus empresas. Comparten nombres, documentos, vínculos, verificación, historial y capital global. Las fichas de grupos ajenos no aparecen mediante sus identificadores. Una persona que solo es representante no adquiere por ese vínculo el límite ni los préstamos de la empresa; su ficha solo se enlaza si la agencia tiene acceso a ella.

Todas las fichas usan los mismos bloques: titular, identificación, condición de pago, capital y personas y empresas vinculadas. Los préstamos se consultan en Préstamos y los historiales se abren mediante Ver historial, fuera de la ficha. Persona: DNI y RUC10 si tiene. Empresa: razón social, RUC20, propietario y representante. Las fichas del grupo se pueden abrir desde el bloque de vínculos.

La ficha ya no muestra «Préstamos en tu agencia». La sección Préstamos conserva exclusivamente la cartera de la agencia actual. Clientes lista solo titulares con préstamos confirmados locales, incluidos los ya pagados; la existencia de un vínculo compartido o un pago ajeno no incorpora al titular al listado.

Consultar para pagar por DNI, RUC10 o cualquier RUC20 del propietario devuelve los mismos préstamos pendientes de todo el grupo entre agencias. El código PR- sigue consultando solo un préstamo. Cada deuda conserva titular, documento, agencia y cuotas; el cobro sigue siendo individual.

Desde una ficha, Pagos mantiene el documento fijo y ya no ofrece Cambiar cliente. Para otra búsqueda se entra a Pagos desde el menú. La búsqueda general conserva la limpieza inmediata de resultados y de la confirmación de cobro al editar documento o tipo; descarta respuestas tardías.

Solicitar préstamo despliega Personal · DNI y Negocio · RUC10 en la propia ficha cuando existen ambos documentos. Sin RUC10, el único flujo se abre directamente. Sin capital o sin elegibilidad, la acción permanece bloqueada.

Plazo muestra 0 inicialmente y permite solo dígitos enteros hasta 60; para continuar debe ser de 1 a 60. Monto conserva soles y centavos con punto fijo, solo dígitos, mínimo operativo 0.01 y máximo del capital disponible.

## Instalar

En la instalación existente ya se aplicaron las revisiones de fichas y pagos y, posteriormente, el control de sesiones. La sincronización documental no necesita SQL adicional. Copia solo los archivos entregados conservando los demás; no elimines `app/src`, `docs`, `.env.local` ni las dependencias. Sigue `../INSTRUCCIONES_ACTUALIZACION.md`.

Para una instalación nueva, consulta el orden de los scripts en `ESTADO_IMPLEMENTACION.md`. El SQL acumulado de fichas no contiene el control de sesiones y no debe reaplicarse como una actualización posterior a este.

## Pruebas

Con Node 24, desde app: node tests/fichas-grupo.test.mjs. Utiliza PGlite aislado y comprueba misma identidad e historial en dos agencias, vínculos compartidos, consultas equivalentes por DNI/RUC10/RUC20, cartera local, ausencia de fichas ajenas, separación de representantes y repetición segura del SQL acumulado sin cambios en operaciones anteriores.

ruc.test.mjs carga la revisión actual y selecciona el préstamo por su identificador dentro de los resultados globales. Conserva las comprobaciones de firmas, pagos, mora, capital, autorización e idempotencia.
