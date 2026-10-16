# Sprint 1 del sistema de préstamos

El incremento permite verificar al cliente, registrar préstamos con TEA del 30 %, entregar el cronograma y registrar el pago de cuotas en cualquiera de las cinco agencias. La cartera se consulta por agencia y la condición de pago del cliente se obtiene automáticamente de sus obligaciones pendientes.

## Negocio y atención al cliente

El negocio ofrece préstamos de libre disponibilidad en Chimbote, Trujillo, Chiclayo, Piura y Tumbes. La atención es presencial y el sistema es utilizado por los trabajadores. Un préstamo conserva su agencia de origen aunque el cliente pague una cuota en otra agencia.

## Problema que debemos resolver

El registro en hojas de cálculo provoca errores de identidad y dificulta conocer las cuotas pendientes. El sistema debe conservar datos confiables, distinguir la cartera de cada agencia y registrar los pagos para evitar cobros duplicados y nuevos préstamos a clientes con mora.

## Usuarios del negocio

| Usuario | Función |
| --- | --- |
| Asesor de ventas | Verifica clientes, registra préstamos y cobra cuotas desde su agencia asignada. |
| Gerente | Consulta la situación general en una entrega posterior; no tiene panel en este sprint. |

## Reglas del negocio

| Aspecto | Regla |
| --- | --- |
| Agencias | Solo Chimbote, Trujillo, Chiclayo, Piura y Tumbes. Cada cuenta tiene una agencia asignada. |
| Préstamo | Cliente, fecha de operación, monto positivo en soles y plazo entero de 1 a 60 meses. Sin monto mínimo adicional para las pruebas. |
| Interés | TEA fija del 30 %. Sistema francés y tasa efectiva mensual equivalente. |
| Vencimientos | Mensuales, en el día original del préstamo. Si no existe en un mes, se utiliza el último día de ese mes, considerando años bisiestos. |
| Capital máximo | Hasta S/ 10 000 de capital pendiente entre todos los préstamos del cliente, incluyendo el nuevo monto y las cinco agencias. |
| Elegibilidad | DNI verificado y vigente, sin condición de fallecido acreditada y sin mora ni estado extrajudicial. |
| Cobranza | Se pueden pagar cuotas de un préstamo en otra agencia. Se atienden primero las cuotas pendientes más antiguas del préstamo seleccionado. |

## Funciones de la entrega

Se atiende a personas naturales peruanas con DNI y una ficha única compartida entre las cinco agencias. Clientes lista solo a quienes fueron registrados en la agencia actual o recibieron un préstamo allí; Préstamos lista solo operaciones originadas en esa agencia. Sus búsquedas respetan estos límites. La verificación y los saldos globales se reutilizan para evaluar nuevos préstamos, sin habilitar la consulta ordinaria de carteras ajenas.

| Área | En esta entrega | Para después |
| --- | --- | --- |
| Acceso | Iniciar y cerrar sesión sin cuentas de demostración visibles. | Administrar cuentas y recuperar contraseñas. |
| Clientes | Consultar ficha e historial de verificación; registrar o revalidar desde el flujo del préstamo. | RUC, empresas y otros documentos. |
| Préstamos | Registrar, controlar el capital pendiente y consultar cartera propia. | Editar, anular o refinanciar préstamos confirmados. |
| Cronograma | Cuotas mensuales, desglose de interés y capital, guardado y PDF. | Reprogramaciones y amortización extraordinaria. |
| Pagos | Registrar cuotas completas, incluso de otra agencia, y emitir constancia. | Abonos parciales, devoluciones y pasarelas de pago. |
| Estados | Actualizar deuda y condición de pago automáticamente. | Reportes gerenciales y gestión jurídica de cobranza. |

## Decisiones que precisan el alcance

Las observaciones del profesor establecen la consulta por agencia, el pago entre agencias y la condición automática de moroso o extrajudicial. Para que estas reglas sean implementables, se adoptan las siguientes precisiones del proyecto, que se revisarán con el profesor si indica otro criterio.

| Decisión | Criterio operativo propuesto |
| --- | --- |
| Inicio de mora | Desde el día siguiente al vencimiento de una cuota que conserve saldo impago; no se espera al fin del mes. |
| Un año de atraso | Doce meses calendario desde el vencimiento de la cuota impaga más antigua. El día inexistente se ajusta al último del mes. |
| Cobro mínimo | Registro interno por el asesor de una o varias cuotas completas consecutivas del préstamo seleccionado; no integra un banco ni una pasarela. |
| Orden del pago | Primero la cuota pendiente más antigua del préstamo elegido. La condición del cliente considera todos sus préstamos en las cinco agencias. |
| Cálculo mensual | Tasa mensual constante equivalente a la TEA, separada de las fechas mensuales de calendario. No se aplica interés según días reales en esta entrega. |

