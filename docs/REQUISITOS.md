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
| Capital máximo | Hasta S/ 10 000 de capital pendiente del propietario, incluidos préstamos personales y empresas vinculadas de las cinco agencias. Solo la amortización pagada libera cupo. |
| Elegibilidad | Identidad aprobada y vigente, sin mora, historial conciliado y capital disponible; RUC ACTIVO/HABIDO cuando corresponda. El antecedente extrajudicial exige autorización. |
| Cobranza | Se pueden pagar cuotas de un préstamo en otra agencia. Se atienden primero las cuotas pendientes más antiguas del préstamo seleccionado. |

## Funciones de la entrega

Se atiende a personas naturales con DNI, personas naturales con negocio (RUC 10) y empresas (RUC 20). DNI y RUC 10 comparten ficha; la empresa conserva titular propio y se vincula al propietario responsable del límite global. Clientes lista solo a los titulares con préstamos confirmados en la agencia actual, incluidos los ya pagados; Préstamos lista solo operaciones originadas en esa agencia. Sus búsquedas respetan estos límites. La verificación y los saldos globales se reutilizan para evaluar nuevos préstamos, sin habilitar la consulta ordinaria de carteras ajenas.

| Área | En esta entrega | Para después |
| --- | --- | --- |
| Acceso | Iniciar y cerrar sesión, controlar 15 minutos de inactividad y mantener una sesión por cuenta, sin credenciales de demostración visibles. | Administrar cuentas y recuperar contraseñas. |
| Clientes | Consultar ficha e historial de verificación; registrar o revalidar desde el flujo del préstamo. | Otros documentos de identidad y cambios de propietario. |
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
| Cálculo mensual | Tasa mensual constante equivalente a la TEA, separada de las fechas mensuales de calendario. El interés compensatorio mantiene la tasa mensual; la mora pactada se calcula por días sobre el capital vencido. |

## Condiciones para operar

Las cuentas y las cinco agencias están preconfiguradas. Se retiran del entorno operativo la agencia General y la cuenta Ana Morales. La depuración respeta las referencias y la trazabilidad de operaciones existentes; no borra préstamos ni pagos históricos. Un registro ficticio sin referencias puede eliminarse; si tiene referencias, se regulariza antes de retirarlo y se bloquea su acceso.

Los préstamos anteriores requieren capital, cronograma y pagos conciliados. La falta de un pago histórico no demuestra por sí sola que exista mora. Un cliente con historial incompleto queda identificado como pendiente de conciliación y no obtiene nuevos préstamos hasta regularizar los datos.

## Pantallas y recorrido de atención

| Pantalla | Contenido y acciones |
| --- | --- |
| Inicio de sesión | Correo, contraseña y acceso. Sin credenciales de demostración. La agencia proviene de la cuenta. La sesión anterior se reemplaza al iniciar en otro navegador; la cabecera muestra el tiempo restante sin actividad. |
| Préstamos | Solo cartera de la agencia actual. Activos por defecto y filtro Activos, Cancelados o Todos. Código, documento del titular, cliente o razón social, fecha, monto original, plazo, estado y Ver detalle; sin columna Deuda pendiente ni botón Nuevo préstamo. Selector DNI exacto, RUC exacto o Código de préstamo con validación de formato. |
| Clientes | Listado y búsqueda limitados a titulares con préstamos confirmados en la agencia actual, incluidos los ya pagados. Filtros Todos, Personas y Empresas; DNI para personas y RUC para empresas, nombre, verificación y condición de pago. Cobrar un préstamo ajeno no incorpora al cliente al listado. Sin botón Validar cliente ni búsqueda global. |
| Ficha del cliente | Identidad compartida, datos SUNAT cuando corresponda, condición de pago, capital global y personas y empresas vinculadas. Solicitar préstamo y Revalidar datos ofrecen DNI/RUC 10 en la misma ficha. Consultar para pagar abre el grupo; Ver historial abre las revisiones en una página aparte. No contiene la tabla Préstamos en tu agencia ni selectores manuales de condición. |
| Nuevo préstamo | Paso 1: elegir DNI o RUC 10/20, comprobar identidad y representación, reutilizar ficha vigente o preparar borrador del nuevo. El tipo queda fijo en los pasos 2 y 3. Paso 2: monto y plazo. Paso 3: confirmar conjuntamente cliente nuevo, evidencia, préstamo y cronograma. La revalidación del existente se guarda aparte aunque no concluya el préstamo. |
| Detalle del préstamo | Tres cuadros: Total a pagar, Total pagado y Saldo por pagar, en una fila en escritorio y adaptables en móvil. Estado junto al título; TEA, TEM e interés total en Datos del préstamo. Cronograma e historial de cobros. Registrar pago abre Pagos con las cuotas cargadas automáticamente. |
| Pagos | Selector DNI exacto, RUC exacto o Código de préstamo para cobrar en cualquiera de las cinco agencias. DNI de ocho números; código con prefijo PR- fijo y ocho caracteres hexadecimales. Por DNI o RUC se reúne el grupo del propietario y sus empresas entre agencias; por código se carga un préstamo. Desde ficha el documento queda fijo; desde detalle quedan fijos el código y el préstamo. Conserva agencia de origen y registra agencia de cobro, sin ofrecer una cartera completa sin búsqueda dirigida. |

