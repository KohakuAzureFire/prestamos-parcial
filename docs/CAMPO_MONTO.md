# Campo de monto

## Última revisión: monto con formato fijo

El monto muestra soles y dos cifras de centavos separados por un punto fijo, como `0.00`. Cada parte admite solo dígitos. Al seleccionar una parte se puede reemplazar su valor; el punto, la coma o la flecha derecha permiten pasar de soles a centavos. No admite signos, letras ni importes superiores al capital disponible. `0.00` no habilita Ver cronograma. Al salir del campo, los centavos siempre tienen dos cifras. Se retiraron el aviso superior repetido del monto y el aviso informativo repetido de guardado.

La revisión del campo ya está integrada. Esta actualización solo documental no requiere SQL ni reinstalación. Copia los archivos indicados en `../INSTRUCCIONES_ACTUALIZACION.md` sin eliminar `app/src`.


Ejemplos: 200 soles y 00 centavos → 200.00; 0 soles y 01 centavos → 0.01; 500 soles y 25 centavos → 500.25. El máximo usa el capital disponible real del propietario, no un máximo fijo por agencia. Los controles del servidor permanecen vigentes.

El plazo utiliza un control separado: valor inicial 0, solo dígitos enteros y máximo de 60. Para continuar exige de 1 a 60 meses. La validación del servidor mantiene ambas restricciones aunque se altere la solicitud del navegador.
