# Estado de implementación del sistema de préstamos

Actualizado el 17 de octubre de 2026. Proyecto académico del examen parcial, contrastado con los 137 archivos de GitHub en el código `5723a1385559f3e60d003c74395f9d3ae5edbda5`. Se conserva Cliente → Condiciones → Cronograma y se documenta la versión integrada, sin presentar instrucciones anteriores como pasos pendientes.

`REQUISITOS.md` y `Sprint_1_Sistema_Prestamos.docx` contienen las reglas, las ocho HU y sus criterios de aceptación. Los documentos de interfaz explican las mismas reglas aplicadas a cada pantalla. `../INSTRUCCIONES_ACTUALIZACION.md` indica los archivos de esta revisión exclusivamente documental.

## Funcionalidades integradas

| Área | Comportamiento |
| --- | --- |
| Acceso | Cuenta activa con agencia asignada. Una sesión por cuenta, 15 minutos sin actividad, contador después de nombre/rol, agencia y fecha. Aviso del último minuto con Continuar sesión; validación en rutas, API y autorización de base de datos. |
| Identidad | DNI peruano de 8 dígitos y RUC 10 o 20 de 11 dígitos con dígito verificador. Las respuestas de consulta se firman, se vinculan al asesor y caducan a los 30 minutos para su confirmación. No se admiten documentos extranjeros ni otros prefijos RUC. |
| Verificación presencial | Caducidad y dos casillas para DNI original y presencia. Se generan referencias descriptivas sin pedir al asesor escribir evidencia de vigencia o vida. La presencia no se presenta como consulta oficial de fallecimiento. |
| Persona con negocio | DNI y RUC 10 comparten ficha. Se elige Personal DNI o Negocio RUC 10 en Solicitar préstamo. La modalidad personal no exige el estado SUNAT de su RUC; la solicitud por RUC exige una consulta válida ACTIVO/HABIDO. |
| Empresa | Ficha RUC 20 independiente, propietario responsable del límite y firmante con facultades. Puede firmar el propietario o un representante distinto. El propietario ausente solo reutiliza identidad previa aprobada y vigente; el firmante debe estar presente. |
| Evidencia empresarial | Tipo y referencia breve de propiedad/designación y facultades. Un mismo documento puede acreditar ambas con confirmaciones separadas. Se recuperan referencias anteriores y se exige revisarlas para la nueva operación. Varios propietarios requieren designación documentada del responsable del límite. |
| Capital | S/ 10 000 para propietario y empresas vinculadas entre agencias. Solo el capital amortizado libera cupo. El representante sin propiedad no integra por ese solo vínculo su capital o deuda al grupo. |
| Monto y plazo | Monto inicial 0.00 con punto fijo, solo dígitos y mínimo operativo S/ 0.01 hasta el disponible. Plazo inicial 0 y validación de entero de 1 a 60. Servidor repite las restricciones. |
| Pasos | Tipo de cliente seleccionable solo en paso 1, sin Volver allí. Tipo fijo en pasos 2 y 3. Volver del cronograma conserva condiciones; volver a identificación advierte el descarte cuando corresponde. No se duplica Continuar a condiciones ni Consultar clientes. |
| Guardado | Alta nueva de personas, empresa, evidencia, préstamo y cronograma en una confirmación transaccional. Fallar revierte el alta nueva; una revalidación existente ya guardada permanece al abandonar. Claves de operación evitan duplicar un mismo reintento. |
| Clientes | Lista solo titulares con préstamos confirmados locales, incluidos los ya pagados. Filtros Todos, Personas y Empresas y búsqueda exacta por DNI o RUC. Pagar una deuda ajena o ser un vínculo del grupo no añade al titular al listado. |
| Fichas compartidas | Persona única por DNI/RUC 10 y empresa separada por RUC 20. Las agencias con acceso al grupo comparten identidad, vínculos, historial y capital, sin ampliar su cartera. El representante solo se enlaza si su ficha es accesible. |
| Ficha resumida | Identificación, condición de pago, capital y Personas y empresas vinculadas. No repite Préstamos en tu agencia. Termina con Consultar para pagar y Ver historial; el historial abre DNI/RUC directamente o mediante menú según el titular. |
| Revalidación | DNI consulta automáticamente el documento fijo y exige evidencia nueva para guardar. SUNAT compara valores anteriores y actuales y permite guardar una consulta sin cambios o con observación. No actualiza automáticamente DNI, propiedad o facultades ni consulta periódicamente todos los RUC. |
| Cartera | Préstamos conserva únicamente operaciones de la agencia del asesor. Filtros Activos, Cancelados o Todos, tipo de titular y búsqueda DNI/RUC/código PR-. Personas muestran DNI; empresas, RUC. |
| Contrato y cronograma | Detalle con menús Cronograma —descarga PDF e impresión— y Contrato —Word e impresión/guardar PDF—. Plantilla del profesor conservada, campos variables y anexo de condiciones; identidad contractual congelada al confirmar préstamos nuevos. |
| Mora | Desde el día siguiente al vencimiento, fecha de Perú. Cálculo diario separado sobre capital vencido; tasa efectiva anual y base 360 o 365 pactadas y congeladas por préstamo. |
| Pagos del grupo | DNI, RUC 10 o RUC 20 reúnen las obligaciones del propietario y sus empresas entre agencias. Se cobra un préstamo por vez, con cuotas completas consecutivas de la más antigua; no se mezclan cuotas de distintos préstamos. |
| Contexto del pago | Desde ficha, documento y tipo fijos y regreso a la misma ficha. Desde detalle, UUID autorizado y código/tipo fijos y regreso al mismo detalle. La búsqueda general sigue editable y borra selección y confirmaciones al cambiar documento o tipo. No existe Cambiar cliente en los flujos fijos. |
| Desplazamiento | Elegir préstamo o cargar un resultado único enfoca su titular con margen superior de 8 px tras la animación. Una lista múltiple o cambiar cantidad de cuotas no repiten el desplazamiento. Respeta reducir animaciones. |
| Regularización | Cubrir todo lo vencido regulariza sin anticipar cuotas futuras. Cancelación total cierra el préstamo. Sin atrasos es la etiqueta visual de habilitado; no acredita identidad ni capital disponible. |
| Extrajudicial y permiso | Doce meses calendario desde la cuota impaga más antigua. El antecedente permanece después de regularizar y exige autorización especial con motivo, sin mora ni historial pendiente. Autorizar no omite identidad, RUC o capital. |
| Constancias y trazabilidad | Pago conserva préstamo, cuotas, capital, interés, mora, asesor, fecha y agencias de origen/cobro. La constancia se recupera desde la agencia de origen o de cobro conforme a permisos; no se presenta como comprobante tributario. |

