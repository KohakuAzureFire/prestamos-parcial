# Sprint 1 del sistema de préstamos

El incremento permite verificar al cliente, registrar préstamos con TEA del 30 %, entregar el cronograma y registrar el pago de cuotas en cualquiera de las cinco agencias. La cartera se consulta por agencia y la condición de pago del cliente se obtiene automáticamente de sus obligaciones pendientes.

## Negocio y atención al cliente

El negocio ofrece préstamos de libre disponibilidad en Chimbote, Trujillo, Chiclayo, Piura y Tumbes. La atención es presencial y el sistema es utilizado por los trabajadores. Un préstamo conserva su agencia de origen aunque el cliente pague una cuota en otra agencia.

## Problema que debemos resolver

El sistema sustituye el registro en hojas de cálculo para conservar identidad, cartera por agencia y pagos trazables, evitando cobros duplicados y nuevos préstamos con atraso.

## Usuarios del negocio

| Usuario | Función |
| --- | --- |
| Asesor de ventas | Verifica clientes, registra préstamos y cobra cuotas desde su agencia asignada. |
| Administrador | Rol previsto para una entrega posterior; no tiene pantallas en este sprint. |

## Reglas del negocio

| Aspecto | Regla |
| --- | --- |
| Agencias | Solo Chimbote, Trujillo, Chiclayo, Piura y Tumbes. Cada cuenta tiene una agencia asignada. |
| Préstamo | Cliente, fecha de operación, monto positivo en soles y plazo entero de 1 a 60 meses. Mínimo S/ 0.01 y máximo según el capital disponible. |
| Interés | TEA fija del 30 %. Sistema francés y tasa efectiva mensual equivalente. |
| Vencimientos | Cada 30 días: fecha del préstamo más 30, 60, 90 días y así sucesivamente. No se fija el día del mes. Se conservan las cuotas ya confirmadas. |
| Capital máximo | Hasta S/ 10 000 de capital pendiente por persona entre las cinco agencias. Suma préstamos personales, RUC 10 y RUC 20 vinculados al representante en cada préstamo. Solo la amortización pagada libera cupo; otro representante no recibe deudas anteriores. |
| Elegibilidad | Identidad aprobada y vigente, sin atrasos, historial conciliado y capital disponible; RUC ACTIVO/HABIDO cuando corresponda. El antecedente extrajudicial exige autorización. |
| Cobranza | Se pueden pagar cuotas de un préstamo en otra agencia. Se atienden primero las cuotas pendientes más antiguas del préstamo seleccionado. |

## Funciones de la entrega

Se atiende a personas con DNI, negocios RUC 10 y empresas RUC 20. DNI y RUC 10 comparten ficha. La empresa tiene ficha propia y cada préstamo RUC 20 conserva al representante que lo solicitó. Clientes incluye titulares y representantes con préstamos confirmados en la agencia; Préstamos conserva solo operaciones originadas allí. Identidad y límite se comparten entre las cinco agencias, sin ampliar la cartera local por un cobro ajeno.

| Área | En esta entrega | Para después |
| --- | --- | --- |
| Acceso | Iniciar y cerrar sesión, controlar 15 minutos de inactividad y mantener una sesión por cuenta, sin credenciales de demostración visibles. | Administrar cuentas y recuperar contraseñas. |
| Clientes | Consultar ficha e historial de verificación; registrar o revalidar desde el flujo del préstamo. | Otros documentos de identidad y evaluación del alcance de poderes. |
| Préstamos | Registrar, controlar el capital pendiente y consultar cartera propia. | Editar, anular o refinanciar préstamos confirmados. |
| Cronograma | Cuotas cada 30 días, desglose de interés y capital, guardado y PDF. | Reprogramaciones y amortización extraordinaria. |
| Pagos | Registrar cuotas completas, incluso de otra agencia, y emitir constancia. | Abonos parciales, devoluciones y pasarelas de pago. |
| Estados | Actualizar deuda y condición de pago automáticamente. | Reportes gerenciales y gestión jurídica de cobranza. |

No incluye abonos parciales, reversos, refinanciación, gestión judicial, panel gerencial, evaluación automática de riesgo ni documentos extranjeros. El vínculo con el representante para el límite es una regla académica; no constituye por sí solo garantía personal de una deuda empresarial. La consulta API identifica representantes informados, sin certificar el alcance de sus poderes.

## Decisiones que precisan el alcance

Se adoptan las siguientes precisiones para la consulta por agencia, el pago entre agencias y los estados automáticos del caso académico.

