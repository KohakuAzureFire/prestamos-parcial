# Clientes por agencia y actualización de datos

## Alcance

Esta revisión modifica la aplicación, sin cambios de esquema ni nuevas dependencias.
Supabase mantiene las fichas compartidas y las reglas financieras ya publicadas.

El listado /dashboard/clientes se construye con los titulares de préstamos confirmados
visibles mediante RLS en la agencia del asesor. Incluye préstamos ya pagados y clientes
que originalmente se registraron en otra agencia. Excluye registros sin préstamos
confirmados locales, empresas vinculadas sin cartera local y representantes sin préstamo
propio. La búsqueda y los filtros se aplican a ese listado, no al grupo compartido completo.
La lectura se pagina para evitar perder titulares por el límite de respuesta de Supabase.

La ficha y relaciones_cliente no se restringen: siguen mostrando los vínculos permitidos,
la identidad compartida y el capital global. La sección Préstamos conserva la cartera local; su tabla ya no se repite en la ficha. Consultar para pagar continúa reuniendo el grupo en todas las agencias.

## Revalidación

- DNI y RUC10: menú en la ficha con «Revalidar DNI» y «Actualizar datos SUNAT · RUC 10».
- Solo DNI: acceso directo a la revisión de identidad.
- RUC20: acceso directo a Actualizar datos SUNAT; identidades en las fichas vinculadas.
- La URL antigua /clientes/[id]/revalidar sin tipo para una persona redirige al DNI;
  ?tipo=ruc abre SUNAT. Ya no existe una página intermedia para elegir documento.
- Aprobada y Habilitado no desactivan la actualización. Habilitado es condición de pago.
- La revisión de DNI exige completar de nuevo las evidencias, sin confirmaciones marcadas.

## SUNAT

La pantalla consulta automáticamente. Compara razón social, estado, condición y domicilio
con lo guardado. Señala cada cambio y muestra su valor anterior. El domicilio tiene una
fila completa, también en móvil. Un guion de proveedor se muestra como dato no informado.
Los datos externos no se editan manualmente.

Si no hay cambios permite Registrar consulta SUNAT: guardar renueva la fecha y crea la
constancia de la nueva consulta. Guardar nunca es automático. Al guardar se vuelve a la
misma ficha con confirmación y se muestran las fechas de revisión/consulta en el bloque
existente. El botón queda bloqueado durante el envío; el servidor ya deduplica un mismo
payload firmado y asesor. Una nueva consulta legítima puede tener otro registro aunque
no haya cambiado la información.

Los errores distinguen autorización del proveedor, límite de consultas, RUC no encontrado
y fallo temporal. Ninguno de estos errores se guarda como identidad rechazada. Solo se
registra una consulta válida, firmada y confirmada por el asesor. Los estados SUNAT
observados se pueden guardar para reflejar la información real; pagar sigue permitido.
Se registra en el log solamente el código HTTP del proveedor, sin claves ni documentos.

## Validación

ESLint y compilación de producción. Recorrido con datos ficticios y Supabase local aislada:
dos agencias, cartera local, navegación al grupo, menú DNI/RUC, evidencia DNI sin autocompletar,
SUNAT sin cambios y con cambios firmados, doble clic, guardar un estado observado, fallo técnico,
consulta global de pagos y distribución en escritorio/móvil. No se crean préstamos reales
ni se usan claves de producción en las pruebas.

La consulta de nombres por DNI no actualiza una condición oficial de fallecimiento ni acredita vigencia documental por sí sola. Se registra caducidad y revisión presencial con referencias generadas. SUNAT se actualiza al consultar y guardar expresamente; no existe un proceso periódico externo. Revalidar continúa disponible aunque los datos anteriores estén aprobados o vigentes.

Una observación del RUC 10 bloquea una nueva solicitud por ese RUC, pero no la modalidad personal por DNI si cumple identidad, pagos, historial y cupo. En RUC 20 se comprueban el RUC de la empresa y las identidades y facultades correspondientes. La identidad observada de un propietario afecta las solicitudes que requieren esa identidad; el representante no aporta por sí solo su límite al grupo. Los errores técnicos no equivalen a observaciones acreditadas ni bloquean el cobro de deudas existentes.
