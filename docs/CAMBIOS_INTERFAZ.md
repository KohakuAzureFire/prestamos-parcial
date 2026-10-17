# Revisión de Clientes, Préstamos y documentación de empresas

## Ajuste nuevo: revalidación y pagos globales

Revalidar datos se despliega en la propia ficha si la persona tiene DNI y RUC 10. DNI abre su revisión automáticamente con el número fijo; RUC abre la consulta SUNAT con comparación de valores y guardado confirmado. Solo DNI o RUC 20 utilizan su acceso directo. Las revisiones vigentes se pueden actualizar y conservan historial. Consulta `REVALIDACION_Y_PAGOS.md` y `OBSERVACIONES_CLIENTES_REVALIDACION.md`.

Pagos por documento reúne al propietario y sus empresas en todas las agencias. Desde ficha mantiene documento y tipo fijos, sin Cambiar cliente, y permite volver a la misma ficha. Desde detalle fija el préstamo autorizado y ofrece regresar a su detalle. La búsqueda general limpia la selección anterior al editar documento o tipo.

## Actualización: acceso desde ficha y modalidad personal

La ficha bloquea solicitudes sin capital disponible o sin elegibilidad. Una persona con RUC 10 elige Personal DNI o Negocio RUC 10 mediante el desplegable Solicitar préstamo; las demás fichas entran directamente a su modalidad. La consulta del RUC recibido desde ficha es automática. No se muestra Revisar propietario en el resumen. La modalidad confirmada se conserva en contrato y cronograma.

La ficha mantiene identificación, condición de pago, capital global y vínculos. Se retiró la tabla Préstamos en tu agencia y se separaron los historiales. Sus acciones finales son Consultar para pagar y Ver historial. El alcance local permanece en las secciones Clientes y Préstamos.

## Documentos y filtros

- Clientes continúa siendo una sola sección con filtros Todos, Personas y Empresas. Solo lista titulares con préstamos confirmados en la agencia, incluidos los ya pagados.
- Personas: la tabla muestra DNI. El RUC 10 sigue asociado a la misma ficha y se puede buscar seleccionando RUC exacto.
- Empresas: la tabla muestra RUC. No se presenta el DNI del propietario como documento de la empresa.
- En la ficha de una persona y el detalle de su préstamo se muestra primero DNI y luego RUC, cuando existe.
- Préstamos conserva Activos, Cancelados y Todos e incorpora tipo de cliente y búsqueda por DNI, RUC o código PR-.

## Acreditación de una empresa

Selecciona el tipo de documento e ingresa una referencia breve (por ejemplo, partida y asiento). Se conserva la revisión separada de propiedad/designación y facultades para contratar el préstamo. Si un documento acredita ambas, marca «El mismo documento acredita las facultades del representante» y confirma cada revisión.

Al consultar una empresa vinculada a tu agencia, se recuperan las referencias anteriores y los DNI vinculados. Las casillas de revisión permanecen desmarcadas: deben confirmarse para la nueva operación. Las referencias no certifican por sí mismas que las facultades sigan vigentes.

Cambiar la presencia del propietario conserva las referencias. Elegir otro representante borra su referencia de facultades; conserva la propiedad. Cambiar el propietario descarta las referencias vinculadas al anterior. La reasignación del propietario de una empresa existente sigue sujeta a las restricciones del servidor.

El propietario ausente debe tener identidad previamente verificada y vigente. No se le registra una verificación presencial nueva. Quien firma debe estar presente. Con varios propietarios se requiere una designación documentada del responsable del límite.

Los registros anteriores de texto continúan siendo legibles. Una referencia antigua de más de 240 caracteres debe resumirse manualmente; no se trunca silenciosamente.

## Instalación en la carpeta actual

La versión de código ya está publicada y los ajustes SQL están aplicados en la instalación existente, incluido el control de sesiones. Esta entrega actualiza documentación: copia los archivos indicados en `../INSTRUCCIONES_ACTUALIZACION.md` sin borrar carpetas. Conserva `.env.local`, `node_modules` y las plantillas; no necesitas SQL ni `npm.cmd ci`. Una reconstrucción desde cero sigue el orden técnico de `ESTADO_IMPLEMENTACION.md`.

## Comprobación manual

1. Busca una persona por DNI y por su RUC 10: debe abrir la misma ficha, con DNI primero.
2. Cambia Clientes entre Personas y Empresas; comprueba los documentos de las filas.
3. En Préstamos combina tipo de cliente, estado de deuda y documento; Limpiar conserva los filtros.
4. Para una empresa, prueba dos documentos y también un documento compartido. Sin ambas revisiones, no se habilita Continuar.
5. Tras confirmar un préstamo de prueba, vuelve a consultar el mismo RUC: deben recuperarse las referencias con las casillas sin marcar.
6. Cambia de representante: conserva la propiedad y solicita su acreditación. Cambia la presencia del propietario: conserva las referencias, pero vuelve a verificar la identidad conforme a esa modalidad.

Las pruebas automatizadas utilizan datos ficticios y una base local aislada. Confirmar préstamos en tu aplicación conectada a Supabase modifica los datos de ese proyecto.

## Validación realizada

ESLint y compilación de producción de Next.js aprobados. Las suites de agencias, borradores y RUC pasaron en PGlite. En navegador se comprobó RUC10, empresa con propietario ausente y representante, recuperación de referencias sin aprobación automática, cambio de representante, documento compartido, cambio de presencia, filtros y búsquedas, ficha DNI/RUC, anchos 390/1440 y ausencia de errores JavaScript. Esas pruebas no escribieron operaciones en Supabase real. La publicación posterior y la activación de sesiones se registran en `ESTADO_IMPLEMENTACION.md`.

## Pasos y cabecera de sesión

Nuevo préstamo conserva Cliente, Condiciones y Cronograma. El paso 1 no tiene Volver; el tipo de cliente permanece fijo en los pasos 2 y 3. Regresar desde cronograma conserva monto y plazo; volver a identificación descarta condiciones cuando se confirma la salida. El monto usa soles y centavos fijos y el plazo solo enteros de 1 a 60, sin negativos. La consulta incrustada no agrega Consultar clientes ni duplica Continuar a condiciones. Los guiones vacíos de domicilio no se muestran como datos útiles.

En el detalle, Cronograma agrupa descarga PDF e impresión y Contrato agrupa Word e impresión. La navegación de regreso en Pagos e historiales usa el enlace con flecha encima del título. Al seleccionar préstamo, su titular queda junto al borde superior del contenido, con margen de 8 px y sin contorno adicional del recuadro; se conserva el foco accesible.

La cabecera mantiene nombre y rol, agencia y fecha; después muestra el contador de 15 minutos. Se vuelve ámbar durante los últimos dos minutos y rojo en el último, con aviso para continuar o cerrar. El vencimiento o un inicio posterior con la misma cuenta cierran la sesión antigua. Ver `CONTROL_SESIONES.md`.