| Decisión | Criterio operativo propuesto |
| --- | --- |
| Inicio del atraso | Desde el día siguiente al vencimiento de una cuota que conserve saldo impago; no se espera al fin del mes. |
| Un año de atraso | Doce meses calendario desde el vencimiento de la cuota impaga más antigua. El día inexistente se ajusta al último del mes. |
| Cobro mínimo | Registro interno por el asesor de una o varias cuotas completas consecutivas del préstamo seleccionado; no integra un banco ni una pasarela. |
| Orden del pago | Primero la cuota pendiente más antigua del préstamo elegido. La condición del cliente considera todos sus préstamos en las cinco agencias. |
| Cálculo mensual | Tasa constante por período de 30 días equivalente a la TEA con base 360. La fecha se obtiene sumando 30 días por cuota; el atraso no genera cargos adicionales. |

## Condiciones para operar

Las cuentas y las cinco agencias están preconfiguradas; General y Ana Morales permanecen fuera de operación, sin borrar datos históricos.

Los préstamos anteriores requieren capital, cronograma y pagos conciliados. La falta de un pago histórico no demuestra por sí sola que exista atraso. Un cliente con historial incompleto queda identificado como pendiente de conciliación y no obtiene nuevos préstamos hasta regularizar los datos.

## Pantallas y recorrido de atención

| Pantalla | Contenido y acciones |
| --- | --- |
| Inicio de sesión | Correo y contraseña. Agencia asignada por cuenta, sin credenciales de demostración; contador y sesión única. |
| Préstamos | Cartera local; estado, tipo de titular y búsqueda exacta por DNI/RUC/PR-. Documento, cliente o razón social, fecha, monto, plazo, estado y detalle. |
| Clientes | Titulares con préstamos confirmados locales, incluidos pagados. Filtros Todos/Personas/Negocios y empresas. DNI/RUC 10 aparece con DNI en Personas y con RUC en Negocios y empresas; Todos reúne ambos en una fila. |
| Ficha del cliente | Identificación, condición, capital global y vínculos. Solicitar préstamo, Revalidar datos, Consultar para pagar y Ver historial. Historial en página aparte, sin tabla de préstamos. |
| Nuevo préstamo | Cliente → Condiciones → Cronograma. RUC 20 verifica empresa y DNI del representante por API, sin documentación ni evaluación posterior. Tipo fijo después del paso 1; Atrás conserva el borrador. Sin Ir a clientes dentro del formulario. |
| Detalle del préstamo | Total a pagar, pagado y saldo; tasas, estado, cuotas e historial. Menús Cronograma y Contrato. Registrar pago carga ese préstamo fijo. |
| Pagos | Consulta dirigida al grupo entre agencias por DNI/RUC o a un préstamo por PR-. Desde ficha fija documento; desde detalle fija préstamo. Regreso al origen y cobro individual. |

El menú del asesor contiene Préstamos, Clientes, Nuevo préstamo, Pagos y Cerrar sesión. Los accesos desde ficha o detalle llevan a esos mismos procesos. Solicitudes documentales queda fuera del flujo vigente.

## Recorrido del cliente nuevo y del cliente existente

Nuevo préstamo usa Cliente → Condiciones → Cronograma para DNI, RUC 10 y RUC 20. Para RUC 20, consulta la empresa y comprueba el DNI del representante mediante API Perú; no pide propietario, certificados ni archivos. Atrás conserva el borrador en memoria. Solo Confirmar préstamo registra las altas y el préstamo; abandonar descarta lo no confirmado.

La empresa debe estar ACTIVA y HABIDA. El DNI completo del firmante debe coincidir exactamente con uno de los representantes devueltos para ese RUC. Se comprueba identidad vigente y presencia, elegibilidad y capital global antes de confirmar. Una API caída, sin coincidencias o con documentos ocultos impide continuar; no se completa una identidad por deducción. Cada préstamo fija su representante y copia contractual. Elegir otra persona en un préstamo posterior no le traslada deudas anteriores. El cronograma nace al confirmar y vence cada 30 días.

Desde Clientes se abre la ficha y Solicitar préstamo. Un cliente de otra agencia se recupera en Nuevo préstamo. La revalidación guardada actualiza la ficha compartida sin generar crédito ni eliminar atrasos.

Cobranza: Pagos → consultar DNI/RUC/PR- → elegir préstamo → revisar cuotas y origen → confirmar dinero recibido y cobro → constancia. Desde ficha o detalle consulta automáticamente y conserva el contexto.

## Validación del representante de la empresa

El asesor ingresa el DNI del representante que solicita y firma. La consulta expresa a API Perú puede devolver varias personas. El sistema compara el DNI completo con la lista del RUC consultado y luego verifica la identidad de quien firma. No se solicitan referencias de propiedad ni documentos adjuntos.

