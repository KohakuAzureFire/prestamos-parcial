# Corrección de regresos y desplazamiento — solo cambios

Este paquete se aplica sobre la última versión ya publicada (commit c782f16).
No es un proyecto completo: contiene únicamente seis archivos modificados,
agrupados en tres carpetas para publicar tres commits desde la web de GitHub.

## 1. Código: tres archivos

- app/src/components/Pagos.tsx
- app/src/app/globals.css
- app/src/app/dashboard/clientes/[id]/historial/page.tsx

En GitHub, abre la RAÍZ de prestamos-parcial, rama main.
Add file → Upload files. En tu computadora entra en 01_CODIGO y arrastra
la carpeta app que hay DENTRO. Solo contiene los tres archivos anteriores.
Commit: «Corregir enlaces de regreso y desplazamiento en pagos».

No subas la carpeta 01_CODIGO: se usa solo para organizar el lote.
No entres en app en GitHub para este lote: arrastrar app dentro crearía app/app.

## 2. Documentación: un archivo

- docs/AJUSTES_REGRESO_Y_DESPLAZAMIENTO.md

En GitHub vuelve a la RAÍZ. Add file → Upload files.
Entra en 02_DOCUMENTACION y arrastra la carpeta docs que hay DENTRO.
Commit: «Documentar ajustes de navegación y cobro».

## 3. Instrucciones: dos archivos

- INSTRUCCIONES_ACTUALIZACION.md
- LEEME_PRIMERO.md

En GitHub, desde la RAÍZ, Add file → Upload files.
Entra en 03_INSTRUCCIONES y arrastra sus DOS ARCHIVOS, no la carpeta.
Commit: «Actualizar instrucciones para publicar solo cambios».

## Actualizar tu copia local

Detén el servidor si está abierto. Copia app desde 01_CODIGO sobre el app
existente, aceptando reemplazar archivos. Copia docs desde 02_DOCUMENTACION
sobre docs. Copia los dos archivos de 03_INSTRUCCIONES a la raíz del proyecto.
NO elimines app, src ni otras carpetas: este paquete solo contiene cambios.
Conserva .env.local, node_modules y todos los archivos no incluidos.
Puedes retirar app/.next y ejecutar npm.cmd run dev desde app.
No necesitas npm.cmd ci: no cambian dependencias.

## Publicación

Después de los tres commits, avisa para verificar GitHub, Supabase y Vercel.
La integración de Vercel puede desplegar main automáticamente con cada commit.
Esta corrección no requiere SQL adicional, cambiar claves ni modificar Supabase.
Nunca subas .env.local, node_modules, .next, .git ni .vercel.

## Qué comprobar

- En Pagos desde ficha: «← Volver a la ficha del cliente», arriba del título,
  sin recuadro, con la misma apariencia que «← Volver a clientes».
- En Pagos desde detalle: «← Volver al detalle del préstamo», mismo estilo.
- En historial de DNI/RUC: regreso con flecha encima del título, a la misma ficha.
- Al elegir préstamo, el recuadro del titular queda junto al borde superior del
  contenido, con margen de 8 px y sin contorno celeste adicional.
- Aplica en ficha, detalle y Pagos general. Elegir cantidad de cuotas no repite
  el desplazamiento. El foco se conserva para accesibilidad, sin dibujar el borde.
