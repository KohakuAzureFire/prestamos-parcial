# Revisión actual: clientes por agencia y revalidación

Implementada en esta entrega. Consulta OBSERVACIONES_CLIENTES_REVALIDACION.md y las instrucciones de actualización. No requiere SQL adicional sobre la base ya sincronizada.

El contenido siguiente describe la base y revisiones anteriores.

# Estado de implementación del sistema de préstamos

## Revisión actual: fichas compartidas y desplegable

Sigue `INSTRUCCIONES_ACTUALIZACION.md`. Aplica el contenido completo de `app/scripts/ACTUALIZAR_SISTEMA.sql` en el SQL Editor de Supabase. Este archivo incluye todos los ajustes anteriores y el nuevo; no necesitas ejecutar los demás por separado. Todavía no se aplicó al proyecto real desde este chat. Conserva .env.local y node_modules.

Consulta `docs/FICHAS_COMPARTIDAS.md` para las fichas y vínculos compartidos, cartera local, pagos del mismo grupo por DNI/RUC10/RUC20, retiro de Cambiar cliente, desplegable de Solicitar préstamo y plazo controlado de 1 a 60. El monto conserva su formato fijo.


## Notas históricas de revisiones anteriores

## Última revisión: monto con formato fijo

El monto muestra soles y dos centavos separados por un punto fijo, como `0.00`. Cada parte admite solo dígitos. Al seleccionar una parte se puede reemplazar su valor; el punto, la coma o la flecha derecha permiten pasar de soles a centavos. No admite signos, letras ni importes superiores al capital disponible. `0.00` no habilita Ver cronograma. Al salir del campo, los centavos siempre tienen dos cifras. Se retiraron el aviso superior repetido del monto y el aviso informativo repetido de guardado.

**Si ya instalaste la revisión anterior, reemplaza `app/src` por el de este ZIP y elimina `app/.next`, conservando `.env.local` y `node_modules`. Ejecuta `npm.cmd run dev`. Esta revisión del formulario no necesita SQL nuevo ni reinstalar dependencias.** Si partes de una versión anterior, conserva los pasos SQL de instalación indicados más abajo.


## Ajuste nuevo: revalidación y pagos globales

**Ejecuta el nuevo `app/scripts/revalidacion_y_pagos_globales.sql` en el SQL Editor de tu Supabase.** Si ya aplicaste `habilitar_modalidad_personal.sql` de la revisión anterior, no necesitas repetirlo. Si aún no lo aplicaste, ejecútalo primero. Ninguno se ha aplicado al proyecto real desde este chat.

Copia `app/src`, `app/scripts`, `app/tests` y las instrucciones conservando tu `.env.local` y `node_modules`, y elimina `app/.next`. No requiere reinstalar dependencias. Consulta `docs/REVALIDACION_Y_PAGOS.md` para el comportamiento y pruebas de esta actualización.


## Actualización: acceso desde ficha y modalidad personal

**Antes de usar esta revisión, aplica `app/scripts/habilitar_modalidad_personal.sql` en el SQL Editor de tu proyecto Supabase.** Está probado en una base aislada y todavía no se ha aplicado al proyecto real. Conserva tus claves y dependencias. Sigue `INSTRUCCIONES_ACTUALIZACION.md` para copiar los archivos y ejecutar este único ajuste.

La ficha bloquea solicitudes sin capital disponible. Las personas con RUC10 eligen préstamo personal (DNI) o negocio (RUC10); la consulta RUC y la recuperación del titular se realizan automáticamente desde ficha. Revalidar identidad revisa el DNI independientemente del RUC. Se retiró «Revisar propietario». La modalidad se conserva en el contrato y cronograma de cada operación nueva.

Actualizado el 16 de octubre de 2026. Proyecto académico del examen parcial. Se conserva el diseño y el flujo Cliente → Condiciones → Cronograma; la ampliación agrega identidad por RUC, empresas, contrato y cobranza con mora.

## Funcionalidades integradas