| Campo | Entrada admitida | Validación |
| --- | --- | --- |
| RUC de empresa | Once dígitos con prefijo 20. | Dígito verificador; ACTIVO y HABIDO. |
| DNI del representante | Ocho dígitos; conserva ceros iniciales. | Coincidencia completa en la lista del RUC. |
| Representantes API | Puede incluir varias personas. | Sin coincidencia o con datos ocultos, bloquea. |
| Consulta firmada | Asesor, RUC, fecha y respuesta del proveedor. | Firma válida y antigüedad hasta 30 minutos. |
| Identidad presencial | DNI original, caducidad y presencia. | Identidad vigente al confirmar. |
| Capital global | Préstamos personales y por empresas. | Hasta S/ 10 000 por representante. |

El DNI admite exactamente ocho dígitos y conserva ceros iniciales. El RUC admite once dígitos, prefijo 10 o 20 y dígito verificador. Una consulta firmada pertenece al asesor y RUC consultados y vence a los 30 minutos. El servidor repite estas comprobaciones al confirmar, sin confiar en la selección del navegador.

Cambiar el DNI descarta la identidad seleccionada y exige comprobar de nuevo el vínculo. Renovar consulta descarta la validación anterior. Una persona ya verificada puede reutilizar su ficha, pero el asesor confirma DNI original y presencia durante esta atención. Sin identidad vigente o capital disponible no se confirma el préstamo.

## Estados y datos que deben conservarse

| Concepto | Estados y regla |
| --- | --- |
| Verificación de identidad | Pendiente, Aprobada, Caducada o Rechazada. Aprobada exige identidad confiable, documento vigente y evidencia suficiente de las condiciones exigidas. |
| Condición de pago del cliente | Sin atrasos (valor interno habilitado) si no tiene cuotas vencidas impagas; Con atrasos si tiene atraso menor de 12 meses; Extrajudicial si al menos una cuota impaga cumple 12 meses de atraso. Son estados automáticos del grupo, con prioridad de Extrajudicial sobre Con atrasos; un historial incompleto se identifica como Pendiente de conciliación. |
| Validación RUC 20 | Consulta en memoria hasta confirmar. Exige DNI completo coincidente e identidad presencial vigente. No genera solicitud pendiente; las solicitudes documentales anteriores quedan como historial. |
| Préstamo | Activo mientras quede deuda contractual pendiente; Cancelado por pago total cuando todas sus cuotas estén pagadas. Cancelado no significa anulado. |
| Cuota | Pendiente antes de vencer o durante su fecha de vencimiento; Vencida desde el día siguiente si no está pagada; Pagada únicamente si existe un cobro confirmado que la cubra. |

Identidad y condición de pago son independientes: el atraso o el DNI caducado bloquean nuevos préstamos, pero no cobros. Pagar no borra verificaciones.

El fallecimiento acreditado bloquea nuevas colocaciones y no se modifica con un selector financiero. Revisar el DNI físico no acredita una consulta oficial de fallecimiento.

## Datos y trazabilidad mínimos

| Registro | Información que conserva |
| --- | --- |
| Cliente y verificación | DNI único de la persona y RUC propio de la empresa. La ficha personal se comparte con RUC 10; cada préstamo RUC 20 fija su representante. Conserva nombres exactos, agencia inicial, caducidad, resultado, evidencia, fuente, fecha, asesor y agencia de cada revisión. Renovar agrega una revisión y conserva las anteriores para todas las agencias. |
| Préstamo y cronograma | Identificador único, cliente, agencia de origen, asesor, fecha, monto, plazo, TEA, tasa mensual y cuotas originales con interés, amortización y saldo programado. |
| Pago y aplicación | Identificador único, préstamo, cuotas cubiertas, importe, fecha y hora, asesor y agencia de cobro. La aplicación distingue capital e interés según el cronograma guardado. |
| Situación vigente | Total pagado, deuda contractual pendiente, capital pendiente, cuotas vencidas, antigüedad del atraso y fecha de actualización. Se derivan de datos conciliados y pagos confirmados. |

La fecha de operación y el corte diario se interpretan en la zona horaria de Perú. Los estados se actualizan al cambiar el día y después de un pago; también se verifican al consultar y antes de autorizar un nuevo préstamo, aunque nadie haya abierto el sistema durante varios días.

## Criterios de cálculo del cronograma

