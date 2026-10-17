# Sistema de préstamos actualizado

Esta entrega completa las fichas compartidas entre agencias, los vínculos del propietario y sus empresas, los pagos de todo el grupo al consultar DNI/RUC10/RUC20, el desplegable de Solicitar préstamo y el plazo controlado de 1 a 60 meses. Conserva el monto con soles y centavos y las funciones anteriores de identidad, cronograma, contrato y cobranza.

## Instalar sobre tu carpeta actual

1. Detén el servidor (Ctrl+C).
2. Conserva app/.env.local, app/node_modules, app/templates y .git.
3. Reemplaza app/src y copia app/scripts del ZIP. Elimina app/.next. Actualiza docs y los archivos de instrucciones.
4. Abre app/scripts/ACTUALIZAR_SISTEMA.sql en VS Code. Copia TODO EL CÓDIGO y ejecútalo en una consulta nueva del SQL Editor de Supabase. No pegues el nombre o la ruta del archivo. Este archivo contiene los ajustes anteriores y el actual; no hace falta ejecutar los demás por separado. Se puede repetir sin cambiar operaciones anteriores.
5. Desde app ejecuta npm.cmd run dev. No necesitas reinstalar dependencias si conservas node_modules de esta base.

El SQL nuevo no se ha aplicado al proyecto real desde este chat. El ZIP no contiene tus claves. No cambiaron package.json, package-lock.json ni las variables requeridas.

Consulta INSTRUCCIONES_ACTUALIZACION.md y docs/FICHAS_COMPARTIDAS.md. Las pruebas se realizaron con datos ficticios en una base aislada. La aplicación que utilice tu Supabase real registra allí las operaciones que confirmes.