## Condiciones para operar

Las cuentas y las cinco agencias están preconfiguradas. Se retiran del entorno operativo la agencia General y la cuenta Ana Morales. La depuración respeta las referencias y la trazabilidad de operaciones existentes; no borra préstamos ni pagos históricos. Un registro ficticio sin referencias puede eliminarse; si tiene referencias, se regulariza antes de retirarlo y se bloquea su acceso.

Los préstamos anteriores requieren capital, cronograma y pagos conciliados. La falta de un pago histórico no demuestra por sí sola que exista mora. Un cliente con historial incompleto queda identificado como pendiente de conciliación y no obtiene nuevos préstamos hasta regularizar los datos.

## Pantallas y recorrido de atención

| Pantalla | Contenido y acciones |
| --- | --- |
| Inicio de sesión | Correo, contraseña y acceso. Sin panel, botones ni credenciales de demostración. La agencia proviene de la cuenta. |
| Préstamos | Solo cartera de la agencia actual. Activos por defecto y filtro Activos, Cancelados o Todos. Código, DNI, cliente, fecha, monto original, plazo, estado y Ver detalle; sin columna Deuda pendiente ni botón Nuevo préstamo. Selector DNI exacto o Código de préstamo con validación de formato. |
| Clientes | Listado y búsqueda limitados a clientes registrados en la agencia actual o con préstamos otorgados allí. Muestra DNI, nombre, verificación y condición de pago. Cobrar un préstamo ajeno no incorpora al cliente al listado. Sin botón Validar cliente ni búsqueda global. |
| Ficha del cliente | Identidad, caducidad, evidencia e historial de revisión, condición de pago y capital global. Sin selector manual de condición. Permite iniciar Solicitar préstamo o Revalidar DNI en el flujo correspondiente. |
| Nuevo préstamo | Paso 1: comprobar DNI; reutilizar ficha vigente, revalidar al existente o preparar borrador del nuevo. Paso 2: monto y plazo. Paso 3: confirmar conjuntamente cliente nuevo, evidencia, préstamo y cronograma. La revalidación del existente se guarda aparte, con aviso explícito, aunque no concluya el préstamo. |
| Detalle del préstamo | Tres cuadros: Total a pagar, Total pagado y Saldo por pagar, en una fila en escritorio y adaptables en móvil. Estado junto al título; TEA, TEM e interés total en Datos del préstamo. Cronograma e historial de cobros. Registrar pago abre Pagos con las cuotas cargadas automáticamente. |
| Pagos | Selector DNI exacto o Código de préstamo para cobrar en cualquiera de las cinco agencias. DNI de ocho números; código con prefijo PR- fijo y ocho caracteres hexadecimales. Por DNI se elige entre préstamos con saldo; por código se carga uno. Conserva agencia de origen y registra agencia de cobro, sin listado global. |

El menú del asesor contiene Préstamos, Clientes, Nuevo préstamo, Pagos y Cerrar sesión. Los accesos desde ficha o detalle llevan a esos mismos procesos, sin formularios de negocio duplicados.

## Recorrido del cliente nuevo y del cliente existente

Nuevo préstamo: ingresar DNI → comprobar si existe en las cinco agencias → reutilizar ficha vigente, revalidar al existente o preparar datos del nuevo → completar monto y plazo → revisar cronograma → confirmar. El nuevo permanece como borrador en memoria hasta el paso 3: no se registra ni aparece en Clientes antes de confirmar. La detección por DNI no es un buscador global y una identidad vigente no repite consulta externa por cambiar de agencia.

Cliente del listado propio: Clientes → abrir ficha → Solicitar préstamo. Cliente de otra agencia: Nuevo préstamo → ingresar DNI y recuperar ficha. Si requiere revalidación, Guardar verificación y continuar actualiza su identidad para las cinco agencias aunque no termine el préstamo; no genera crédito ni elimina mora. Una verificación rechazada o fallecimiento acreditado no se omiten. La respuesta verbal no sustituye la comprobación por DNI.

Cobranza desde el menú: Pagos → elegir DNI exacto o Código de préstamo → consultar → elegir préstamo si corresponde → revisar cuotas y agencia de origen → seleccionar cuotas consecutivas → confirmar cobro → entregar constancia. Desde Registrar pago en el detalle se cargan automáticamente el préstamo y sus cuotas, sin pulsar Consultar cuotas. Un DNI vencido o la mora no impiden pagar; bloquean únicamente nuevas colocaciones.

## Estados y datos que deben conservarse