| Parámetro | Criterio adoptado |
| --- | --- |
| TEA | 30 % efectiva anual, fija y no editable. |
| Tasa mensual | TEM = (1 + 0,30)^(1/12) − 1 = 2,210445 % aproximadamente. Equivale a (1 + 0,30)^(30/360) − 1 bajo la base convencional de 360 días adoptada. |
| Amortización | Sistema francés con cuota mensual constante. Interés del mes = capital anterior × TEM; amortización = cuota − interés. La última cuota ajusta los redondeos. |
| Vencimientos | Intervalos de 30 días desde la fecha de operación: fecha original más 30 por el número de cuota. Los cronogramas confirmados antes de este cambio permanecen intactos. |
| Bisiestos | Un préstamo del 31/01/2028 vence el 01/03/2028, 31/03/2028 y 30/04/2028. Uno del 22/10/2026 vence el 21/11/2026, 21/12/2026 y 20/01/2027. |
| Convención | La tasa por período usa 30/360 y los nuevos vencimientos se separan por 30 días. No se ajustan fines de semana. El umbral extrajudicial conserva los doce meses calendario. |
| Redondeo y cargos | De 1 a 60 cuotas, dos decimales y saldo final cero. Sin comisiones, seguros, penalidades ni recargos por atraso. |
| Importes informativos | Interés total programado = suma de intereses; total programado = suma de cuotas; deuda pendiente = total programado menos cobros confirmados. El capital pendiente excluye intereses futuros. |
| Atrasos sin recargos | El atraso no incrementa el importe de las cuotas. Se conservan vencimientos, días de atraso, condición de pago y bloqueo de nuevos préstamos. |

La confirmación del cobro comprueba las cuotas y el importe consultado. Si cambiaron durante la revisión, exige actualizar antes de cobrar.

## Planificación del sprint

Sprint N.º 1: Acceso, préstamos y pago básico de cuotas.

Objetivo del sprint: atender al cliente desde su verificación hasta el préstamo y el cobro de cuotas, con consulta por agencia, control de capital global y actualización automática de la condición de pago.

Resultado de la entrega: préstamos y cronogramas recuperables, pagos trazables entre agencias y bloqueo de nuevas colocaciones cuando existe atraso, documento vencido o verificación insuficiente.

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

Días 1 y 2: ajustar acceso, permisos por agencia, identidad y datos. Días 3 y 4: integrar cronograma, pagos y estados automáticos. Día 5: probar el flujo completo, desplegar y preparar la demostración.

## Épica Gestionar acceso

Permitir el acceso exclusivo de asesores autorizados con una de las cinco agencias asignadas. La creación de cuentas y recuperación de contraseñas quedan fuera del sprint.

### HU-01 Iniciar sesión

Como asesor de ventas, quiero iniciar sesión con mi cuenta autorizada, para operar desde la agencia que tengo asignada.

#### Criterios de aceptación

- **CA01. Credenciales obligatorias:** Solicita correo y contraseña; los campos vacíos impiden continuar.

- **CA02. Acceso autorizado:** Solo ingresa una cuenta válida y activa. El rechazo de credenciales no identifica cuál falló.

- **CA03. Agencia de sesión:** Obtiene asesor y agencia de la cuenta; no permite elegir otra agencia ni usar General.

- **CA04. Protección efectiva:** Pantallas y operaciones requieren sesión y permisos, incluso por URL directa o solicitudes alteradas.

- **CA05. Login limpio:** No muestra accesos rápidos ni contraseñas de demostración.

- **CA06. Resultado:** Abre Préstamos con cartera propia. La cabecera muestra nombre y rol, agencia, fecha de Perú y contador, en ese orden.

- **CA07. Sesión única:** Otro inicio válido de la misma cuenta reemplaza al anterior. La base lo bloquea y la interfaz lo detecta en hasta 15 segundos con conexión; las pestañas comparten sesión.

- **CA08. Inactividad:** Cierra tras 15 minutos sin interacción. Teclado, puntero y desplazamiento renuevan actividad con envíos limitados; el sondeo no renueva. Usa tiempo del servidor y no reactiva sesiones vencidas.

### HU-02 Cerrar sesión

Como asesor de ventas, quiero cerrar mi sesión, para impedir que otra persona opere con mi cuenta.

#### Criterios de aceptación

- **CA01. Opción disponible:** Cerrar sesión permanece visible durante una sesión activa.

- **CA02. Finalización:** Invalida la sesión actual y vuelve al acceso. Las rutas protegidas exigen nuevo ingreso; cerrar una sesión antigua no revoca una posterior de otra computadora.

- **CA03. Borradores:** Advierte antes de abandonar manualmente datos sin confirmar. El cierre obligatorio pierde borradores; las verificaciones guardadas y operaciones confirmadas permanecen.

- **CA04. Aviso de vencimiento:** Contador ámbar en los últimos dos minutos y rojo en el último. El aviso ofrece Continuar sesión o Cerrar sesión; continuar exige sesión aún válida.

- **CA05. Cierre obligatorio:** Inactividad, sesión reemplazada o cuenta sin acceso bloquean operaciones y devuelven al inicio con el motivo.

## Épica Gestionar préstamos y cobranza

Las HU-03 a HU-08 comparten identidad, préstamos, cronogramas y pagos. La condición financiera se deriva de las obligaciones del cliente y no se cambia manualmente. Los datos contractuales confirmados permanecen sin edición; los pagos se registran como nuevas operaciones.