El menú del asesor contiene Préstamos, Clientes, Nuevo préstamo, Pagos y Cerrar sesión. Configuración aparece solo a quien tiene el permiso específico de mora. Los accesos desde ficha o detalle llevan a esos mismos procesos, sin formularios de negocio duplicados.

## Recorrido del cliente nuevo y del cliente existente

Nuevo préstamo: elegir DNI o RUC → comprobar si existe en las cinco agencias → reutilizar ficha vigente, revalidar al existente o preparar datos del nuevo → completar monto y plazo → revisar cronograma → confirmar. El nuevo permanece como borrador en memoria hasta el paso 3: no se registra ni aparece en Clientes antes de confirmar. La detección por DNI no es un buscador global y una identidad vigente no repite consulta externa por cambiar de agencia.

Cliente del listado propio: Clientes → abrir ficha → Solicitar préstamo. Cliente de otra agencia: Nuevo préstamo → ingresar DNI y recuperar ficha. Si requiere revalidación, Guardar verificación y continuar actualiza su identidad para las cinco agencias aunque no termine el préstamo; no genera crédito ni elimina mora. Una verificación rechazada o fallecimiento acreditado no se omiten. La respuesta verbal no sustituye la comprobación por DNI.

Cobranza desde el menú: Pagos → elegir DNI exacto, RUC exacto o Código de préstamo → consultar → elegir préstamo si corresponde → revisar cuotas y agencia de origen → seleccionar cuotas consecutivas → confirmar cobro → entregar constancia. Desde Registrar pago en el detalle se cargan automáticamente el préstamo y sus cuotas, sin pulsar Consultar cuotas. Un DNI vencido o la mora no impiden pagar; bloquean únicamente nuevas colocaciones.

## Estados y datos que deben conservarse

| Concepto | Estados y regla |
| --- | --- |
| Verificación de identidad | Pendiente, Aprobada, Caducada o Rechazada. Aprobada exige identidad confiable, documento vigente y evidencia suficiente de las condiciones exigidas. |
| Condición de pago del cliente | Sin atrasos (valor interno habilitado) si no tiene cuotas vencidas impagas; Moroso si tiene atraso menor de 12 meses; Extrajudicial si al menos una cuota impaga cumple 12 meses de atraso. Son estados automáticos del grupo, con prioridad de Extrajudicial sobre Moroso; un historial incompleto se identifica como Pendiente de conciliación. |
| Préstamo | Activo mientras quede deuda contractual pendiente; Cancelado por pago total cuando todas sus cuotas estén pagadas. Cancelado no significa anulado. |
| Cuota | Pendiente antes de vencer o durante su fecha de vencimiento; Vencida desde el día siguiente si no está pagada; Pagada únicamente si existe un cobro confirmado que la cubra. |

La condición de pago no cambia la verificación de identidad. Un cliente puede tener verificación Aprobada y condición Moroso, o condición Sin atrasos y DNI Caducado. En ambos casos se bloquea un nuevo préstamo. Cambiar un saldo nunca borra la fecha, la fuente o la evidencia de una verificación.

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
| Redondeo y cargos | De 1 a 60 cuotas, dos decimales y saldo final cero. Sin comisiones, seguros ni penalidades. La mora se separa del interés original y solo se cobra cuando el préstamo tiene una tasa pactada. |
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

- **CA06. Resultado:** Se abre Préstamos con la cartera propia. La cabecera identifica nombre y rol, agencia, fecha de Perú y tiempo restante de sesión, en ese orden. Las contraseñas no se conservan en texto plano.

- **CA07. Sesión única:** Un nuevo inicio válido reemplaza al anterior de esa cuenta. La base rechaza operaciones de la sesión anterior y la interfaz la detecta en el siguiente control, hasta 15 segundos con conexión. Varias pestañas del mismo navegador comparten sesión.

- **CA08. Inactividad:** El tiempo máximo es 15 minutos sin interacción. Teclado, puntero y desplazamiento renuevan la actividad con envíos limitados; las consultas automáticas no la renuevan. El contador usa la referencia del servidor y una sesión vencida no se reactiva con el mismo identificador.

### HU-02 Cerrar sesión

Como asesor de ventas, quiero cerrar mi sesión, para impedir que otra persona opere con mi cuenta.

#### Criterios de aceptación