| Área | Comportamiento |
| --- | --- |
| Identidad | DNI de 8 dígitos, RUC 10 y RUC 20. Validación local y en servidor; RUC con dígito verificador, consulta externa y respuesta firmada ligada al asesor, vigente por 30 minutos. |
| Persona con negocio | El DNI y su RUC 10 utilizan la misma ficha. Un nuevo préstamo exige volver a consultar el RUC. |
| Empresa | Titular independiente, propietario responsable del límite y representante que firma. Ambos DNI requieren identidad aprobada y vigente; pueden ser la misma persona. |
| Evidencia | Referencia del documento de propiedad, confirmación de revisión y referencia de facultades del representante. Con varios propietarios se exige una designación documentada del responsable del límite. No se reasigna el propietario desde una solicitud ordinaria. |
| Capital | S/ 10 000 entre la persona y sus empresas vinculadas en todas las agencias. Solo el capital amortizado libera cupo. Las funciones serializan solicitudes del mismo propietario. |
| Guardado | Personas nuevas, empresa, verificación de RUC, préstamo y cronograma se confirman juntos. Un fallo revierte el alta nueva. Una revalidación guardada de una persona existente permanece aunque abandone el préstamo. |
| Contrato | Descarga Word desde el detalle y vista de impresión para imprimir o guardar como PDF. Plantilla del profesor preservada, campos variables y anexo con las condiciones. El cronograma se entrega por separado. |
| Mora | Desde el día siguiente al vencimiento, fecha de Perú. Cálculo diario separado sobre el capital vencido; tasa efectiva anual pactada y base 360 o 365, congeladas para cada préstamo nuevo. |
| Pagos | DNI, RUC o código PR-. Cuotas completas consecutivas desde la más antigua. Importe cotizado por el servidor con fecha de Perú; rechazo si fecha o importe cambian. Constancia muestra capital, interés original y mora. |
| Regularización | Cubrir todo lo vencido regulariza sin pagar anticipadamente cuotas futuras. La cancelación total cierra el préstamo. |
| Extrajudicial | Doce meses calendario desde la cuota impaga más antigua. El pago de otra cuota no reinicia ese vencimiento. Se conserva el antecedente y se bloquea la nueva colocación hasta una autorización registrada. |
| Autorización | Un asesor designado con permiso especial autoriza desde la ficha, con motivo y sin deuda vencida ni historial pendiente de conciliación. Se conserva su identificador en la auditoría. |
| Agencias | Cartera y fichas ordinarias limitadas a su agencia; cobro dirigido interagencia conserva el origen y no incorpora al cliente a la agencia de cobro. |

## Configuración que requiere definición del responsable del parcial

No se inventa una tasa de mora ni se asignan facultades adicionales a ninguna cuenta existente. La base propuesta por defecto es 360 días y puede configurarse en 365 para nuevos préstamos. Si la tasa no está definida, el préstamo indica que no tiene tasa pactada y no agrega cargos moratorios. Una tasa de cero es una regla explícita distinta de una tasa pendiente.

El administrador designa los permisos mediante la tabla privada `private.permisos_operacion`. No es modificable desde el navegador. Por ejemplo, usando un identificador real de asesor elegido por el responsable:

```sql
insert into private.permisos_operacion(asesor_id, autoriza_credito, configura_mora)
values ('UUID_DEL_ASESOR_DESIGNADO', true, true)
on conflict (asesor_id) do update
set autoriza_credito = excluded.autoriza_credito,
    configura_mora = excluded.configura_mora;
```

El ejemplo contiene un marcador; no se ejecuta literalmente. Los permisos son independientes. La persona con `configura_mora` ve Configuración en el menú y puede fijar tasa y base con motivo; quien tiene `autoriza_credito` ve el formulario de autorización cuando corresponde. Todas las operaciones vuelven a comprobar el permiso en la base. El asesor ordinario no omite bloqueos.

## Fórmula y aplicación de los pagos

Interés moratorio por cuota = capital vencido impago × [(1 + tasa efectiva anual)^(días de atraso / base anual) − 1]. Se redondea por cuota a dos decimales. No se cobra sobre intereses originales ni sobre cuotas futuras. Los pagos completos cubren el capital, interés original y mora de cada cuota seleccionada. No se incluyen abonos parciales ni penalidades.

La configuración de mora solo se aplica a préstamos nuevos. Los préstamos anteriores no se recalculan; cada préstamo conserva las condiciones que tenía al confirmarse. La confirmación comprueba que la tasa y base mostradas no hayan cambiado mientras el asesor revisaba el préstamo.

## Modelo de contrato