### HU-03 Validar y registrar cliente

Como asesor de ventas, quiero verificar la identidad y vigencia del DNI, para registrar un cliente confiable o revalidar su ficha antes de un nuevo préstamo.

#### Criterios de aceptación

- **CA01. Documento admitido:** DNI peruano de ocho dígitos; RUC de once, prefijo 10 o 20 y dígito verificador. Conserva ceros iniciales y valida en pantalla y servidor. Extranjería y otros prefijos quedan fuera.

- **CA02. Entrada y borrador:** Reutiliza la ficha vigente entre agencias sin duplicar consultas de DNI. Personas y empresa permanecen en memoria hasta confirmar el préstamo. Cambiar DNI repite vínculo e identidad; no edita nombres. Abandonar descarta el borrador.

- **CA03. Identidad exacta:** Consulta identidad para nuevos o revalidaciones. Nombres y apellidos originales no se editan; cambiar documento exige repetir su comprobación.

- **CA04. Vigencia acreditada:** Registra caducidad y confirma DNI original y presencia con dos casillas. Genera referencias descriptivas; esta revisión no acredita una consulta oficial de fallecimiento.

- **CA05. Estados separados:** Verificación Pendiente, Aprobada, Caducada o Rechazada, separada de la condición de pago. Fallecido no es una condición financiera editable.

- **CA06. Caducidad automática:** El DNI es vigente hasta su caducidad inclusive. Desde el día siguiente bloquea nuevos préstamos; revalidar exige revisar el documento renovado.

- **CA07. Fallo o rechazo:** Documento inexistente o consulta inconclusa impiden verificar. Un fallo técnico no se guarda como rechazo; permite reintentar y no bloquea pagar deudas existentes. El aviso de Pagos exige deuda pendiente del RUC consultado.

- **CA08. Revalidación independiente:** Desde ficha consulta automáticamente el documento fijo y regresa al guardar. Conserva evidencia, fecha, asesor, agencia e historial compartido; permite actualizar datos vigentes y no elimina atrasos.

- **CA09. SUNAT y alcance:** SUNAT compara razón social, estado, condición y domicilio. Permite guardar consulta firmada sin cambios o con observaciones. No edita datos externos ni revalida DNI, propiedad o facultades; no hay actualización periódica.

- **CA10. Representación:** RUC 20 consulta API Perú y exige DNI completo coincidente con un representante de ese RUC. Admite varias personas y elige quien solicita y firma. Documentos ocultos, respuesta vacía o fallo impiden continuar. No pide propietario ni certificados; conserva verificación de identidad y presencia.

- **CA11. Consulta firmada:** El flujo vigente no exige referencias documentales ni cargas. La consulta de representantes se firma con asesor y RUC y vence a los 30 minutos. El servidor valida firma, RUC y DNI al confirmar; no acepta un vínculo declarado solo por el navegador.

- **CA12. Corrección visible:** El DNI admite ocho dígitos y conserva ceros iniciales. Cambiarlo limpia la persona y exige validar el nuevo vínculo. Renovar consulta descarta la validación previa; Atrás conserva el borrador y las condiciones.


### HU-04 Registrar préstamo

Como asesor de ventas, quiero registrar el monto y plazo de un cliente elegible, para formalizar su préstamo sin superar el capital permitido.

#### Criterios de aceptación

- **CA01. Cliente previo:** Reutiliza cliente y documento desde HU-03 o ficha, sin volver a escribir identidad ni abrir otro buscador.

- **CA02. Elegibilidad automática:** Exige identidad vigente, sin atrasos, historial conciliado, capital y autorización cuando corresponda. DNI personal no exige estado SUNAT del RUC 10 asociado. Por RUC exige ACTIVO/HABIDO. RUC 20 añade coincidencia del DNI en la API y presencia del representante; confirma inmediatamente al superar los controles.

- **CA03. Datos de sesión:** Fecha de Perú, agencia y asesor provienen de la sesión y no son editables.

- **CA04. Monto:** Inicial 0.00, punto fijo y solo dígitos en soles y dos cifras de centavos. Mínimo S/ 0.01 y máximo disponible, hasta S/ 10 000; cero, signos, letras o precisión adicional impiden continuar.

- **CA05. Capital global:** Suma préstamos personales, RUC 10 y préstamos RUC 20 de la misma persona en las cinco agencias, hasta S/ 10 000. Cada préstamo RUC 20 fija su representante; cambiarlo en otro préstamo no traslada deuda. Solo amortización pagada libera cupo.

- **CA06. Concurrencia:** Repite elegibilidad y cupo al confirmar de forma transaccional para impedir exceder el capital con solicitudes simultáneas.