- **CA01. Opción disponible:** Cerrar sesión está visible durante una sesión activa.

- **CA02. Finalización:** Se invalida la sesión actual y se vuelve al acceso. Volver atrás o abrir una ruta protegida exige autenticarse otra vez. Cerrar una sesión antigua no revoca una sesión posterior en otra computadora.

- **CA03. Borradores:** Se advierte antes de abandonar o cerrar manualmente con datos sin confirmar. Al vencer la sesión o ser reemplazada, el cierre es obligatorio y los borradores se pierden. Las verificaciones ya guardadas y las operaciones confirmadas permanecen.

## Épica Gestionar préstamos y cobranza

Las HU-03 a HU-08 comparten identidad, préstamos, cronogramas y pagos. La condición financiera se deriva de las obligaciones del cliente y no se cambia manualmente. Los datos contractuales confirmados permanecen sin edición; los pagos se registran como nuevas operaciones.

- **CA04. Aviso de vencimiento:** El contador se vuelve ámbar en los últimos dos minutos y rojo en el último. Durante el último minuto se ofrece Continuar sesión o Cerrar sesión. Continuar solo renueva una sesión que siga válida.

- **CA05. Cierre obligatorio:** La inactividad, una sesión reemplazada o una cuenta sin acceso bloquean las operaciones y devuelven al inicio con su motivo.

### HU-03 Validar y registrar cliente

Como asesor de ventas, quiero verificar la identidad y vigencia del DNI, para registrar un cliente confiable o revalidar su ficha antes de un nuevo préstamo.

#### Criterios de aceptación

- **CA01. Documento admitido:** DNI de exactamente ocho dígitos numéricos para una persona natural peruana. Se conservan ceros iniciales; letras, signos e ingreso incompleto impiden consultar. Se valida en pantalla y servidor. RUC 10 y RUC 20 se admiten con validación de formato, dígito verificador y consulta externa firmada. Extranjería queda fuera del incremento.

- **CA02. Entrada y borrador:** Nuevo préstamo comprueba el DNI en las cinco agencias. Reutiliza la ficha aprobada y vigente sin duplicar ni repetir consulta externa; revalida la pendiente, incompleta o caducada. El nuevo conserva identidad y evidencia solo en memoria al continuar al paso 2; se registra al confirmar el paso 3. Abandonar o recargar descarta el borrador.

- **CA03. Identidad exacta:** Para el registro nuevo o la revalidación necesaria se consulta la fuente de identidad seleccionada. Se conservan nombres y apellidos originales, incluidas tildes, sin edición manual. Corregir el DNI exige repetir la comprobación interna y, si corresponde, la consulta de identidad.

- **CA04. Vigencia acreditada:** Se registra la fecha de caducidad y la revisión del DNI original. El asesor confirma mediante dos casillas la revisión del DNI original y la presencia física del cliente. Las referencias se generan automáticamente y describen esa revisión presencial; no acreditan una consulta oficial de fallecimiento ni inventan datos ausentes de la API.

- **CA05. Estados separados:** La verificación puede estar Pendiente, Aprobada, Caducada o Rechazada. No depende de que el cliente tenga mora. Fallecido no es una condición financiera seleccionable por el asesor.

- **CA06. Caducidad automática:** El DNI es vigente hasta su fecha de caducidad inclusive; desde el día siguiente se bloquea un nuevo préstamo. Una revalidación requiere evidencia del documento renovado, no solo pulsar Habilitar.

- **CA07. Fallo o rechazo:** Un documento inexistente o una consulta inconclusa impiden completar esa verificación. Un error técnico o de disponibilidad no se guarda como rechazo de identidad. Se permite reintentar; el formato por sí solo no acredita identidad.

- **CA08. Revalidación independiente:** Guardar una verificación existente actualiza la misma ficha y conserva historial, fuente, evidencia, fecha, asesor y agencia aunque no finalice otro préstamo. Desde ficha se consulta automáticamente el documento fijo y se vuelve a la ficha al guardar. La acción sigue disponible con datos vigentes; no elimina mora ni requiere crear un préstamo.

- **CA09. SUNAT y alcance:** Actualizar datos SUNAT compara nombre o razón social, estado, condición y domicilio con lo guardado. Permite guardar una consulta firmada aunque no haya cambios o el RUC esté observado; conserva fecha e historial. Los datos del proveedor no se editan manualmente. No equivale a revalidar DNI, propiedad ni facultades.

- **CA10. Representación:** En RUC 20 el propietario puede firmar si tiene facultades, o puede acudir otro representante. El propietario ausente debe tener identidad previa aprobada y vigente; no recibe verificación presencial nueva. El firmante debe estar presente. Se revisan propiedad/designación y facultades con tipo y referencia breve; un mismo documento puede acreditar ambas, con dos confirmaciones separadas.

