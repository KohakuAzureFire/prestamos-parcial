# Regresos y desplazamiento en Pagos e historiales

Esta corrección modifica tres archivos de código y no cambia la base de datos.

Pagos usa el estilo breadcrumb ya existente: enlace con flecha, encima del título,
sin botón con recuadro. Conserva el regreso a la ficha personal o empresa de origen,
o al detalle del préstamo según el recorrido. Pagos general no agrega un regreso.
Los historiales de DNI/RUC usan el mismo estilo y regresan a su misma ficha.

El recuadro del titular del préstamo seleccionado usa scroll-margin-top de 8 px,
en lugar de 100/85 px. La cabecera superior no es fija; no hace falta reservar su
altura al desplazarse. La selección espera el fin de la animación de entrada antes
de medir y desplazar, para mantener la posición correcta al llegar desde un detalle.
Se retira únicamente el contorno del recuadro no interactivo enfocado automáticamente.
Se mantienen el foco accesible y los indicadores de foco de botones y enlaces.

La selección desde lista, desde una ficha o desde un detalle usa el mismo destino.
La consulta con resultado único conserva su selección automática. Cambiar cantidad
de cuotas no vuelve a desplazar. Se respeta la preferencia de reducir animaciones.
Los importes, firmas, permisos y controles de pago no cambian.

Validación: ESLint, compilación de producción y navegador con datos ficticios locales.
Se verifican enlaces de regreso, posición superior del recuadro y ausencia de contorno,
selección desde ficha/detalle/general, cambio de cuotas sin otro desplazamiento,
pago con préstamo fijo, aislamiento por agencia e historiales DNI/RUC.

Distribución: esta corrección de código ya está publicada. La entrega actual solo sincroniza documentación; copia los archivos de INSTRUCCIONES_ACTUALIZACION.md sin sustituir carpetas completas. No se necesita SQL adicional para la documentación.