- **CA07. Plazo y tasa:** Plazo inicial 0; solo enteros de 1 a 60 para continuar. TEA fija del 30 %, no porcentaje plano para cualquier duración.

- **CA08. Confirmación conjunta:** Revisar cronograma no guarda. Confirmar crea personas, empresa, préstamo, copia contractual y cuotas en una transacción, o revierte todo. No crea solicitud pendiente ni pide PDF. Firma de consulta mayor de 30 minutos exige renovarla; reintentar no duplica operaciones.

- **CA09. Resultado protegido:** El préstamo pertenece a la agencia de sesión y añade allí al titular sin duplicar ficha ni trasladar préstamos. No permite editar ni anular lo confirmado.

- **CA10. Pasos y regreso:** Cliente → Condiciones → Cronograma, también para RUC 20. Tipo modificable solo en identificación. Sin Documentación, Ver solicitudes, Actualizar revisión ni Ir a clientes. Atrás conserva el borrador; salir por enlaces protegidos advierte de datos pendientes. Cambiar DNI exige validar de nuevo.

### HU-05 Generar y entregar cronograma

Como asesor de ventas, quiero generar y entregar el cronograma, para que el cliente conozca sus cuotas mensuales, intereses y vencimientos.

#### Criterios de aceptación

- **CA01. Entradas:** Usa monto, fecha, plazo y TEA del préstamo; genera una cuota por mes.

- **CA02. Cálculo:** TEM = (1 + 0,30)^(1/12) − 1, aproximadamente 2,210445 %. Sistema francés: interés sobre saldo y amortización como cuota menos interés.

- **CA03. Fechas cada 30 días:** Suma 30 días por cuota a la fecha del préstamo. Considera cambios de mes, año y bisiestos, sin ajuste por fines de semana. Conserva las fechas de cuotas ya confirmadas.

- **CA04. Detalle:** Muestra número, vencimiento, cuota, interés, amortización y saldo; identifica titular, código, agencia, monto, plazo, TEA, TEM y totales.

- **CA05. Redondeo y cargos:** Dos decimales y última cuota ajustada a saldo cero. Sin comisiones, seguros, penalidades ni recargos por atraso.

- **CA06. Consistencia:** Guarda el cronograma confirmado sin recalcularlo al consultar o pagar. RUC 20 conserva empresa, RUC, representante y DNI originales en el préstamo; otra persona posterior no cambia el contrato ni la deuda anterior. Solo emite contrato para un préstamo confirmado y bloquea si falta la copia completa del firmante.

- **CA07. Descarga e impresión:** Cronograma agrupa PDF e impresión. Contrato agrupa Word e impresión/guardar PDF, con plantilla adaptada del profesor que termina en las firmas, con nombre, DNI y calidad del firmante, sin anexo de condiciones. Descargar de nuevo no crea préstamo.

- **CA08. Caso financiero:** Para S/ 1 000 a seis meses: primeras cinco cuotas S/ 179,80 y última S/ 179,77; capital S/ 1 000, interés S/ 78,77 y total S/ 1 078,77.

- **CA09. Caso de calendario:** Desde 22/10/2026 vence el 21/11/2026, 21/12/2026 y 20/01/2027. Desde 31/01/2028 usa 01/03/2028 y 31/03/2028; la tasa por período se mantiene.

### HU-06 Consultar clientes y cartera propia

Como asesor de ventas, quiero consultar clientes y la cartera de mi agencia, para conocer su situación y recuperar los cronogramas autorizados.

#### Criterios de aceptación

- **CA01. Cartera propia:** Solo operaciones originadas en la agencia, de más recientes a antiguas; también se restringe detalle y servidor.

- **CA02. Listado y filtros:** Activos por defecto; filtros Activos/Cancelados/Todos y Personas/Empresas/Todos. Busca DNI, RUC o PR-. Documento muestra DNI personal o RUC empresarial, con monto, plazo, fecha, estado y detalle.

- **CA03. Clientes de la agencia:** Titulares y representantes de préstamos confirmados locales, incluidos pagados. DNI/RUC 10 figura en Personas con DNI y en Negocios y empresas con RUC; Todos conserva una fila. Identidad y cobros ajenos no incorporan personas a la cartera.

- **CA04. Ficha y privacidad de cartera:** DNI/RUC 10 comparten ficha; RUC 20 conserva su empresa y muestra el representante actual. Repetir el RUC permite otro préstamo con representante validado por API, sin alterar contratos ni responsables anteriores. El detalle mantiene privacidad por agencia.

- **CA05. Continuar atención:** Solicitar préstamo ofrece DNI/RUC 10 si existen ambos y exige elegibilidad y cupo. Para RUC 20 abre la validación del representante antes de determinar su capital. Revalidar datos ofrece DNI/RUC 10 o SUNAT para RUC 20. Incluye Consultar para pagar y Ver historial.

