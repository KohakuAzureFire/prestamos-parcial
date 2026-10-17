# Actualización: control de sesiones

El ZIP contiene solamente los archivos nuevos o modificados respecto de la versión que ya subiste. Copia cada archivo sobre su ruta actual. **No elimines `app/src`, `app/scripts` ni `app/tests`**: el paquete no incluye sus archivos sin cambios.

Conserva `.env.local` y `node_modules`. No necesitas ejecutar `npm ci`: las dependencias no cambian.

## GitHub web: tres commits

Abre la raíz de `KohakuAzureFire/prestamos-parcial`, rama `main`. Para cada grupo usa **Add file → Upload files**, arrastra el contenido del grupo, comprueba las rutas y confirma. No subas la carpeta numerada contenedora.

1. Contenido de `01_BASE_DATOS_Y_PRUEBAS`: carpeta `app` con el script nuevo y las pruebas. Commit: **`feat: preparar control de sesiones en base de datos`**.
2. Contenido de `02_CODIGO`: carpeta `app` con los archivos de `src`. Commit: **`feat: agregar contador de inactividad y sesion unica`**.
3. Contenido de `03_DOCUMENTACION`: carpeta `docs`, `LEEME_PRIMERO.md` e `INSTRUCCIONES_ACTUALIZACION.md`. Commit: **`docs: documentar activacion y pruebas de sesiones`**.

Cada grupo tiene menos de 100 archivos. Las rutas definitivas empiezan por `app/` o `docs/`, nunca por `01_`, `02_` o `03_`.

Después avisa que terminaste para aplicar el SQL nuevo y comprobar Vercel. La versión nueva necesita `app/scripts/control_sesiones.sql`; hasta activarlo puede aparecer un error al iniciar sesión. No cambies las claves ni subas `.env.local`.

La lista exacta de archivos está en `docs/ARCHIVOS_CAMBIADOS_SESIONES.md`.
