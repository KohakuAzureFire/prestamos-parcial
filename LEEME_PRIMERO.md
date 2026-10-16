# Sistema de préstamos actualizado

Esta versión amplía el sistema con cartera por agencia y cobro de cuotas. Conserva el diseño anterior y añade el menú Pagos.

## Ejecutar sin reemplazar tu aplicación

Las migraciones de pagos y clientes por agencia ya se aplicaron al proyecto `prestamos-parcial` el 16 de octubre de 2026. La firma de identidad está configurada y el corte diario está activo. No vuelvas a ejecutar la migración ni regeneres la clave para arrancar esta copia.

1. Descomprime este ZIP en una carpeta nueva, por ejemplo `PrestamosPrueba` en el Escritorio.
2. Abre la carpeta `ProyectoActual/app` de esa copia, donde está `package.json`.
3. En su terminal ejecuta `npm.cmd install` y luego `npm.cmd run dev -- --port 3001`.
4. Abre http://localhost:3001 e ingresa con una cuenta vigente de agencia.

Esto conserva los archivos de tu aplicación anterior. **Ambas copias usan el mismo Supabase**: los registros y pagos se comparten. Además, los permisos de la base ya cambiaron; los formularios antiguos pueden dejar de funcionar. Para aislar también los datos se necesita otro proyecto Supabase.

Se conservaron los clientes, préstamos, cuotas y pagos actuales. Cada ficha indica si su verificación requiere revalidación. Clientes muestra solo registros vinculados a la agencia; Nuevo préstamo recupera por DNI al cliente de otra agencia. Consultar `docs/ESTADO_IMPLEMENTACION.md`, sección 4, para las cinco cuentas de evaluación.

El ZIP conserva tu `.env.local` para tu uso privado y añade IDENTITY_SIGNING_SECRET; no se publica en el navegador. No subas ese archivo a un repositorio público.

## Si copias archivos sobre el proyecto anterior

Reemplaza `app/src` por completo, copia `app/scripts`, `app/supabase`, `docs` y los archivos de configuración. No mezcles componentes antiguos con los nuevos: se retiró el formulario de cambio manual de condición.

## Despliegue

Configura en el proveedor de Next.js estas variables de `.env.local`:

- NEXT_PUBLIC_SUPABASE_URL
- NEXT_PUBLIC_SUPABASE_ANON_KEY
- DECOLECTA_API_TOKEN
- IDENTITY_SIGNING_SECRET

Ejecuta `npm run build`; el servidor de producción se inicia con `npm start`. La API de DNI requiere ejecución de servidor; no sirve una exportación HTML estática. La tarea diaria se programa en Supabase al aplicar la migración, no depende de mantener abierta una PC. La aplicación calcula los estados actuales al consultar y antes de prestar aunque el corte todavía no haya corrido.

Los pagos registrados en el proyecto compartido afectan los mismos datos para todos los integrantes. No se agregó una pasarela externa.

Consulta `docs/ESTADO_IMPLEMENTACION.md` para conocer las comprobaciones realizadas y los límites de las pruebas.

## Cambios de esta revisión

Clientes por agencia con ficha única; reutilización del DNI vigente entre agencias; revalidación compartida con autoría; tres cuadros del detalle; buscadores DNI/código con PR- fijo; carga automática de cuotas desde Registrar pago. El Word, REQUISITOS.md y ESTADO_IMPLEMENTACION.md están actualizados en docs.

## Guardado de clientes

Nuevo: el paso 1 prepara un borrador, sin crear cliente. Cliente, verificación, préstamo y cuotas se guardan al confirmar el paso 3. Salir o recargar descarta lo pendiente. Existente: Guardar verificación y continuar conserva la revalidación aunque abandones el préstamo. La migración de esta corrección ya está aplicada. Los registros anteriores no se borraron.