### HU-04 Registrar préstamo

Como asesor de ventas, quiero registrar el monto y plazo de un cliente elegible, para formalizar su préstamo sin superar el capital permitido.

#### Criterios de aceptación

- **CA01. Cliente previo:** Se reutiliza el cliente de HU-03 o de su ficha. No se vuelven a escribir DNI y nombre ni se abre un buscador general dentro del formulario del préstamo.

- **CA02. Elegibilidad automática:** Al iniciar y confirmar se exige identidad aprobada y vigente, ausencia de mora, historial conciliado y capital disponible. El antecedente extrajudicial requiere autorización registrada. La modalidad DNI no exige ACTIVO/HABIDO de un RUC 10 asociado; solicitar por RUC sí exige consulta válida ACTIVO/HABIDO y, en empresa, identidad y facultades del propietario y firmante.

- **CA03. Datos de sesión:** La fecha es la del día de operación en Perú. Agencia de origen y asesor se obtienen de la sesión y no son editables.

- **CA04. Monto:** Campo inicial 0.00 con soles y centavos separados por un punto fijo. Solo admite dígitos; mínimo S/ 0.01 y máximo el capital disponible del propietario, hasta S/ 10 000. No acepta signos, letras ni más de dos cifras de centavos; cero impide continuar. El servidor repite la validación.

- **CA05. Capital global:** El capital pendiente del propietario y todas sus empresas vinculadas entre agencias más la nueva solicitud no supera S/ 10 000. Solo la amortización efectivamente pagada libera cupo; los intereses no lo liberan. Un representante sin vínculo de propiedad no aporta su límite al grupo.

- **CA06. Concurrencia:** La validación de elegibilidad y capital se repite al confirmar mediante una operación indivisible que evita exceder el límite con solicitudes simultáneas.

- **CA07. Plazo y tasa:** Campo inicial 0 y entrada solo de dígitos enteros hasta 60. Para continuar se exige de 1 a 60 meses; no se admiten signos ni decimales. La TEA fija del 30 % es visible y no se suma como un porcentaje plano a cualquier duración.

- **CA08. Confirmación conjunta:** Revisar el paso 3 no guarda datos. Al confirmar se guardan cliente nuevo, verificación, préstamo y cuotas en una sola transacción; cualquier fallo revierte todo. En el existente se conserva su ficha y la revalidación ya guardada. La clave de operación evita duplicados por doble clic o reintentos. Si la consulta firmada del nuevo supera 30 minutos, se exige volver al paso 1.

- **CA09. Resultado protegido:** El préstamo confirmado pertenece a la agencia de la sesión y solo se consulta por acceso ordinario desde ella. El cliente aparece también en su listado de Clientes, sin duplicar la ficha ni trasladar préstamos anteriores. No se editan o anulan condiciones en este sprint; los pagos se registran por HU-07.

- **CA10. Pasos y regreso:** El tipo de cliente se elige solo en el paso 1, que no muestra Volver. En los pasos 2 y 3 queda fijo. Volver del cronograma conserva condiciones; volver desde condiciones a identificación requiere confirmar el descarte cuando corresponde. Hay una sola acción Continuar a condiciones y no se añade Consultar clientes dentro del flujo.

### HU-05 Generar y entregar cronograma

Como asesor de ventas, quiero generar y entregar el cronograma, para que el cliente conozca sus cuotas mensuales, intereses y vencimientos.

#### Criterios de aceptación

- **CA01. Entradas:** Se utilizan monto, fecha, plazo y TEA de HU-04. Se genera una cuota por mes del plazo.

- **CA02. Cálculo:** TEM = (1 + 0,30)^(1/12) − 1, aproximadamente 2,210445 %. Se aplica amortización francesa: interés sobre capital pendiente y amortización como diferencia entre cuota e interés. La base convencional de 360 días no convierte las fechas en intervalos fijos de 30 días.

- **CA03. Fechas mensuales:** Cada fecha se obtiene sumando meses a la fecha original del préstamo. Se conserva el día original; si falta, se toma el último día del mes. Se consideran bisiestos y no se desplaza por fines de semana.

- **CA04. Detalle:** Número, vencimiento, cuota, interés, amortización y saldo de capital programado. Se identifican cliente, código, agencia de origen, monto, plazo, TEA, TEM, total de intereses y total de cuotas.

- **CA05. Redondeo y cargos:** Dos decimales; última cuota ajustada para saldo final S/ 0,00. Sin comisiones, seguros ni penalidades. La mora pactada se calcula por separado del cronograma.

- **CA06. Consistencia:** Se guarda el cronograma mostrado junto con el préstamo. Consultarlo o registrar pagos no lo recalcula con otra tasa o fecha; el estado de cobro se muestra por separado.