- `Contrato_profesor.docx`: copia original entregada por el profesor.
- `app/templates/contrato.docx`: plantilla con campos variables y un anexo, conservando las cláusulas, formato e imágenes originales.
- `app/templates/contrato-texto.json`: texto para la vista de impresión.
- Los préstamos nuevos guardan una copia de identidad, propietario y representante al confirmar. Cambiar una ficha después no cambia esos datos en su contrato.
- Un préstamo histórico sin copia de identidad usa la ficha disponible; no se afirma que recupera los datos originales de una fecha pasada.
- Se identifican en el modelo denominaciones EFS/Préstamos Castillo, una referencia a una cláusula décimo sexta ausente y conceptos no implementados en este sprint. Se conserva el original sin crear penalidades, pagarés, intermediación ni integración bancaria.

## Migraciones

Las cuatro migraciones anteriores del sprint permanecen. Se incorporan al repositorio las dos migraciones que ya existían en Supabase:

- `20261016174004_ruc_propietario_regularizacion_contrato.sql`.
- `20261016174232_restringir_rehabilitaciones.sql`.

La migración `20261016190840_integrar_ruc_contrato_mora_autorizacion.sql` agrega permisos, configuración auditada, congelación de condiciones, cotizaciones y autorización desde la ficha. Está aplicada en Supabase. Se comprobó que permanecen 5 clientes, 4 préstamos, 59 cuotas, 4 pagos y 5 aplicaciones de pago; no elimina operaciones anteriores.

La migración `20261016191009_proteger_configuracion_privada.sql`, también aplicada, deniega explícitamente el acceso directo a las tablas privadas de permisos y auditoría. La revisión de seguridad no detectó problemas nuevos de tablas o funciones; permanece la advertencia anterior de Supabase Auth sobre protección de contraseñas filtradas. Referencia: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Validación

- ESLint, TypeScript y compilación de producción.
- Suites aisladas en PGlite para reglas anteriores, clientes por agencia, borradores y ampliación por RUC.
- Firma y vigencia de consultas, alta conjunta, rollback, idempotencia, RUC ACTIVO/HABIDO, separación propietario/representante y capital compartido.
- Cálculo moratorio comprobado contra la fórmula, rechazo de importe obsoleto, cobro interagencia, regularización y autorización con antecedente.
- Recorrido en navegador con base y proveedor simulados localmente: login, RUC 20 con personas distintas, ausencia de altas antes de confirmar, contrato descargable, cobro con mora y constancia, ficha con RUC y anchos 1440, 1024 y 390 sin desbordamiento de página ni errores JavaScript.
- Contrato: campos completos, XML escapado, identidad congelada y conservación de las partes del Word; renderización e inspección visual.

Los datos de prueba y la tasa ficticia de las pruebas pertenecen al entorno local aislado. No se insertan clientes, préstamos o cobros de prueba en el proyecto real. La consulta externa necesita las variables del servidor; un resultado simulado no acredita disponibilidad del proveedor real.

## Ejecución

Desde `app`: `npm ci`, configurar las cuatro variables de `.env.example`, `npm run dev`. Para producción: `npm run build` y `npm start`. No se publica `.env.local` ni secretos. Para las pruebas de base: `cd app/tests`, `npm ci`, `npm test`. Para probar el contrato con Node 24: desde `app`, `node tests/contrato.test.mjs`.

## Estado de publicación

El usuario autorizó expresamente la publicación el 16 de octubre de 2026. El acceso de la integración a KohakuAzureFire/prestamos-parcial está habilitado. La implementación fue verificada con compilación, lint, TypeScript, pruebas de base y navegación aislada. La versión publicada se identifica en el historial de main; el estado del despliegue debe comprobarse en Vercel. Las migraciones descritas ya están aplicadas en Supabase.

## Revisión de interfaz del 16 de octubre de 2026