| Concepto | Estados y regla |
| --- | --- |
| Verificación de identidad | Pendiente, Aprobada, Caducada o Rechazada. Aprobada exige identidad confiable, documento vigente y evidencia suficiente de las condiciones exigidas. |
| Condición de pago del cliente | Habilitado si no tiene cuotas vencidas impagas; Moroso si tiene atraso menor de 12 meses; Extrajudicial si al menos una cuota impaga cumple 12 meses de atraso. Son estados automáticos, con prioridad de Extrajudicial sobre Moroso. |
| Préstamo | Activo mientras quede deuda contractual pendiente; Cancelado por pago total cuando todas sus cuotas estén pagadas. Cancelado no significa anulado. |
| Cuota | Pendiente antes de vencer o durante su fecha de vencimiento; Vencida desde el día siguiente si no está pagada; Pagada únicamente si existe un cobro confirmado que la cubra. |

La condición de pago no cambia la verificación de identidad. Un cliente puede tener verificación Aprobada y condición Moroso, o condición Habilitado y DNI Caducado. En ambos casos se bloquea un nuevo préstamo. Cambiar un saldo nunca borra la fecha, la fuente o la evidencia de una verificación.

Fallecido deja de ser una opción editable de condición financiera. La información acreditada sobre fallecimiento pertenece a la verificación de identidad y bloquea nuevos préstamos; el asesor no declara ni revierte ese hecho mediante un selector. La revisión de un DNI físico, por sí sola, no acredita la condición de no fallecido.

## Datos y trazabilidad mínimos

| Registro | Información que conserva |
| --- | --- |
| Cliente y verificación | DNI único y ficha compartida; nombres y apellidos exactos; agencia de registro inicial; fecha de caducidad; resultado, evidencia, fuente, fecha, asesor y agencia de cada revisión. La renovación agrega una revisión y conserva las anteriores. Una revalidación actualiza la misma ficha para todas las agencias. |
| Préstamo y cronograma | Identificador único, cliente, agencia de origen, asesor, fecha, monto, plazo, TEA, tasa mensual y cuotas originales con interés, amortización y saldo programado. |
| Pago y aplicación | Identificador único, préstamo, cuotas cubiertas, importe, fecha y hora, asesor y agencia de cobro. La aplicación distingue capital e interés según el cronograma guardado. |
| Situación vigente | Total pagado, deuda contractual pendiente, capital pendiente, cuotas vencidas, antigüedad de la mora y fecha de actualización. Se derivan de datos conciliados y pagos confirmados. |

La fecha de operación y el corte diario se interpretan en la zona horaria de Perú. Los estados se actualizan al cambiar el día y después de un pago; también se verifican al consultar y antes de autorizar un nuevo préstamo, aunque nadie haya abierto el sistema durante varios días.

## Criterios de cálculo del cronograma

| Parámetro | Criterio adoptado |
| --- | --- |
| TEA | 30 % efectiva anual, fija y no editable. |
| Tasa mensual | TEM = (1 + 0,30)^(1/12) − 1 = 2,210445 % aproximadamente. Equivale a (1 + 0,30)^(30/360) − 1 bajo la base convencional de 360 días adoptada. |
| Amortización | Sistema francés con cuota mensual constante. Interés del mes = capital anterior × TEM; amortización = cuota − interés. La última cuota ajusta los redondeos. |
| Vencimientos | Meses calendario desde la fecha original, sin sumar intervalos fijos de 30 días. Un vencimiento ajustado a febrero no cambia el día de los meses siguientes. |
| Bisiestos | Un préstamo del 31/01/2028 vence primero el 29/02/2028 y después el 31/03/2028. Del 12/05/2026 al 12/06/2026 hay 31 días y sigue siendo una cuota mensual. |
| Convención | La base 360 sustenta la equivalencia mensual elegida; no obliga a que todas las fechas estén separadas por 30 días. No se ajustan fines de semana en este alcance. |
| Redondeo y cargos | De 1 a 60 cuotas, dos decimales y saldo final cero. Sin comisiones, seguros, penalidades ni interés moratorio agregado. |
| Importes informativos | Interés total programado = suma de intereses; total programado = suma de cuotas; deuda pendiente = total programado menos cobros confirmados. El capital pendiente excluye intereses futuros. |

## Planificación del sprint

Sprint N.º 1: Acceso, préstamos y pago básico de cuotas.

Objetivo del sprint: atender al cliente desde su verificación hasta el préstamo y el cobro de cuotas, con consulta por agencia, control de capital global y actualización automática de la condición de pago.

Resultado de la entrega: préstamos y cronogramas recuperables, pagos trazables entre agencias y bloqueo de nuevas colocaciones cuando existe mora, documento vencido o verificación insuficiente.

