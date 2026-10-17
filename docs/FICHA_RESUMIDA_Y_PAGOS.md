# Ficha resumida y navegación de pagos

## Cambios

La ficha conserva identidad, información SUNAT, capital global, vínculos y controles
excepcionales de autorización. Las acciones finales son Consultar para pagar y
Ver historial. Se retira Préstamos en tu agencia: los préstamos siguen en Préstamos,
con sus filtros de documento y reglas de acceso por agencia.

Los historiales se consultan en /dashboard/clientes/[id]/historial?tipo=dni|ruc.
La ruta valida el acceso a la misma ficha con la sesión del asesor antes de leer su
historial. Personas solo DNI van directamente a DNI; personas con RUC10 tienen un
menú; empresas van directamente a RUC. Una combinación inválida redirige al historial
que corresponde a la ficha. Se conservan todos los registros y evidencias existentes.
Cada página tiene Volver a la ficha del cliente.

## Pagos por origen

- cliente_id: documento fijo, consulta global del propietario y sus empresas,
  Volver a la ficha del cliente. Conserva la ficha de origen aunque se pague a otra
  empresa del grupo. La lista no se desplaza hasta que se selecciona un préstamo.
- prestamo_id: UUID completo comprobado con RLS y estado confirmado en el servidor.
  Solo consulta ese UUID, filtra la respuesta al mismo ID y bloquea el código y tipo.
  Carga automáticamente y muestra Volver al detalle del préstamo.
- Entrada general: permite DNI, RUC o código; no hay regreso contextual.

Los parámetros se resuelven a rutas internas conocidas, sin aceptar URLs de retorno
arbitrarias. Un préstamo no visible por el asesor no puede abrirse como detalle fijo.
La búsqueda global de Pagos conserva sus reglas para cobrar entre agencias.

Al seleccionar un préstamo, manualmente o por resultado único, se mueve el foco y
se desplaza hasta el nombre del titular. La cantidad de cuotas no vuelve a mover la
pantalla. Respeta prefers-reduced-motion y deja margen para la cabecera. Cambiar la
búsqueda sigue borrando los resultados anteriores y la confirmación de dinero recibido.

La etiqueta visual habilitado pasa a Sin atrasos. El valor almacenado y las condiciones
de elegibilidad permanecen iguales. Estar sin atrasos no acredita identidad ni cupo.

## Publicación y validación

No hay cambios de SQL, de dependencias ni de variables de entorno. El usuario publica
los tres commits indicados en INSTRUCCIONES_ACTUALIZACION.md. Después se revisarán
Supabase y el despliegue Vercel. No se publica ni se modifica producción con este ZIP.

Verificación: ESLint, compilación Next/TypeScript y pruebas en navegador con dos agencias
y datos ficticios aislados. Casos: ficha compacta en los tres tipos, selección correcta
de historial y retorno, pago global desde empresa, préstamo fijo desde su detalle,
regreso contextual, desplazamiento único al seleccionar, búsqueda general editable,
rechazo de UUID de otra agencia y cobro de prueba con cuotas. Revisión móvil/escritorio.