## Configuración que requiere definición del responsable del parcial

El sistema no inventa una tasa de mora ni asigna permisos especiales automáticamente. El responsable define tasa, base y personas autorizadas. Base admite 360 o 365 días para nuevos préstamos; tasa pendiente no agrega mora y una tasa cero es una decisión explícita distinta.

Los permisos de autorización y configuración se registran en `private.permisos_operacion`, sin acceso directo desde el navegador. El siguiente ejemplo es administrativo y requiere sustituir el marcador por el UUID del asesor elegido; no se ejecuta literalmente ni es un paso pendiente de la actualización documental.

```sql
insert into private.permisos_operacion(asesor_id, autoriza_credito, configura_mora)
values ('UUID_DEL_ASESOR_DESIGNADO', true, true)
on conflict (asesor_id) do update
set autoriza_credito = excluded.autoriza_credito,
    configura_mora = excluded.configura_mora;
```

Los permisos son independientes. Configuración aparece solo a quien tiene `configura_mora`; la autorización por antecedente aparece solo a quien tiene `autoriza_credito` y cuando se cumplen las condiciones. Ambas operaciones vuelven a validar permisos en la base.

## Fórmula y aplicación de los pagos

Interés moratorio por cuota = capital vencido impago × [(1 + tasa efectiva anual)^(días de atraso / base anual) − 1]. Se redondea por cuota a dos decimales. No se cobra sobre intereses originales ni cuotas futuras. El pago completo cubre capital, interés original y mora de cada cuota seleccionada.

La configuración se aplica solo a préstamos nuevos; los anteriores conservan sus condiciones. La confirmación rechaza una cotización cuya tasa o base haya cambiado mientras se revisaba. El cobro comprueba importe, primera cuota pendiente y fecha de Perú para rechazar selecciones obsoletas. Las pruebas usan tasas ficticias aisladas y no establecen una tasa operativa.

## Modelo de contrato

- `Contrato_profesor.docx` conserva el original del profesor y no se reescribe con las decisiones de la aplicación.
- `app/templates/contrato.docx` conserva sus cláusulas, formato e imágenes, añade campos variables y anexo de condiciones; `contrato-texto.json` alimenta la impresión.
- Los préstamos nuevos congelan identidad, modalidad, propietario y representante al confirmar. Revalidar después no cambia esos datos contractuales.
- Un préstamo histórico sin copia de identidad usa la ficha disponible; no se afirma recuperar datos originales inexistentes.
- Las denominaciones EFS/Préstamos Castillo, la referencia a una cláusula décimo sexta ausente y los conceptos fuera del alcance se identifican sin crear penalidades, pagarés, intermediación o integración bancaria.