- **CA06. Resumen del detalle:** Detalle muestra Total a pagar, Total pagado y Saldo por pagar, con estado, TEA, TEM e interés total; diseño adaptable a móvil.

- **CA07. Cuotas y acceso al cobro:** Registrar pago carga el préstamo y cuotas automáticamente con código/tipo fijos y regreso al mismo detalle. Desplaza al titular; no confirma el cobro.

- **CA08. Cobro entre agencias:** Pagos localiza deudas entre agencias por DNI, RUC o código. No incorpora préstamos ajenos a la cartera ni habilita sus detalles ordinarios.

- **CA09. Documento y resultados vacíos:** Recupera documentos sin alterar el préstamo. Una búsqueda vacía informa que no hay coincidencias, sin mostrar registros ajenos.

- **CA10. Formato de búsqueda:** DNI de ocho dígitos y RUC válido de once. PR- fijo más ocho hexadecimales en mayúsculas; pegar código completo no duplica prefijo. Entrada inválida impide consultar.

- **CA11. Confirmación directa:** Nuevo préstamo RUC 20 confirma directamente. El menú retira Solicitudes de préstamo y la base bloquea nuevos envíos y evaluaciones documentales. Conserva solicitudes previas y sus documentos como historial; no modifica préstamos anteriores.


### HU-07 Registrar pago de cuotas

Como asesor de ventas, quiero registrar el pago de cuotas de un préstamo, incluso de otra agencia, para actualizar la deuda y entregar constancia del cobro.

#### Criterios de aceptación

- **CA01. Localización:** DNI o RUC 10 reúne préstamos personales y los RUC 20 vinculados a esa persona al confirmar. RUC 20 reúne préstamos de esa empresa, incluso con distintos representantes. PR- identifica un préstamo. Permite cobrar entre agencias sin cambiar el responsable; desde ficha o detalle conserva contexto y regreso.

- **CA02. Datos de revisión:** Muestra titular, código, agencia de origen, deuda y cuotas. No exige DNI vigente, RUC habilitado ni ausencia de atrasos para pagar.

- **CA03. Selección:** Cuotas completas consecutivas desde la pendiente más antigua del préstamo. Admite la próxima cuota sin recalcular; excluye abonos parciales y pagos extraordinarios a capital.

- **CA04. Importe y confirmación:** Suma el capital y el interés original de las cuotas seleccionadas, sin recargos por atraso; el importe no es editable. Exige confirmar dinero recibido y aceptar el cobro; no integra un banco.

- **CA05. Trazabilidad:** Guarda identificador, fecha/hora, asesor, agencia de cobro, préstamo y aplicación por cuota. Conserva origen y emite constancia recuperable desde origen o agencia de cobro.

- **CA06. Registro consistente:** La clave evita duplicar el mismo reintento y se rechazan cuotas ya cobradas. Un fallo no deja aplicaciones incompletas. Si se pierde la respuesta, revisar historial antes de iniciar otro cobro.

- **CA07. Efectos:** Marca cuotas pagadas, reduce deuda y capital por su amortización y recalcula condición. Pago total cancela el préstamo.

- **CA08. Conservación:** No modifica el cronograma ni desmarca pagos confirmados. Reversos y devoluciones quedan fuera; la constancia no es comprobante tributario.

- **CA09. Validación de búsqueda:** Valida documento o PR- antes de consultar, según HU-06 CA10. Un error no muestra otras identidades.

- **CA10. Relación con la agencia:** Cobrar en otra agencia registra quién recibió el dinero, sin cambiar origen ni incorporar al cliente a su listado.

- **CA11. Cambio de consulta:** Solo la búsqueda general permite editar documento/tipo. Cualquier cambio limpia resultados, cuotas y confirmación y descarta respuestas antiguas; los flujos fijos conservan su origen.

- **CA12. Desplazamiento y revisión:** Elegir préstamo o cargar resultado único enfoca y desplaza al titular. Una lista múltiple o cambiar cuotas no repiten el movimiento; respeta reducir animaciones y foco accesible.

### HU-08 Actualizar estados automáticamente

Como asesor de ventas, quiero que el sistema determine la deuda y condición del cliente, para impedir nuevos préstamos cuando tenga cuotas atrasadas sin cambiar estados manualmente.

#### Criterios de aceptación

- **CA01. Fecha de referencia:** Fecha de Perú: una cuota impaga de hoy vence al día siguiente.

- **CA02. Condición global:** Considera persona y empresas entre agencias. Extrajudicial desde doce meses de la cuota impaga más antigua; Con atrasos con menor atraso; Sin atrasos sin vencidas. Historial incompleto queda Pendiente de conciliación.