| N.º | HU | Historia de usuario | Dependencia |
| --- | --- | --- | --- |
| 1 | HU-01 | Iniciar sesión | Identifica asesor y agencia. |
| 2 | HU-02 | Cerrar sesión | Protege el acceso y los borradores. |
| 3 | HU-03 | Validar y registrar cliente | Define identidad y vigencia. |
| 4 | HU-04 | Registrar préstamo | Requiere cliente elegible y capital disponible. |
| 5 | HU-05 | Generar y entregar cronograma | Se confirma junto con el préstamo. |
| 6 | HU-06 | Consultar clientes y cartera propia | Recupera fichas y cronogramas. |
| 7 | HU-07 | Registrar pago de cuotas | Requiere préstamo y cronograma confirmados. |
| 8 | HU-08 | Actualizar estados automáticamente | Integra vencimientos, pagos y elegibilidad. |

Días 1 y 2: ajustar acceso, permisos por agencia, identidad y datos. Días 3 y 4: integrar cronograma, pagos y estados automáticos. Día 5: probar el flujo completo, desplegar y preparar la demostración. Los cobros y estados automáticos amplían el alcance anterior y se incorporan como HU-07 y HU-08.

## Épica Gestionar acceso

Permitir el acceso exclusivo de asesores autorizados con una de las cinco agencias asignadas. La creación de cuentas y recuperación de contraseñas quedan fuera del sprint.

### HU-01 Iniciar sesión

Como asesor de ventas, quiero iniciar sesión con mi cuenta autorizada, para operar desde la agencia que tengo asignada.

#### Criterios de aceptación

- **CA01. Credenciales obligatorias:** Se solicita correo y contraseña; los campos vacíos impiden continuar.

- **CA02. Acceso autorizado:** Solo ingresa una cuenta válida y activa. El mensaje de rechazo no revela cuál credencial falló.

- **CA03. Agencia de sesión:** El sistema obtiene asesor y agencia de la cuenta. No permite elegir otra agencia ni operar con General.

- **CA04. Protección efectiva:** Pantallas, consultas y operaciones requieren sesión y permisos. Abrir una dirección o alterar una solicitud no permite consultar carteras ajenas.

- **CA05. Login limpio:** Se eliminan el panel y los accesos rápidos de cuentas de demostración. No se muestran ni precargan contraseñas de prueba.

- **CA06. Resultado:** Se abre Préstamos con la cartera propia, el asesor y su agencia identificados. Las contraseñas no se conservan en texto plano.

### HU-02 Cerrar sesión

Como asesor de ventas, quiero cerrar mi sesión, para impedir que otra persona opere con mi cuenta.

#### Criterios de aceptación

- **CA01. Opción disponible:** Cerrar sesión está visible durante una sesión activa.

- **CA02. Finalización:** La sesión se invalida y se vuelve al acceso. Volver atrás o entrar a una ruta protegida exige autenticarse otra vez.

- **CA03. Borradores:** Se advierte antes de salir, recargar o cerrar sesión con datos sin confirmar. El cliente nuevo en borrador se descarta al abandonar y no aparece en Clientes. Una revalidación existente ya guardada y las operaciones confirmadas permanecen.

## Épica Gestionar préstamos y cobranza

Las HU-03 a HU-08 comparten identidad, préstamos, cronogramas y pagos. La condición financiera se deriva de las obligaciones del cliente y no se cambia manualmente. Los datos contractuales confirmados permanecen sin edición; los pagos se registran como nuevas operaciones.

### HU-03 Validar y registrar cliente

Como asesor de ventas, quiero verificar la identidad y vigencia del DNI, para registrar un cliente confiable o revalidar su ficha antes de un nuevo préstamo.

#### Criterios de aceptación

- **CA01. Documento admitido:** DNI de exactamente ocho dígitos numéricos para una persona natural peruana. Se conservan ceros iniciales; letras, signos e ingreso incompleto impiden consultar. Se valida en pantalla y servidor. RUC y extranjería quedan fuera del incremento.

- **CA02. Entrada y borrador:** Nuevo préstamo comprueba el DNI en las cinco agencias. Reutiliza la ficha aprobada y vigente sin duplicar ni repetir consulta externa; revalida la pendiente, incompleta o caducada. El nuevo conserva identidad y evidencia solo en memoria al continuar al paso 2; se registra al confirmar el paso 3. Abandonar o recargar descarta el borrador.

- **CA03. Identidad exacta:** Para el registro nuevo o la revalidación necesaria se consulta la fuente de identidad seleccionada. Se conservan nombres y apellidos originales, incluidas tildes, sin edición manual. Corregir el DNI exige repetir la comprobación interna y, si corresponde, la consulta de identidad.

- **CA04. Vigencia acreditada:** Se registra la fecha de caducidad y la revisión del DNI original. Si la fuente no acredita vigencia o ausencia de fallecimiento, se registra evidencia oficial suficiente para cada condición antes de aprobar. No se inventan datos ausentes de la API.