- **CA07. Descarga e impresión:** Después de confirmar, Cronograma ofrece descargar PDF o imprimir desde una vista protegida. Contrato ofrece Word o impresión y guardado como PDF desde el navegador. Reintentar una descarga no crea otro préstamo.

- **CA08. Caso financiero:** Para S/ 1 000 a seis meses con la TEM definida, las primeras cinco cuotas son S/ 179,80 y la última S/ 179,77. Capital amortizado S/ 1 000, interés total S/ 78,77 y total programado S/ 1 078,77.

- **CA09. Caso de calendario:** 12/05/2026 → 12/06/2026. Para 31/01/2028, los siguientes vencimientos son 29/02/2028 y 31/03/2028. Estos ajustes no cambian la TEM mensual adoptada.

### HU-06 Consultar clientes y cartera propia

Como asesor de ventas, quiero consultar clientes y la cartera de mi agencia, para conocer su situación y recuperar los cronogramas autorizados.

#### Criterios de aceptación

- **CA01. Cartera propia:** Préstamos muestra exclusivamente operaciones originadas en la agencia de la sesión, de más recientes a más antiguas. El control también se aplica en el acceso directo al detalle y en las consultas al servidor.

- **CA02. Listado y filtros:** Activos por defecto; filtros Activos, Cancelados o Todos y tipo Todos, Personas o Empresas. Búsqueda por DNI exacto, RUC exacto o Código de préstamo en la cartera propia. Documento muestra DNI en personas y RUC en empresas; se conservan fecha, monto original, plazo, estado y Ver detalle, sin columna Deuda pendiente.

- **CA03. Clientes de la agencia:** Listado y búsqueda muestran solo titulares con algún préstamo confirmado en la agencia, incluidos los ya pagados. Un registro sin préstamo local, una empresa vinculada sin cartera local o un representante sin préstamo propio no se incorporan por ese motivo. Cobrar un préstamo ajeno tampoco incorpora al titular.

- **CA04. Ficha y privacidad de cartera:** DNI y RUC 10 comparten una ficha; cada RUC 20 conserva ficha propia vinculada al propietario. Las agencias con acceso al grupo ven identidad y vínculos compartidos, sin ampliar su cartera de préstamos. La ficha resumida muestra identificación, condición de pago, capital y vínculos; los historiales se abren aparte. No incluye la tabla Préstamos en tu agencia.

- **CA05. Continuar atención:** Solicitar préstamo despliega Personal DNI y Negocio RUC 10 cuando existen ambos documentos; con una sola modalidad entra directamente. Sin capital o elegibilidad queda bloqueado. Revalidar datos ofrece DNI o RUC 10 en la ficha; RUC 20 abre SUNAT. Consultar para pagar conserva el titular y Ver historial ofrece DNI/RUC según corresponda.

- **CA06. Resumen del detalle:** Tres cuadros principales: Total a pagar (cuotas originales y mora pactada), Total pagado (cobros confirmados) y Saldo por pagar (diferencia). Se presentan en una fila en escritorio y se adaptan en móvil. El estado va junto al título; TEA, TEM e interés total programado en Datos del préstamo. El capital pendiente se consulta en el resumen del cliente. El interés no se suma otra vez como cargo adicional.

- **CA07. Cuotas y acceso al cobro:** Cada cuota muestra importe, interés, capital, vencimiento y estado. Registrar pago abre Pagos con el préstamo y sus cuotas cargados automáticamente, con código y tipo fijos y regreso al mismo detalle. Se desplaza al titular seleccionado; la carga no confirma el cobro.

- **CA08. Cobro entre agencias:** Un préstamo ajeno no aparece en la cartera local ni se abre por su detalle ordinario. Pagos lo localiza por DNI, RUC o código para cobrar, conserva su agencia de origen y muestra las obligaciones del grupo del propietario cuando se consulta por documento.

- **CA09. Documento y resultados vacíos:** Se recupera el PDF guardado sin alterar el préstamo. Una búsqueda sin coincidencias informa el resultado sin mostrar otros clientes ni registros ajenos a los permisos.

- **CA10. Formato de búsqueda:** DNI exacto acepta solo ocho dígitos numéricos y conserva ceros iniciales. Código de préstamo muestra PR- fijo y exige ocho caracteres hexadecimales (0 a 9 y A a F), convertidos a mayúsculas. Pegar el código completo no duplica el prefijo. Un valor incompleto o inválido impide consultar y muestra el motivo. Se valida en pantalla y servidor sin ampliar permisos.

### HU-07 Registrar pago de cuotas

Como asesor de ventas, quiero registrar el pago de cuotas de un préstamo, incluso de otra agencia, para actualizar la deuda y entregar constancia del cobro.

#### Criterios de aceptación

