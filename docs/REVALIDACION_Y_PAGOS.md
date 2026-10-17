# Revalidación, monto y pagos globales

## Cambios

- La ficha de una persona con RUC10 ofrece «Revalidar datos»: identidad por DNI o datos del negocio por RUC10. Sin RUC, sigue abriendo directamente la revalidación de DNI.
- Revalidar RUC consulta automáticamente los datos actuales y permite guardarlos sin crear un préstamo. Guarda asesor, fecha y respuesta firmada en el historial. No revalida DNI, propiedad, facultades ni presencia; no modifica contratos anteriores. Una observación SUNAT se puede guardar sin bloquear pagos.
- Monto solicitado acepta importes mayores que cero con formato fijo de soles y dos cifras de centavos, solo dígitos y límite según el capital disponible. Se muestra el error debajo del campo y no se habilita Ver cronograma con importe inválido o superior al cupo. Válidos: 0.01, 10, 10.5, 10.50. Inválidos: 0, negativos, letras, 1e3 o 0.001.
- La ficha está resumida: muestra identificación, condición, capital y vínculos. Los préstamos se buscan en Préstamos y los historiales de DNI/RUC se abren en su propia página.
- Consultar para pagar desde una ficha fija el cliente y el documento. Una persona se consulta por DNI, aunque tenga RUC10, para reunir deuda personal y empresas en las que figura como propietario, en todas las agencias. Ser solo representante no incorpora deudas empresariales a esta consulta. Consultar un RUC20 recupera las mismas obligaciones del grupo del propietario y sus empresas entre agencias.
- Pagos muestra titular/documento, agencia de origen y saldo de cada préstamo. La selección y el cobro siguen siendo individuales: no se mezclan cuotas de préstamos distintos.
- Desde ficha no aparece Cambiar cliente: documento y tipo permanecen fijos, con regreso a la misma ficha. Desde detalle quedan fijos el préstamo, código y tipo, con regreso al mismo detalle. En Pagos general, editar documento o tipo limpia resultados, selección de cuotas y confirmación; las respuestas antiguas se descartan.

## Instalar sobre la revisión anterior

La revisión está integrada en el Supabase existente. Para copiar esta entrega documental sigue `../INSTRUCCIONES_ACTUALIZACION.md`, sin SQL ni reinstalación de dependencias. Para reconstruir otra base, consulta el orden de `ESTADO_IMPLEMENTACION.md`; conserva el control de sesiones como último ajuste de autorización.

## Verificación

Se probaron con datos ficticios en PGlite la deuda personal en Trujillo y la empresa del mismo propietario en Chimbote, cartera local sin ampliación, consulta global por DNI/RUC10, exclusión del representante como propietario, cobro cruzado y liberación de capital, firma y permisos de revalidación RUC, idempotencia y ausencia de préstamos nuevos al revalidar. Pasaron las suites anteriores de agencias, borradores y RUC y la compilación y lint.

En navegador se comprobaron las dos rutas de revalidación, el guardado RUC, validación inmediata del monto, consulta fija desde ficha, campos fijos desde detalle, regreso contextual y limpieza en la búsqueda general, respuesta tardía, cobro entre agencias y visualización en móvil y escritorio.

Prueba adicional con Node 24, desde app: node tests/revalidacion-pagos.test.mjs. Solo utiliza una base aislada; no se conecta al Supabase real.

La revisión SUNAT compara lo consultado con lo guardado y conserva una nueva consulta confirmada aunque no cambien los datos. No revisa automáticamente el DNI ni consulta periódicamente todos los RUC. Un error de proveedor no se registra como rechazo de identidad; una nueva solicitud por RUC necesita un resultado válido, pero pagar deudas existentes sigue permitido. Ver `OBSERVACIONES_CLIENTES_REVALIDACION.md`.
