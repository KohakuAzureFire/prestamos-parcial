# Control de sesiones

Esta actualización incorpora 15 minutos de inactividad y una única sesión por cuenta. No cambia los límites de crédito ni los datos históricos.

## Interfaz

La cabecera conserva nombre y rol, agencia y fecha; después muestra `Sesión 15:00`. El indicador se vuelve ámbar durante los últimos dos minutos y rojo durante el último. Un aviso ofrece **Continuar sesión** y **Cerrar sesión**. Teclado, puntero y desplazamiento renuevan la actividad, con envíos limitados a uno cada diez segundos. Las consultas automáticas no renuevan el tiempo. Varias pestañas comparten la misma sesión.

Al cerrar por inactividad se pierden los formularios sin confirmar. Los préstamos y pagos ya confirmados permanecen registrados. Si la conexión se interrumpe durante una confirmación, revisa el historial antes de intentar una nueva operación.

## Validación en servidor

`app/scripts/control_sesiones.sql` guarda únicamente la sesión actual del asesor y su última actividad. Comprueba el identificador firmado de Supabase y su registro en `auth.sessions`. Un nuevo inicio invalida al anterior; el navegador anterior lo detecta en el siguiente control (hasta 15 segundos con conexión), y la base de datos rechaza sus operaciones desde que se registra el nuevo inicio.

La autorización central `private.asesor()` también comprueba la sesión. No basta con ocultar botones. Una sesión vencida o cerrada no se reactiva con el mismo identificador: hay que iniciar sesión nuevamente. El cierre utiliza alcance local y no revoca una sesión posterior de otra computadora.

No se agregan dependencias ni variables de entorno. Se conserva `.env.local`.

## Activación coordinada

1. Subir los tres grupos del ZIP a GitHub, conservando las rutas indicadas.
2. Avisar que la subida terminó. Después se aplicará **solo** `app/scripts/control_sesiones.sql` al Supabase existente y se verificará Vercel.
3. Volver a iniciar sesión en los navegadores. Las sesiones anteriores a esta actualización no están registradas en el nuevo control.

**La versión nueva requiere el SQL nuevo.** Si Vercel publica automáticamente antes de aplicar SQL, el acceso mostrará un error de control de sesiones hasta completar la activación. Programar estos pasos juntos cuando no se estén registrando operaciones. No ejecutar nuevamente los scripts antiguos de actualización como sustituto de este archivo.

## Pruebas reproducibles

Desde `app`, con las dependencias locales de `app/tests` instaladas:

```sh
node tests/sesiones.test.mjs
npm run lint
npm run build
```

El test de sesiones usa PostgreSQL en memoria y los datos de prueba; no conecta con Supabase real. Comprueba sesión única, inactividad, renovación por actividad, consultas que no renuevan, cierre antiguo que no afecta al nuevo, autorización de negocio, rechazo de una sesión de otra cuenta y ejecución repetida del SQL sin pérdida de datos.

Prueba manual: ingresar en dos navegadores con la misma cuenta. El primero debe mostrar el motivo de cierre y no poder registrar operaciones; el segundo debe seguir funcionando. Dejar una sesión sin interacción durante 14 minutos para ver el aviso; continuar debe renovar el contador. Dejar transcurrir 15 minutos debe devolver al inicio de sesión.
