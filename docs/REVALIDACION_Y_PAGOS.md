# Revalidación, monto y pagos globales

## Cambios

- La ficha de una persona con RUC10 ofrece «Revalidar datos»: identidad por DNI o datos del negocio por RUC10. Sin RUC, sigue abriendo directamente la revalidación de DNI.
- Revalidar RUC consulta automáticamente los datos actuales y permite guardarlos sin crear un préstamo. Guarda asesor, fecha y respuesta firmada en el historial. No revalida DNI, propiedad, facultades ni presencia; no modifica contratos anteriores. Una observación SUNAT se puede guardar sin bloquear pagos.
- Monto solicitado acepta importes mayores que cero con hasta dos decimales. Se muestra el error debajo del campo y no se habilita Ver cronograma con importe inválido o superior al cupo. Válidos: 0.01, 10, 10.5, 10.50. Inválidos: 0, negativos, letras, 1e3 o 0.001.
- La ficha sigue mostrando solo los préstamos de la agencia del asesor.
- Consultar para pagar desde una ficha fija el cliente y el documento. Una persona se consulta por DNI, aunque tenga RUC10, para reunir deuda personal y empresas en las que figura como propietario, en todas las agencias. Ser solo representante no incorpora deudas empresariales a esta consulta. Consultar un RUC20 recupera las operaciones de esa empresa entre agencias.
- Pagos muestra titular/documento, agencia de origen y saldo de cada préstamo. La selección y el cobro siguen siendo individuales: no se mezclan cuotas de préstamos distintos.
- Cambiar cliente elimina resultados, préstamo seleccionado, cuotas elegidas y confirmación de dinero recibido antes de habilitar otra consulta. En búsqueda general, editar documento o tipo produce la misma limpieza; una respuesta antigua que llegue después se descarta.

## Instalar sobre la revisión anterior

1. Detén el servidor y conserva app/.env.local, app/node_modules, app/templates y .git.
2. Elimina app/src y app/.next. Copia app/src, app/scripts y app/tests (conserva sus dependencias); reemplaza docs y los archivos de instrucciones/lectura.
3. Si no aplicaste el ajuste anterior, ejecuta primero app/scripts/habilitar_modalidad_personal.sql en SQL Editor del proyecto Supabase. Si ya lo aplicaste, no es necesario repetirlo.
4. Ejecuta el nuevo app/scripts/revalidacion_y_pagos_globales.sql en ese mismo SQL Editor. Reemplaza la consulta de cobranza y agrega el guardado firmado del RUC con permisos restringidos. No se ha aplicado al proyecto real desde este chat.
5. Desde app ejecuta npm.cmd run dev. No hay dependencias ni variables nuevas; no necesitas npm.cmd ci para esta actualización sobre la misma base.

## Verificación

Se probaron con datos ficticios en PGlite la deuda personal en Trujillo y la empresa del mismo propietario en Chimbote, cartera local sin ampliación, consulta global por DNI/RUC10, exclusión del representante como propietario, cobro cruzado y liberación de capital, firma y permisos de revalidación RUC, idempotencia y ausencia de préstamos nuevos al revalidar. Pasaron las suites anteriores de agencias, borradores y RUC y la compilación y lint.

En navegador se comprobaron las dos rutas de revalidación, el guardado RUC, validación inmediata del monto, consulta fija desde ficha, Cambiar cliente, limpieza por edición, respuesta tardía, cobro entre agencias y visualización en móvil y escritorio.

Prueba adicional con Node 24, desde app: node tests/revalidacion-pagos.test.mjs. Solo utiliza una base aislada; no se conecta al Supabase real.
