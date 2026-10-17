# Campo de monto

## Última revisión: monto con formato fijo

El monto muestra soles y dos centavos separados por un punto fijo, como `0.00`. Cada parte admite solo dígitos. Al seleccionar una parte se puede reemplazar su valor; el punto, la coma o la flecha derecha permiten pasar de soles a centavos. No admite signos, letras ni importes superiores al capital disponible. `0.00` no habilita Ver cronograma. Al salir del campo, los centavos siempre tienen dos cifras. Se retiraron el aviso superior repetido del monto y el aviso informativo repetido de guardado.

**Si ya instalaste la revisión anterior, reemplaza `app/src` por el de este ZIP y elimina `app/.next`, conservando `.env.local` y `node_modules`. Ejecuta `npm.cmd run dev`. Esta revisión del formulario no necesita SQL nuevo ni reinstalar dependencias.** Si partes de una versión anterior, conserva los pasos SQL de instalación indicados más abajo.


Ejemplos: 200 soles y 00 centavos → 200.00; 0 soles y 01 centavos → 0.01; 500 soles y 25 centavos → 500.25. El máximo usa el capital disponible real del propietario, no un máximo fijo por agencia. Los controles del servidor permanecen vigentes.
