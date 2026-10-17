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

La activación ya se completó el 17 de octubre de 2026 en el proyecto existente. Se aplicó `app/scripts/control_sesiones.sql` mediante la migración `20261017072218_control_sesiones_inactividad_y_sesion_unica`. La versión de GitHub contrastada es `5723a13`; Vercel reportó el despliegue exitoso y se verificaron login público, rechazo de la API sin sesión y redirección de rutas protegidas.

Después de activar este control las sesiones antiguas necesitan un nuevo ingreso, porque todavía no tienen registro en la tabla de control. La comprobación de permisos confirmó RLS activo, acceso directo a la tabla privada denegado y ejecución de la función pública permitida solo a usuarios autenticados. La migración conservó las operaciones existentes; en la verificación había 11 préstamos y 6 pagos, como dato de ese momento.

Para una instalación nueva, aplica el script de sesiones después de los ajustes de fichas y pagos. El código requiere ese SQL antes de poder iniciar una sesión operativa. No reapliques un SQL acumulado anterior después del control de sesiones porque puede reemplazar su autorización central. Consulta el orden de `ESTADO_IMPLEMENTACION.md`.

Esta actualización de textos no necesita ejecutar el script otra vez ni cambiar `.env.local`.

## Pruebas reproducibles

Desde `app`, con las dependencias locales de `app/tests` instaladas:

```sh
node tests/sesiones.test.mjs
npm run lint
npm run build
```

El test de sesiones usa PostgreSQL en memoria y los datos de prueba; no conecta con Supabase real. Comprueba sesión única, inactividad, renovación por actividad, consultas que no renuevan, cierre antiguo que no afecta al nuevo, autorización de negocio, rechazo de una sesión de otra cuenta y ejecución repetida del SQL sin pérdida de datos.

Prueba manual: ingresar en dos navegadores con la misma cuenta. El primero debe mostrar el motivo de cierre y no poder registrar operaciones; el segundo debe seguir funcionando. Dejar una sesión sin interacción durante 14 minutos para ver el aviso; continuar debe renovar el contador. Dejar transcurrir 15 minutos debe devolver al inicio de sesión.

La prueba de dos navegadores, el aviso, la renovación, el vencimiento y el cierre local se ejecutó en el entorno aislado. La verificación pública de producción no utiliza credenciales ni confirma préstamos o cobros. Las consultas automáticas cada 15 segundos comprueban vigencia, sin simular actividad. La renovación por interacción se limita a un envío cada diez segundos y las pestañas se sincronizan sin guardar tokens en el mecanismo de sincronización.
