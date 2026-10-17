# Actualización de sesiones

Este paquete es un parche sobre el proyecto actual: contiene solo archivos cambiados.

- Tiempo máximo sin actividad: **15 minutos**.
- Contador en cabecera y aviso durante el último minuto.
- Una sesión por cuenta, validada también en la base de datos.
- No cambian las dependencias ni las variables de entorno.

Lee `INSTRUCCIONES_ACTUALIZACION.md` para copiar y subir los tres grupos. No borres carpetas actuales ni `.env.local`. Después de subir a GitHub hay que activar `app/scripts/control_sesiones.sql` y verificar Vercel antes de probar en producción.

Detalles y pruebas: `docs/CONTROL_SESIONES.md`.