- **CA05. Estados separados:** La verificación puede estar Pendiente, Aprobada, Caducada o Rechazada. No depende de que el cliente tenga mora. Fallecido no es una condición financiera seleccionable por el asesor.

- **CA06. Caducidad automática:** El DNI es vigente hasta su fecha de caducidad inclusive; desde el día siguiente se bloquea un nuevo préstamo. Una revalidación requiere evidencia del documento renovado, no solo pulsar Habilitar.

- **CA07. Fallo o rechazo:** Un DNI inexistente, una condición no admisible o una consulta inconclusa impiden aprobar. Se informa el motivo y se permite reintentar, sin dar por válida una identidad por el solo formato.

- **CA08. Revalidación independiente:** Guardar verificación y continuar actualiza al cliente existente aunque no finalice otro préstamo, con aviso previo. Se conservan fuente, resultado, caducidad, evidencia, fecha, asesor y agencia; el cambio se comparte entre las cinco agencias sin borrar historial ni eliminar mora. Pagar no exige renovar DNI.

### HU-04 Registrar préstamo

Como asesor de ventas, quiero registrar el monto y plazo de un cliente elegible, para formalizar su préstamo sin superar el capital permitido.

#### Criterios de aceptación

- **CA01. Cliente previo:** Se reutiliza el cliente de HU-03 o de su ficha. No se vuelven a escribir DNI y nombre ni se abre un buscador general dentro del formulario del préstamo.

- **CA02. Elegibilidad automática:** Al iniciar y al confirmar se exige verificación Aprobada, DNI vigente, sin fallecimiento acreditado, sin mora ni estado extrajudicial y con historial conciliado. El asesor no puede anular estos bloqueos manualmente.

- **CA03. Datos de sesión:** La fecha es la del día de operación en Perú. Agencia de origen y asesor se obtienen de la sesión y no son editables.

- **CA04. Monto:** Valor numérico positivo, con hasta dos decimales. Se admite menos de S/ 1 000 para pruebas; no se permite cero ni un monto negativo.

- **CA05. Capital global:** El capital pendiente de todos los préstamos del cliente en las cinco agencias más el monto solicitado no supera S/ 10 000. Se descuenta solo la amortización de capital efectivamente pagada; no todo el importe cobrado. No se suman los montos originales como si nunca se amortizaran.

- **CA06. Concurrencia:** La validación de elegibilidad y capital se repite al confirmar mediante una operación indivisible que evita exceder el límite con solicitudes simultáneas.

- **CA07. Plazo y tasa:** Plazo entero de 1 a 60 meses y TEA fija del 30 % visible. No se acepta un plazo decimal ni se agrega 30 % fijo a cualquier duración.

- **CA08. Confirmación conjunta:** Revisar el paso 3 no guarda datos. Al confirmar se guardan cliente nuevo, verificación, préstamo y cuotas en una sola transacción; cualquier fallo revierte todo. En el existente se conserva su ficha y la revalidación ya guardada. La clave de operación evita duplicados por doble clic o reintentos. Si la consulta firmada del nuevo supera 30 minutos, se exige volver al paso 1.

- **CA09. Resultado protegido:** El préstamo confirmado pertenece a la agencia de la sesión y solo se consulta por acceso ordinario desde ella. El cliente aparece también en su listado de Clientes, sin duplicar la ficha ni trasladar préstamos anteriores. No se editan o anulan condiciones en este sprint; los pagos se registran por HU-07.

### HU-05 Generar y entregar cronograma

Como asesor de ventas, quiero generar y entregar el cronograma, para que el cliente conozca sus cuotas mensuales, intereses y vencimientos.

#### Criterios de aceptación

- **CA01. Entradas:** Se utilizan monto, fecha, plazo y TEA de HU-04. Se genera una cuota por mes del plazo.

- **CA02. Cálculo:** TEM = (1 + 0,30)^(1/12) − 1, aproximadamente 2,210445 %. Se aplica amortización francesa: interés sobre capital pendiente y amortización como diferencia entre cuota e interés. La base convencional de 360 días no convierte las fechas en intervalos fijos de 30 días.

- **CA03. Fechas mensuales:** Cada fecha se obtiene sumando meses a la fecha original del préstamo. Se conserva el día original; si falta, se toma el último día del mes. Se consideran bisiestos y no se desplaza por fines de semana.

- **CA04. Detalle:** Número, vencimiento, cuota, interés, amortización y saldo de capital programado. Se identifican cliente, código, agencia de origen, monto, plazo, TEA, TEM, total de intereses y total de cuotas.

- **CA05. Redondeo y cargos:** Dos decimales; última cuota ajustada para saldo final S/ 0,00. Sin comisiones, seguros ni penalidades adicionales.