- **CA03. Alcance de la etiqueta:** Extrajudicial es clasificación académica, sin iniciar trámite jurídico ni permitir selección manual de la condición.

- **CA04. Actualización efectiva:** Recalcula después de pagar, al cambiar el día y al consultar o confirmar, aunque el corte diario no se haya ejecutado.

- **CA05. Regularización:** Cubrir lo vencido regulariza sin anticipar cuotas futuras. El antecedente permanece: nuevo crédito requiere asesor autorizado, motivo, ausencia de vencidas e historial conciliado, sin omitir identidad, RUC o cupo.

- **CA06. Independencia de identidad:** Pagar o regularizar no borra verificaciones. Un DNI caducado sigue bloqueando nuevas colocaciones hasta revalidar.

- **CA07. Capital y cierre:** Disponible = límite menos capital pendiente global. Los intereses no liberan cupo; terminar el plazo no cancela deuda.

- **CA08. Caso de umbral:** Cuota del 15/10/2026: pendiente ese día, vencida el 16/10/2026 y extrajudicial el 15/10/2027 si sigue impaga.

- **CA09. Datos incompletos:** Un historial no conciliado no se declara ficticiamente pagado o con atrasos y bloquea nuevos préstamos hasta completarse.

## Criterios de finalización del incremento

La entrega debe demostrar las ocho HU integradas, permisos por agencia, cálculo financiero, cobro sin duplicados y estados automáticos. Se conservan operaciones confirmadas e historial. Las pruebas y el despliegue se verifican sobre la misma versión; las funciones fuera del alcance no se presentan como implementadas.

## Casos de verificación de la entrega

| Caso | Resultado esperado |
| --- | --- |
| Acceso y sesiones | Cuenta activa, contador de 15 minutos y renovación válida. Otro navegador reemplaza la sesión; cerrar la anterior no revoca la nueva. |
| Identidad y representación | RUC 20: DNI de un representante devuelto por API, identidad y presencia verificadas. Prueba varios representantes, DNI con ceros y datos ocultos; no pide propietario, referencia ni certificado. |
| Cliente nuevo y borradores | Antes de confirmar no guarda personas ni empresa. Un fallo de API o DNI sin coincidencia impide continuar. Confirmar crea una sola operación; fallo transaccional revierte todo. Atrás conserva el borrador. |
| Agencias y fichas | Cartera local sin incorporar titulares por cobro ajeno. DNI/RUC 10 en ambos filtros, una fila en Todos. Empresa y representante visibles por préstamos locales; deuda fijada por préstamo. |
| RUC y elegibilidad | RUC observado bloquea ese RUC, sin impedir DNI elegible ni pagos. Aviso de Pagos solo con deuda del RUC exacto. Fallo técnico no es rechazo; revalidar conserva historial y atrasos. |
| Monto plazo y capital | Solo dígitos, S/ 0.01 hasta el disponible global de S/ 10 000 y de 1 a 60 meses. Pagar libera únicamente el capital amortizado. |
| Cronograma y documentos | Comprueba el ejemplo de S/ 1 000, redondeos, meses de 28 a 31 días y bisiestos. Descargas e impresión conservan las condiciones e identidad del préstamo. |
| Cobro entre agencias | DNI/RUC 10 reúne préstamos de la persona y empresas donde es responsable. RUC 20 muestra solo esa empresa. Cobra cuotas consecutivas, conserva origen y libera cupo del representante original. |
| Contexto y navegación | Desde ficha o detalle los campos quedan fijos y el regreso conserva el origen. Búsqueda general limpia resultados al cambiar documento/tipo; seleccionar préstamo desplaza al titular una vez. |
| Concurrencia y reintentos | No excede capital ni duplica préstamos o cobros. Confirma con firma vigente y controles repetidos. Préstamos de varias empresas suman al mismo representante; cambiarlo no traslada deuda. |
| Atrasos y regularización | Prueba vencimiento, día siguiente y doce meses. Regularizar no anticipa cuotas futuras; conserva antecedente y exige autorización especial para nuevo crédito. |
| Conciliación y cierre | Un historial incompleto bloquea nuevas colocaciones; cancelar exige pago total. Pagar no elimina identidad ni su caducidad, y quedan historial y constancias. |
| Entradas y restricciones | Validar RUC y DNI, conservar ceros iniciales y rechazar caracteres o longitudes inválidas. Cambiar DNI exige nueva coincidencia. Una máscara o un fallo de API impide continuar; las consultas caducadas se renuevan. |
| Interfaz y conservación del flujo | Sin Ir a clientes ni documentación en Nuevo préstamo. Atrás conserva personas y condiciones; cambiar DNI reinicia la validación del vínculo. Revisar escritorio y móvil, foco y separación de botones. |