## Migraciones

El repositorio conserva las ocho migraciones de base en `app/supabase/migrations`, desde `20261016054059_prestamos_pagos_agencias.sql` hasta `20261016191009_proteger_configuracion_privada.sql`. Integran pagos, agencias, identidad, borradores, RUC, permisos, contrato y mora. `docs/archivo/007_no_aplicada.sql` es un archivo histórico no aplicado: no forma parte del orden operativo.

Las revisiones posteriores están en `app/scripts`. Para una base nueva compatible, el orden documental es:

1. Aplicar las migraciones de base en su orden cronológico, sobre el esquema inicial compatible. No representan por sí solas una instalación autónoma desde cualquier base vacía: las pruebas construyen ese esquema inicial de forma explícita.
2. Aplicar `habilitar_modalidad_personal.sql`.
3. Aplicar `revalidacion_y_pagos_globales.sql`.
4. Aplicar `fichas_compartidas_y_grupo_pago.sql`.
5. Aplicar **al final** `control_sesiones.sql`.

`ACTUALIZAR_SISTEMA.sql` reúne los ajustes anteriores de modalidad/fichas/pagos como alternativa acumulada, pero no incluye sesiones. No debe reaplicarse después del control de sesiones: sustituye la autorización central por una versión anterior. Las revisiones ya aplicadas no se repiten para actualizar textos.

En el Supabase existente se aplicó la sincronización de modalidad, fichas y pagos con la migración `20261017033954`, y sesiones con `20261017072218_control_sesiones_inactividad_y_sesion_unica`. La verificación del 17 de octubre confirmó función pública de sesión disponible, RLS en la tabla privada, sin lectura directa para `authenticated` y sin ejecución para `anon`. Las funciones privadas mantienen búsqueda de esquema restringida. En esa comprobación se conservaron 11 préstamos y 6 pagos; es una referencia temporal, no una cantidad fija del negocio.

La tabla privada de sesiones deniega el acceso directo por diseño; el aviso informativo de RLS sin políticas refleja ese cierre. La advertencia de Auth sobre protección de contraseñas filtradas es independiente de esta revisión. Referencia: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Validación

- ESLint, TypeScript y compilación de producción en la versión de código integrada.
- Suites PGlite aisladas para agencias, borradores, RUC, modalidad personal, revalidación/pagos, fichas compartidas y sesiones; pruebas de contrato por separado.
- Firmas y vigencia, alta conjunta, rollback, idempotencia, ACTIVO/HABIDO, propietario/representante y capital global.
- Mora, cotización obsoleta, regularización, autorización y cobro entre agencias sin ampliación de cartera.
- Navegador con datos y proveedor ficticios: pasos, filtros, revalidación DNI/RUC, representante con propietario ausente, monto/plazo, fichas, contrato, pago fijo, retorno e historiales, desplazamiento único y diseño móvil/escritorio.
- Sesiones en dos procesos de navegador independientes: contador, aviso, continuar, vencimiento, reemplazo y cierre antiguo sin revocar la sesión nueva. Son pruebas locales, no nuevos préstamos o cobros reales.
- Word contractual: campos completos, escape XML, identidad congelada y preservación de partes originales, con renderización e inspección visual.

La revisión documental contrasta Markdown y Word con el código y comprueba texto, rutas, tablas y paginación. No se vuelve a ejecutar una operación financiera real para validar una edición de texto. Una respuesta de proveedor simulada no acredita disponibilidad del servicio externo real.

## Ejecución

Desde `app`, primera instalación: `npm.cmd ci`, configurar las cuatro variables de `.env.example` en `.env.local` y `npm.cmd run dev`. Si no cambian dependencias y conservas `node_modules`, no necesitas reinstalarlas. Para producción: `npm.cmd run build` y `npm.cmd start`. No publiques `.env.local`, tokens o claves de firma.

Desde `app/tests`, `npm.cmd ci` y `npm test` ejecutan agencias, borradores y RUC. Las demás suites se invocan por separado desde `app`, por ejemplo `node tests/sesiones.test.mjs`. El detalle de cada suite está en `app/tests/README.md`.

Una actualización parcial copia solo los archivos entregados; no elimina `app/src`, `docs`, plantillas o dependencias. Las instrucciones vigentes están en la raíz y describen este paquete documental, no los ZIP anteriores.

## Estado de publicación

Referencia verificada: `5723a1385559f3e60d003c74395f9d3ae5edbda5`, rama `main` de `KohakuAzureFire/prestamos-parcial`. Los 16 archivos del paquete de sesiones coincidían con esa versión y el contraste documental comprobó la coincidencia de los 137 archivos del repositorio con la copia revisada.