- Cabecera del detalle: dos menús, Cronograma (celeste) y Contrato (azul oscuro), con descarga e impresión. La impresión del cronograma tiene ruta autenticada, permisos de agencia, datos escapados y solo el documento.
- Tipo de cliente fijo en pasos 2 y 3; para cambiarlo se vuelve al paso 1. Volver del paso 3 conserva las condiciones; volver del paso 2 al 1 descarta el formulario pendiente tras confirmación cuando tiene condiciones.
- Verificación presencial: fecha de caducidad y dos casillas obligatorias. Se generan referencias descriptivas sin entrada manual. La presencia física no se presenta como consulta oficial de fallecimiento. Se conserva el contrato de datos de la base existente; el indicador legado no_fallecido registra la confirmación presencial y la evidencia deja explícito su alcance. No se modifica el historial anterior.
- En el paso 1 no hay Volver. En DNI/RUC10 el documento consultado se muestra según contexto; el DNI del RUC10 es de solo lectura.
- En el flujo RUC, la verificación incrustada usa un título de sección, no muestra Consultar clientes y distingue Confirmar verificación de Continuar a condiciones.
- Domicilio fiscal solo si la consulta devuelve un valor útil; se ocultan guiones vacíos.
- No requiere migraciones nuevas, no asigna permisos, no configura mora y no implementa abonos parciales ni evaluación de riesgo.
- El ZIP no incluye .env.local: conservar el archivo real del usuario. No se ha publicado esta revisión.

Validación de esta revisión: ESLint, TypeScript y compilación de producción. Recorrido de navegador con Next.js de producción y base PGlite aislada: RUC10, verificación y alta conjunta, conservación de condiciones al volver de 3 a 2 y descarte al volver a 1, selector bloqueado, PDF y Word descargables, impresión HTML del cronograma, ausencia de desbordamiento de página a 1440 y 390 px y respuestas 401/404 para accesos no autorizados. No se utilizaron credenciales reales ni se escribieron operaciones en Supabase.

## Revisión de revalidación y representación del 16 de octubre de 2026

- Nuevo préstamo tiene un único encabezado antes del selector, con separación de 24 px. Se retira Consultar clientes también del flujo DNI.
- Revalidar identidad reutiliza el mismo componente: consulta automáticamente el DNI recibido, lo deja fijo y no omite la consulta aunque la ficha ya esté aprobada. El asesor confirma la revisión; Guardar revalidación regresa a la ficha y no inicia un préstamo. Se ofrece Reintentar consulta ante error y Volver a la ficha.
- Para RUC 20 se elige quién firma: propietario con facultades de representación o representante distinto. En el segundo caso se registra si el propietario está presente.
- Propietario ausente: solo se reutiliza su identidad existente, aprobada y vigente. No se crea una verificación presencial ni se agregan declaraciones de presencia del propietario. Si falta esa verificación, el formulario bloquea el avance e indica revisión documental pendiente. Esta entrega no incorpora una aprobación remota/documental nueva: una revisión de ese tipo necesita un proceso separado. La base vuelve a comprobar la identidad al confirmar.
- El representante/firmante sí requiere identidad verificada, presencia y revisión del DNI original; si esa revisión ya se hizo en el borrador de la misma solicitud no se repite la casilla. Para fichas vigentes reutilizadas se solicita confirmación de presencia y DNI del firmante en esta operación.
- Propiedad y facultades siguen requiriendo referencias documentales. La evidencia guardada de RUC identifica al propietario ausente y al firmante presente. El límite compartido sigue siendo una regla interna académica y no convierte al propietario en deudor o garante.
- Se conserva el alcance: DNI peruano, RUC 10 y RUC 20. No se añaden prefijos 15/17 ni documentos de identidad extranjeros.
- Cambios de interfaz y reutilización de funciones existentes: sin migraciones nuevas, sin cambios de dependencias ni claves. No se publica en GitHub/Vercel.

Comprobación: TypeScript, ESLint y build de producción; navegador con base PGlite y proveedor de identidad ficticio, sin acceso a Supabase real. Se verificó una sola consulta automática al revalidar una identidad ya aprobada, retorno a ficha tras guardar, propietario ausente válido, rechazo de propietario no verificado y evidencia de RUC con asistencia diferenciada. El número de verificaciones presenciales del propietario ausente no aumentó al confirmar el préstamo de empresa. También pasó el recorrido anterior de pasos, menús y documentos.


## Revisión: filtros y documentación ágil de empresas

Clientes y Préstamos incorporan filtros de personas y empresas; las tablas muestran DNI para personas y RUC para empresas. En las fichas personales, DNI precede a RUC. La documentación empresarial usa tipo de documento y referencia breve, recupera referencias existentes y exige confirmar ambas revisiones para la operación. Consulta `docs/CAMBIOS_INTERFAZ.md` (desde la raíz) para instalación y pruebas manuales. No cambia dependencias ni variables. La revisión actual sí requiere el ajuste SQL indicado al inicio.