- **CA01. Localización:** Pagos general permite DNI, RUC o código. DNI, RUC 10 o RUC 20 consultan las obligaciones del mismo propietario y sus empresas entre agencias; el representante por sí solo no une grupos. Desde ficha el documento queda fijo y desde detalle el préstamo queda fijo por su UUID autorizado. Ambos consultan automáticamente y ofrecen regreso al origen, sin Cambiar cliente.

- **CA02. Datos de revisión:** Se muestran titular, código, agencia de origen, deuda y cuotas pendientes del préstamo. No se exige DNI vigente ni ausencia de mora para aceptar el pago de una obligación existente.

- **CA03. Selección:** Se selecciona una o varias cuotas completas consecutivas, comenzando por la pendiente más antigua del préstamo. Se admite cubrir la próxima cuota programada sin recalcularla; no se omiten cuotas anteriores. No se incluyen abonos parciales ni pagos extraordinarios a capital.

- **CA04. Importe y confirmación:** El importe se obtiene sumando las cuotas seleccionadas y su mora pactada calculada a la fecha de Perú y no se escribe libremente. Se revisa el resumen y se confirma solo cuando el asesor ha recibido el dinero. No es una integración bancaria ni una casilla reversible.

- **CA05. Trazabilidad:** Se genera identificador de pago y se guardan importe, fecha y hora, asesor, agencia de cobro, préstamo y aplicación por cuota. La agencia de origen permanece inalterada. Se emite una constancia recuperable del pago registrado.

- **CA06. Registro consistente:** Pago, aplicación y saldos se actualizan conjuntamente. El doble clic, el reintento o dos agencias cobrando la misma cuota no duplican el cobro; si falla la operación no queda un pago parcialmente aplicado.

- **CA07. Efectos:** Las cuotas cubiertas pasan a Pagada, disminuyen deuda y capital pendiente según su amortización y se recalcula la condición del cliente. Si todas las cuotas están pagadas, el préstamo pasa a Cancelado por pago total.

- **CA08. Conservación:** No se sobrescribe el cronograma original ni se desmarca un pago confirmado. Reversos, devoluciones o correcciones de cobros quedan fuera de este sprint; la constancia no se presenta como comprobante tributario.

- **CA09. Validación de búsqueda:** Se aplican las mismas reglas que en HU-06 CA10: DNI de ocho dígitos, RUC válido de once dígitos o PR- fijo más ocho caracteres hexadecimales. Se admite pegar el código completo sin duplicar el prefijo. Se valida en pantalla y servidor antes de consultar; un error no muestra otros registros.

- **CA10. Relación con la agencia:** Cobrar un préstamo de otra agencia registra la agencia que recibió el dinero, pero no cambia la agencia de origen ni incorpora por sí solo al cliente al listado de Clientes de la agencia de cobro.

- **CA11. Cambio de consulta:** Solo Pagos general permite editar documento o tipo. Cualquier cambio limpia resultados, selección de préstamo, cuotas y confirmación de dinero recibido; las respuestas antiguas se descartan. Desde ficha o detalle se conservan los campos fijos y el enlace de regreso al mismo origen.

- **CA12. Desplazamiento y revisión:** Elegir préstamo o cargar un resultado único desplaza y enfoca el recuadro del titular con margen superior de 8 px. La lista con varios resultados no fuerza el desplazamiento. Cambiar cantidad de cuotas no repite el movimiento; se respeta reducir animaciones y permanecen los indicadores de foco de controles.

### HU-08 Actualizar estados automáticamente

Como asesor de ventas, quiero que el sistema determine la deuda y condición del cliente, para impedir nuevos préstamos cuando tenga cuotas atrasadas sin cambiar estados manualmente.

#### Criterios de aceptación

- **CA01. Fecha de referencia:** Se usa la fecha de Perú. Una cuota impaga con vencimiento de hoy aún no está vencida; entra en mora al día siguiente.

- **CA02. Condición global:** Se consideran la persona y sus empresas vinculadas entre agencias. Extrajudicial tiene prioridad a los doce meses de la cuota impaga más antigua; con atrasos menores es Moroso y sin cuotas vencidas se muestra Sin atrasos, cuyo valor interno es habilitado. Un historial incompleto se identifica como Pendiente de conciliación.

- **CA03. Alcance de la etiqueta:** Extrajudicial es la clasificación automática del caso académico; no inicia un trámite jurídico. No se necesita registrar manualmente un mes sin pago ni seleccionar el estado.

- **CA04. Actualización efectiva:** El cálculo se realiza después de cada pago y en el cambio diario de fecha. Consultar o confirmar un préstamo revalida la situación actual aunque la tarea diaria no se haya ejecutado todavía.

- **CA05. Regularización:** Pagar una cuota recalcula el estado con las que continúen impagas. Puede pasar de Extrajudicial a Moroso o a Sin atrasos según corresponda. El antecedente extrajudicial se conserva y exige autorización registrada para nuevos préstamos. Se conserva la trazabilidad del atraso y del pago; no se borra la evidencia de identidad.