Vercel reportó éxito para el despliegue `HbPXUSk1G1bfRYQGotk497dVtxz6`. Se comprobaron `https://prestamos-parcial.vercel.app/login` con HTTP 200, `/api/sesion` sin autenticar con HTTP 401 y la redirección de `/dashboard/prestamos` al inicio. La prueba autenticada de sesiones se hizo en local; estas comprobaciones públicas no sustituyen un recorrido autenticado completo de producción.

El control de sesiones está aplicado en Supabase. La presente revisión cambia únicamente documentación: no confirma préstamos, no registra cobros, no modifica claves ni exige otra migración. El siguiente commit documental tendrá su propio identificador; la referencia anterior identifica el código que se contrastó, no un SHA futuro inventado.

## Revisión de interfaz del 16 de octubre de 2026

Cronograma y Contrato agrupan descarga e impresión en dos menús del detalle. Se conserva el estilo de botones del sistema. La impresión tiene ruta protegida, datos escapados y permisos por agencia. En pasos 2 y 3 el tipo de cliente permanece fijo; en paso 1 no hay Volver. La verificación incrustada separa Confirmar verificación de Continuar a condiciones y no agrega Consultar clientes. Un domicilio vacío o guion del proveedor se omite como dato útil.

El monto usa punto fijo y dos cifras de centavos y el plazo solo enteros de 1 a 60. Se retiraron avisos repetidos que no aportaban una decisión. En Pagos e historiales, los regresos mantienen el enlace con flecha encima del título; el recuadro seleccionado se desplaza con margen de 8 px, sin contorno adicional y conservando accesibilidad.

## Revisión de revalidación y representación del 16 de octubre de 2026

DNI se consulta automáticamente al revalidar desde ficha, con el número fijo y evidencias sin marcar; guardar vuelve a esa ficha. DNI/RUC 10 ofrecen un menú en la misma ficha y RUC 20 abre SUNAT. La consulta SUNAT compara valores guardados y actuales, permite registrar una nueva consulta sin cambios y conserva observaciones legítimas. Un fallo técnico no se guarda como identidad rechazada. Estos accesos siguen disponibles con información vigente.

En empresa se registra quién firma y si el propietario está presente. El ausente requiere identidad previa aprobada y vigente, sin verificación presencial ficticia. El firmante sí debe estar presente y tener identidad y facultades revisadas. Propiedad y facultades usan tipo y referencia breve, con posibilidad de documento compartido y confirmaciones separadas. Cambiar representante descarta su evidencia de facultades; cambiar propietario descarta las referencias vinculadas al anterior.

## Revisión de filtros y documentación ágil de empresas

Clientes y Préstamos conservan filtros de personas y empresas. La columna Documento usa DNI para personas y RUC para empresas; la ficha personal muestra primero DNI y luego RUC 10 cuando existe. El listado de Clientes exige un préstamo confirmado local y conserva titulares con préstamos ya pagados. Acceder a una ficha vinculada no la añade al listado ni amplía cartera.

La ficha comparte estructura entre personas y empresas y termina con Consultar para pagar y Ver historial. Las revisiones se abren en su página propia. El grupo del propietario se consulta por DNI, RUC 10 o RUC 20 en Pagos, con los mismos préstamos entre agencias. La condición Sin atrasos, la identidad vigente y el capital disponible son comprobaciones distintas.

## Revisión de sesiones del 17 de octubre de 2026

La cabecera conserva nombre y rol, agencia y fecha; añade Sesión 15:00. Teclado, puntero y desplazamiento renuevan actividad con envíos limitados a uno cada diez segundos; el sondeo cada quince segundos no renueva el plazo. El contador se vuelve ámbar en los últimos dos minutos y rojo en el último, con diálogo para continuar o cerrar. Varias pestañas comparten sesión y el reloj usa la referencia del servidor.

Un inicio posterior de la misma cuenta reemplaza al anterior. La base comprueba el identificador de sesión firmado contra `auth.sessions` y su registro privado. La autorización central protege también las funciones de negocio. Una sesión vencida o cerrada no se reabre con la misma identidad de sesión; hace falta iniciar nuevamente. El cierre es local y no revoca una sesión posterior de otra computadora. Los borradores se pierden al cerrar, pero las operaciones confirmadas permanecen.

## Alcance pendiente

No se implementaron abonos parciales, reversos, refinanciación, reprogramación, scoring de riesgo por monto/plazo, gestión judicial, panel gerencial, documentos extranjeros, otros prefijos RUC, aprobación documental remota de un propietario no verificado ni consulta oficial automática de fallecimiento. Los datos SUNAT se actualizan mediante consulta y guardado, no por un proceso periódico externo. Las menciones del contrato original a otras funciones no las incorporan al sistema.
