# Revisión de Clientes, Préstamos y documentación de empresas

## Ajuste nuevo: revalidación y pagos globales

**Ejecuta el nuevo `app/scripts/revalidacion_y_pagos_globales.sql` en el SQL Editor de tu Supabase.** Si ya aplicaste `habilitar_modalidad_personal.sql` de la revisión anterior, no necesitas repetirlo. Si aún no lo aplicaste, ejecútalo primero. Ninguno se ha aplicado al proyecto real desde este chat.

Copia `app/src`, `app/scripts`, `app/tests` y las instrucciones conservando tu `.env.local` y `node_modules`, y elimina `app/.next`. No requiere reinstalar dependencias. Consulta `docs/REVALIDACION_Y_PAGOS.md` para el comportamiento y pruebas de esta actualización.


## Actualización: acceso desde ficha y modalidad personal

**Antes de usar esta revisión, aplica `app/scripts/habilitar_modalidad_personal.sql` en el SQL Editor de tu proyecto Supabase.** Está probado en una base aislada y todavía no se ha aplicado al proyecto real. Conserva tus claves y dependencias. Sigue `INSTRUCCIONES_ACTUALIZACION.md` para copiar los archivos y ejecutar este único ajuste.

La ficha bloquea solicitudes sin capital disponible. Las personas con RUC10 eligen préstamo personal (DNI) o negocio (RUC10); la consulta RUC y la recuperación del titular se realizan automáticamente desde ficha. Revalidar identidad revisa el DNI independientemente del RUC. Se retiró «Revisar propietario». La modalidad se conserva en el contrato y cronograma de cada operación nueva.

## Documentos y filtros

- Clientes continúa siendo una sola sección con filtros Todos, Personas y Empresas.
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

1. Detén el servidor con Ctrl+C.
2. Conserva `app/.env.local`, `app/node_modules`, `app/templates` y `.git`.
3. Elimina `app/src` y `app/.next`. Copia el nuevo `app/src` del ZIP y `app/scripts`.
4. Reemplaza `docs` y copia `INSTRUCCIONES_ACTUALIZACION.md`, `LEEME_PRIMERO.md`, `app/README.md` y `app/tests` (conserva el `node_modules` de pruebas si lo tienes).
5. Desde `app`, ejecuta `npm.cmd run dev`.

No cambiaron dependencias ni variables. Para esta revisión aplica el ajuste SQL indicado al inicio. No necesitas `npm.cmd ci` para actualizar esta misma versión base. El ZIP no contiene tus claves. La publicación en Git/Vercel se realiza aparte.

## Comprobación manual

1. Busca una persona por DNI y por su RUC 10: debe abrir la misma ficha, con DNI primero.
2. Cambia Clientes entre Personas y Empresas; comprueba los documentos de las filas.
3. En Préstamos combina tipo de cliente, estado de deuda y documento; Limpiar conserva los filtros.
4. Para una empresa, prueba dos documentos y también un documento compartido. Sin ambas revisiones, no se habilita Continuar.
5. Tras confirmar un préstamo de prueba, vuelve a consultar el mismo RUC: deben recuperarse las referencias con las casillas sin marcar.
6. Cambia de representante: conserva la propiedad y solicita su acreditación. Cambia la presencia del propietario: conserva las referencias, pero vuelve a verificar la identidad conforme a esa modalidad.

Las pruebas automatizadas utilizan datos ficticios y una base local aislada. Confirmar préstamos en tu aplicación conectada a Supabase modifica los datos de ese proyecto.

## Validación realizada

ESLint y compilación de producción de Next.js aprobados. Las suites de agencias, borradores y RUC pasaron en PGlite. En navegador se comprobó RUC10, empresa con propietario ausente y representante, recuperación de referencias sin aprobación automática, cambio de representante, documento compartido, cambio de presencia, filtros y búsquedas, ficha DNI/RUC, anchos 390/1440 y ausencia de errores JavaScript. No se desplegó ni se escribieron datos en Supabase real.