- **CA06. Consistencia:** Se guarda el cronograma mostrado junto con el préstamo. Consultarlo o registrar pagos no lo recalcula con otra tasa o fecha; el estado de cobro se muestra por separado.

- **CA07. PDF:** Después de confirmar se descarga un PDF legible con identificación, parámetros y todas las cuotas. Reintentar una descarga fallida no genera otro préstamo.

- **CA08. Caso financiero:** Para S/ 1 000 a seis meses con la TEM definida, las primeras cinco cuotas son S/ 179,80 y la última S/ 179,77. Capital amortizado S/ 1 000, interés total S/ 78,77 y total programado S/ 1 078,77.

- **CA09. Caso de calendario:** 12/05/2026 → 12/06/2026. Para 31/01/2028, los siguientes vencimientos son 29/02/2028 y 31/03/2028. Estos ajustes no cambian la TEM mensual adoptada.

### HU-06 Consultar clientes y cartera propia

Como asesor de ventas, quiero consultar clientes y la cartera de mi agencia, para conocer su situación y recuperar los cronogramas autorizados.

#### Criterios de aceptación

- **CA01. Cartera propia:** Préstamos muestra exclusivamente operaciones originadas en la agencia de la sesión, de más recientes a más antiguas. El control también se aplica en el acceso directo al detalle y en las consultas al servidor.

- **CA02. Listado y filtros:** Activos por defecto; filtros Activos, Cancelados o Todos. Búsqueda por selector DNI exacto o Código de préstamo, limitada a la cartera propia. Columnas: código, DNI, cliente, fecha, monto original, plazo, estado Activo o Cancelado y Ver detalle. Sin columna Deuda pendiente ni botón Nuevo préstamo.

- **CA03. Clientes de la agencia:** El listado y su búsqueda muestran solo clientes registrados en la agencia actual o con algún préstamo otorgado allí, conservando el vínculo aunque el préstamo se cancele. Muestra DNI, nombre, verificación y condición de pago, sin Validar cliente ni edición manual. Haber pagado aquí un préstamo ajeno no incorpora al cliente al listado; no hay búsqueda global de clientes en esta pantalla.

- **CA04. Ficha y privacidad de cartera:** Solo se abre ordinariamente la ficha de un cliente vinculado a la agencia. La ficha única muestra vigencia del DNI, historial de verificación, condición de pago y capital pendiente y disponible globales. El detalle de préstamos sigue limitado a la agencia propia. Nuevo préstamo recupera por DNI la ficha ajena solo para atender esa solicitud; los saldos globales no permiten explorar carteras ajenas.

- **CA05. Continuar atención:** Solicitar préstamo lleva a HU-04 con ese cliente. Si corresponde revalidar, se abre HU-03 conservando el contexto. Estas acciones son accesos al flujo de atención, no edición de la ficha desde el listado.

- **CA06. Resumen del detalle:** Tres cuadros principales: Total a pagar (suma de cuotas originales), Total pagado (cobros confirmados) y Saldo por pagar (diferencia). Se presentan en una fila en escritorio y se adaptan en móvil. El estado va junto al título; TEA, TEM e interés total programado en Datos del préstamo. El capital pendiente se consulta en el resumen del cliente. El interés no se suma otra vez como cargo adicional.

- **CA07. Cuotas y acceso al cobro:** Cada cuota muestra importe, interés, capital, vencimiento y estado. El historial identifica fecha, importe, asesor y agencia de cobro. Registrar pago abre HU-07 con el préstamo y las cuotas cargados automáticamente, sin pulsar Consultar cuotas. La carga no confirma un pago; no se marca Pagada o No pagada sin una operación.

- **CA08. Cobro entre agencias:** Un préstamo ajeno no aparece en la cartera ni se abre por acceso ordinario. Se localiza específicamente en Pagos por DNI o código, con los datos necesarios para cobrar y conservando su agencia de origen.

- **CA09. Documento y resultados vacíos:** Se recupera el PDF guardado sin alterar el préstamo. Una búsqueda sin coincidencias informa el resultado sin mostrar otros clientes ni registros ajenos a los permisos.

- **CA10. Formato de búsqueda:** DNI exacto acepta solo ocho dígitos numéricos y conserva ceros iniciales. Código de préstamo muestra PR- fijo y exige ocho caracteres hexadecimales (0 a 9 y A a F), convertidos a mayúsculas. Pegar el código completo no duplica el prefijo. Un valor incompleto o inválido impide consultar y muestra el motivo. Se valida en pantalla y servidor sin ampliar permisos.

### HU-07 Registrar pago de cuotas

Como asesor de ventas, quiero registrar el pago de cuotas de un préstamo, incluso de otra agencia, para actualizar la deuda y entregar constancia del cobro.

#### Criterios de aceptación