- **CA06. Independencia de identidad:** La condición financiera no cambia el resultado de verificación. Al regularizarse la deuda, una identidad aprobada y vigente sigue aprobada. Si el DNI caducó, continúa bloqueado para nuevas colocaciones hasta revalidar.

- **CA07. Capital y cierre:** El capital disponible se obtiene del límite menos el capital pendiente global. Los intereses cobrados no liberan capital. Un préstamo queda Cancelado únicamente por pago completo; terminar el plazo no equivale a cancelar deuda.

- **CA08. Caso de umbral:** Cuota impaga del 15/10/2026: Pendiente ese día, Vencida y cliente Moroso el 16/10/2026; si sigue impaga, Extrajudicial el 15/10/2027. Con otras obligaciones, manda el atraso impago más antiguo.

- **CA09. Datos incompletos:** Los préstamos históricos sin conciliación no generan estados ficticios de pago. Se identifican como pendientes de conciliación y bloquean una nueva colocación hasta completar el historial.

## Criterios de finalización del incremento

Las ocho HU describen el incremento integrado y sus comprobaciones. Al cerrar sesión se conservan los datos confirmados, no los borradores. El despliegue debe verificarse con la versión integrada antes de declarar completada la entrega. Todos los integrantes pueden demostrar registro, consulta por agencia, cobro entre agencias y actualización automática de estados. No se presentan como implementadas funciones que solo estén descritas en este documento.

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
| Sesión e inactividad | El contador aparece después de la fecha; el aviso surge en el último minuto, Continuar renueva una sesión válida y a los 15 minutos sin actividad se exige nuevo ingreso. |
| Sesión reemplazada | Iniciar la misma cuenta en otro navegador bloquea al anterior; cerrar el anterior no cierra al nuevo. |
| SUNAT y modalidades | RUC observado bloquea solicitar por ese RUC, pero no un préstamo personal DNI elegible ni el pago de deudas. Un fallo técnico no se guarda como rechazo. |
| Pagos con contexto | Desde ficha o detalle los campos quedan fijos y el regreso conserva el origen; en Pagos general cambiar documento o tipo elimina resultados anteriores. |
| Ficha e historiales | La ficha queda resumida, los vínculos respetan permisos y Ver historial abre DNI, RUC o su menú sin tabla de préstamos en la ficha. |


## Ampliación de identidad contratos y cobranza

### Atención por DNI y RUC

Se mantiene el flujo Cliente, Condiciones y Cronograma. El paso 1 ofrece DNI o RUC; RUC 10 conserva la ficha de su DNI. Para RUC 20 se identifica por separado al propietario para el límite y al representante que firma. Se validan once números, prefijo 10 o 20 y dígito verificador; la consulta externa debe coincidir con el número solicitado y exige ACTIVO y HABIDO para una nueva solicitud por RUC. Un RUC observado no impide pagar deudas existentes.

### Propiedad y capital global

Para una empresa se registra evidencia documental de propiedad y de representación. Si existen varios propietarios, se exige la designación documentada de uno como responsable del límite de este modelo académico; sin designación no se continúa. La empresa no puede reasignarse a otro propietario mediante una solicitud ordinaria. El capital de la persona y sus empresas vinculadas se suma entre agencias, con un límite de S/ 10 000 y control transaccional al confirmar.

### Contrato descargable e impresión

El detalle del préstamo confirmado permite descargar el contrato en Word y abrir una vista de impresión o guardar como PDF desde el navegador. La plantilla conserva el texto, estructura y diseño del Word del profesor; completa cliente, documento, representante, fecha y agencia. Un anexo incluye monto, plazo, tasas, totales, vencimientos y las personas vinculadas. El cronograma tiene descarga PDF e impresión separadas; los menús Cronograma y Contrato agrupan sus acciones en el detalle. Los préstamos nuevos congelan sus datos contractuales de identidad.

### Mora y aplicación de pagos

La mora comienza al día siguiente del vencimiento en la fecha de Perú. Fórmula implementada: capital vencido impago × [(1 + tasa efectiva anual moratoria)^(días de atraso / base anual) − 1], redondeada por cuota a dos decimales. La base admite 360 o 365 días. El responsable designado configura la tasa para préstamos nuevos; no existe una tasa predeterminada ni se modifican préstamos previos. Sin tasa pactada no se agrega mora. Los pagos cubren cuotas completas consecutivas desde la más antigua, incluyendo capital, interés original y mora de cada cuota seleccionada. No se incluyen abonos parciales ni penalidades.

### Regularización y antecedente extrajudicial

