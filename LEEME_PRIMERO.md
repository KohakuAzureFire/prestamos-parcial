# Sistema de préstamos del Sprint 1

El proyecto académico atiende a personas con DNI o RUC 10 y empresas con RUC 20 en cinco agencias del Perú. Las fichas y vínculos se comparten con los permisos del grupo atendido; la cartera de Préstamos y el listado de Clientes conservan el alcance de la agencia. Pagos consulta las obligaciones del propietario y sus empresas entre agencias.

## Documentación de la entrega

- `docs/REQUISITOS.md` y `docs/Sprint_1_Sistema_Prestamos.docx`: reglas, pantallas, ocho historias de usuario, criterios de aceptación y casos de comprobación. Mantienen el mismo contenido funcional en sus formatos respectivos.
- `docs/ESTADO_IMPLEMENTACION.md`: funciones integradas, alcance, pruebas, base de datos y publicación verificada.
- `docs/FICHAS_COMPARTIDAS.md`, `docs/REVALIDACION_Y_PAGOS.md` y `docs/OBSERVACIONES_CLIENTES_REVALIDACION.md`: identidad compartida, cartera local y consulta global de pagos.
- `docs/CAMBIOS_INTERFAZ.md`, `docs/CAMPO_MONTO.md`, `docs/FICHA_RESUMIDA_Y_PAGOS.md` y `docs/AJUSTES_REGRESO_Y_DESPLAZAMIENTO.md`: decisiones de interfaz y recorrido actual.
- `docs/CONTROL_SESIONES.md`: contador, aviso y validación de 15 minutos de inactividad y sesión única.
- `app/README.md` y `app/tests/README.md`: ejecución, configuración y pruebas.

`docs/Contrato_profesor.docx` conserva el modelo recibido del profesor. `app/templates/contrato.docx` es la plantilla usada por el sistema; su texto y diseño no se alteran con esta revisión documental. `app/AGENTS.md` contiene instrucciones de desarrollo generadas por Next.js y no reemplaza los requisitos.

## Actualización actual

Esta entrega sincroniza documentación con el código publicado `5723a13`. Incluye únicamente Markdown y el Word del sprint. Sigue `INSTRUCCIONES_ACTUALIZACION.md` para copiar y publicar los archivos. No borres carpetas actuales, no cambies `.env.local` y no ejecutes SQL ni `npm ci` por esta actualización.

El control de sesiones ya fue aplicado a Supabase y el despliegue de código se comprobó el 17 de octubre de 2026. El inventario del anterior paquete de sesiones se conserva en `docs/ARCHIVOS_CAMBIADOS_SESIONES.md` como referencia histórica, no como instrucciones de esta entrega.