- **CA01. Localización:** Pagos ofrece el selector DNI exacto o Código de préstamo y el botón Consultar cuotas. Consulta obligaciones de cualquiera de las cinco agencias: por DNI muestra préstamos con saldo de ese cliente para elegir uno; por código carga el préstamo específico, identificando su agencia de origen. No ofrece cartera global para explorar. Desde Registrar pago en el detalle ejecuta la consulta automáticamente y conserva el buscador disponible.

- **CA02. Datos de revisión:** Se muestran titular, código, agencia de origen, deuda y cuotas pendientes del préstamo. No se exige DNI vigente ni ausencia de mora para aceptar el pago de una obligación existente.

- **CA03. Selección:** Se selecciona una o varias cuotas completas consecutivas, comenzando por la pendiente más antigua del préstamo. Se admite cubrir la próxima cuota programada sin recalcularla; no se omiten cuotas anteriores. No se incluyen abonos parciales ni pagos extraordinarios a capital.

- **CA04. Importe y confirmación:** El importe se obtiene sumando las cuotas seleccionadas y no se escribe libremente. Se revisa el resumen y se confirma solo cuando el asesor ha recibido el dinero. No es una integración bancaria ni una casilla reversible.

- **CA05. Trazabilidad:** Se genera identificador de pago y se guardan importe, fecha y hora, asesor, agencia de cobro, préstamo y aplicación por cuota. La agencia de origen permanece inalterada. Se emite una constancia recuperable del pago registrado.

- **CA06. Registro consistente:** Pago, aplicación y saldos se actualizan conjuntamente. El doble clic, el reintento o dos agencias cobrando la misma cuota no duplican el cobro; si falla la operación no queda un pago parcialmente aplicado.

- **CA07. Efectos:** Las cuotas cubiertas pasan a Pagada, disminuyen deuda y capital pendiente según su amortización y se recalcula la condición del cliente. Si todas las cuotas están pagadas, el préstamo pasa a Cancelado por pago total.

- **CA08. Conservación:** No se sobrescribe el cronograma original ni se desmarca un pago confirmado. Reversos, devoluciones o correcciones de cobros quedan fuera de este sprint; la constancia no se presenta como comprobante tributario.

- **CA09. Validación de búsqueda:** Se aplican las mismas reglas que en HU-06 CA10: DNI numérico de ocho dígitos o PR- fijo más ocho caracteres hexadecimales. Se admite pegar el código completo sin duplicar el prefijo. Se valida en pantalla y servidor antes de consultar; un error no muestra otros registros.

- **CA10. Relación con la agencia:** Cobrar un préstamo de otra agencia registra la agencia que recibió el dinero, pero no cambia la agencia de origen ni incorpora por sí solo al cliente al listado de Clientes de la agencia de cobro.

### HU-08 Actualizar estados automáticamente

Como asesor de ventas, quiero que el sistema determine la deuda y condición del cliente, para impedir nuevos préstamos cuando tenga cuotas atrasadas sin cambiar estados manualmente.

#### Criterios de aceptación

- **CA01. Fecha de referencia:** Se usa la fecha de Perú. Una cuota impaga con vencimiento de hoy aún no está vencida; entra en mora al día siguiente.

- **CA02. Condición global:** Se consideran los préstamos del cliente en las cinco agencias. Extrajudicial tiene prioridad si alguna cuota impaga cumple 12 meses desde su vencimiento; en otro caso, con alguna cuota vencida es Moroso; sin cuotas vencidas es Habilitado financieramente.

- **CA03. Alcance de la etiqueta:** Extrajudicial es la clasificación automática del caso académico; no inicia un trámite jurídico. No se necesita registrar manualmente un mes sin pago ni seleccionar el estado.

- **CA04. Actualización efectiva:** El cálculo se realiza después de cada pago y en el cambio diario de fecha. Consultar o confirmar un préstamo revalida la situación actual aunque la tarea diaria no se haya ejecutado todavía.

- **CA05. Regularización:** Pagar una cuota recalcula el estado con las que continúen impagas. Puede pasar de Extrajudicial a Moroso o a Habilitado según corresponda. Se conserva la trazabilidad del atraso y del pago; no se borra la evidencia de identidad.

- **CA06. Independencia de identidad:** La condición financiera no cambia el resultado de verificación. Al regularizarse la deuda, una identidad aprobada y vigente sigue aprobada. Si el DNI caducó, continúa bloqueado para nuevas colocaciones hasta revalidar.

- **CA07. Capital y cierre:** El capital disponible se obtiene del límite menos el capital pendiente global. Los intereses cobrados no liberan capital. Un préstamo queda Cancelado únicamente por pago completo; terminar el plazo no equivale a cancelar deuda.