Cubrir todo lo vencido y exigible permite quedar al día sin anticipar cuotas futuras. La clasificación extrajudicial se alcanza a los doce meses calendario desde el vencimiento impago más antiguo; otro pago no reinicia el plazo. Se conserva el antecedente incluso tras cancelar el préstamo. La autorización para nuevas colocaciones corresponde a un asesor designado con permiso especial y exige motivo, ausencia de cuotas vencidas e historial conciliado. Autorizar no omite identidad, RUC ni límite de capital.

### Permisos y definiciones de la entrega

La tasa moratoria y la persona que autoriza deben ser definidas por el responsable del parcial. La implementación permite configurarlas, pero no asigna automáticamente privilegios ni inventa una tasa. El administrador registra los permisos de autorización y configuración. Se mantiene la visibilidad por agencia y el pago entre agencias; las personas nuevas, empresa, evidencia, préstamo y cuotas se guardan conjuntamente al confirmar. Las revalidaciones ya guardadas de personas existentes se conservan al abandonar.

### Observaciones del modelo del profesor

La plantilla original se conserva en Contrato_profesor.docx. Se identificaron denominaciones Préstamos Castillo y EFS, una referencia a la cláusula décimo sexta ausente y conceptos de penalidad, pagaré, intermediación y pagos externos no desarrollados en el sprint. Su mención no implementa esos módulos ni establece una tasa. El texto original no se modifica automáticamente; las condiciones particulares y el alcance académico se documentan en el anexo.

### Revalidación y representación por empresa

Revalidar identidad desde la ficha consulta automáticamente el DNI fijo, permite reintentar si falla y requiere confirmar la revisión antes de guardar. Al guardar vuelve a la ficha. No se crea una pantalla/plantilla independiente ni se inicia un préstamo.

En RUC 20 se distingue quién firma y la asistencia del propietario. Un propietario ausente conserva su identidad previamente aprobada y vigente, sin una verificación presencial nueva; si falta esa verificación, queda pendiente revisión y no se confirma la solicitud. El firmante debe estar presente y tener identidad y facultades verificadas. La referencia de propiedad y la de facultades documentan las personas y asistencia. No se confunde la vinculación al límite global con responsabilidad personal por deuda de la sociedad.

### Fichas compartidas listados y pagos con contexto

Clientes muestra titulares con préstamos confirmados en la agencia actual, incluidos los ya pagados. El acceso permitido a una ficha vinculada no la incorpora al listado local. DNI y RUC 10 comparten identidad; RUC 20 conserva razón social y ficha independiente. El bloque Personas y empresas vinculadas permite abrir las fichas autorizadas en ambas direcciones. La ficha termina con Consultar para pagar y Ver historial; la cartera local se consulta en Préstamos y las revisiones se muestran en su página propia.

Por DNI, RUC 10 o RUC 20, Pagos reúne las mismas obligaciones del propietario y sus empresas en todas las agencias. Se selecciona y cobra un préstamo a la vez, sin mezclar cuotas. Desde ficha se fija su documento y se vuelve a esa misma ficha; desde detalle se fija el UUID del préstamo autorizado y se vuelve a ese mismo detalle. En ambos casos no aparece Cambiar cliente. La entrada general mantiene búsqueda editable y limpia inmediatamente la atención anterior al cambiarla.

### Control de sesiones y continuidad

La cabecera muestra nombre y rol, agencia, fecha de Perú y contador de sesión. El cierre se produce a los 15 minutos sin interacción o al reemplazar la sesión con un inicio posterior. El aviso del último minuto permite continuar mientras la sesión siga válida. La validación del servidor y de la base protege préstamos y pagos aun si una pantalla permanece abierta; la consulta periódica no renueva la actividad.

Las operaciones confirmadas permanecen al cerrar la sesión; los borradores sin guardar se descartan. Si se interrumpe la respuesta de una confirmación, debe revisarse el préstamo o el historial de pagos antes de iniciar otra operación. Las claves de idempotencia protegen el reintento de la misma operación; no convierten una nueva solicitud independiente en el mismo cobro.

### Alcance de la verificación y funciones pendientes

La consulta de nombres por DNI no consulta automáticamente vigencia ni fallecimiento oficial. La fecha de caducidad y las casillas documentan la revisión presencial del asesor. SUNAT se consulta al ejecutar el flujo correspondiente; no existe un barrido periódico externo que actualice todos los RUC. Un fallo técnico no se registra como rechazo de identidad ni impide cobrar deudas existentes; una nueva solicitud que necesite esa consulta espera un resultado válido.

Se mantienen fuera del incremento los abonos parciales, refinanciación, reversos, gestión judicial, documentos extranjeros y prefijos RUC distintos de 10 y 20, evaluación automática de riesgo por monto/plazo y aprobación documental remota de un propietario no verificado. La vinculación académica para el límite no constituye por sí misma garantía personal de la deuda de una sociedad.