- **CA08. Caso de umbral:** Cuota impaga del 15/10/2026: Pendiente ese día, Vencida y cliente Moroso el 16/10/2026; si sigue impaga, Extrajudicial el 15/10/2027. Con otras obligaciones, manda el atraso impago más antiguo.

- **CA09. Datos incompletos:** Los préstamos históricos sin conciliación no generan estados ficticios de pago. Se identifican como pendientes de conciliación y bloquean una nueva colocación hasta completar el historial.

## Criterios de finalización del incremento

Las ocho HU cumplen sus criterios y el flujo integrado conserva los datos al cerrar sesión. La aplicación está desplegada, accesible y funcionando. Todos los integrantes pueden demostrar registro, consulta por agencia, cobro entre agencias y actualización automática de estados. No se presentan como implementadas funciones que solo estén descritas en este documento.

## Casos de verificación de la entrega

| Caso | Resultado esperado |
| --- | --- |
| Acceso y depuración | Login sin cuentas rápidas. General y Ana Morales fuera de operación, sin pérdida de datos históricos. |
| Separación por agencia | Un asesor de Chimbote no lista ni abre por URL ordinaria un préstamo de Trujillo. La ficha compartida no permite eludir esta restricción. |
| Cliente nuevo y existente | El nuevo se revisa en el paso 1 y se guarda con el préstamo al confirmar el paso 3; abandonar no crea ficha. El existente se recupera desde Clientes o por DNI en Nuevo préstamo, sin repetir una consulta externa vigente ni duplicar su ficha. |
| Identidad independiente | Un cliente con identidad aprobada entra en mora y luego paga: no se pierde su verificación. Si el DNI ya venció, requiere nueva evidencia antes de otro préstamo. |
| DNI vencido y cobro | Se rechaza el nuevo préstamo y se permite pagar una cuota existente. |
| Capital y plazo | Se rechazan montos que excedan S/ 10 000 de capital global, cero, negativos, plazos decimales y plazos fuera de 1 a 60 meses. |
| Cálculo y calendario | Se comprueba HU-05 con S/ 1 000 a seis meses, meses de 28, 29, 30 y 31 días, y recuperación del mismo PDF. |
| Cobranza entre agencias | Chimbote registra una cuota de Trujillo. El pago pertenece a Chimbote y el préstamo conserva Trujillo como origen. Solo pagar allí no incorpora al cliente al listado de Clientes de Chimbote. |
| Concurrencia y reintento | Dos confirmaciones no exceden capital disponible ni cobran dos veces una misma cuota. Un fallo no deja operaciones incompletas. |
| Estados y cierre | Se prueban el día del vencimiento, el día siguiente y los 12 meses de atraso. Al pagar todas las cuotas, se cierra la deuda y queda historial consultable. |
| Capital amortizado | Al pagar una cuota, el cupo aumenta solo por su capital. Se distinguen saldo de capital, intereses y deuda total pendiente. |
| Constancias y conciliación | La constancia puede recuperarse; un historial incompleto no se declara pagado o moroso sin conciliar. |
| Clientes por agencia | Un cliente registrado en Trujillo no aparece ni se encuentra en Clientes de Chimbote hasta recibir un préstamo allí. Entonces figura en ambas agencias con una ficha única, incluso después de cancelar sus préstamos. |
| Revalidación entre agencias | DNI vencido o verificación incompleta: se revalida en Chimbote y el resultado actualizado se refleja en Trujillo, con agencia, asesor e historial. La mora permanece hasta regularizar pagos. |
| Buscadores y formatos | DNI con letras o menos de ocho dígitos no se consulta; se conserva el cero inicial. Código con PR- fijo, ocho caracteres hexadecimales y mayúsculas; pegar PR- completo no duplica el prefijo. Préstamos y Clientes no devuelven registros ajenos al listado autorizado. |
| Detalle y acceso al pago | Tres cuadros en una fila en escritorio; estado junto al título y TEM e interés en Datos del préstamo. Registrar pago carga las cuotas automáticamente; entrar desde el menú mantiene la consulta manual y todo cobro exige confirmación. |
| Abandono y confirmación del nuevo | Continuar a condiciones y revisar el cronograma no crean cliente ni evidencia. Cancelar salida conserva el borrador; salir o recargar lo descarta. Confirmar guarda ficha, revisión, préstamo y cuotas; un fallo intermedio no deja registros parciales. |
| Revalidación sin nuevo préstamo | Guardar una revisión de un cliente existente actualiza la misma ficha y su historial para las agencias autorizadas. Abandonar luego el paso 2 no deshace esa revisión ni crea un préstamo. |
| Reintento y DNI concurrente | Repetir la confirmación devuelve el mismo préstamo. Si otro asesor registró ese DNI durante el borrador, se reutiliza la ficha vigente sin sobrescribir evidencia; de necesitar revisión, se vuelve al paso 1. |
