# VOID Hub

Hub estático de scripts y comunidad. Mantiene la interfaz existente (Outfit, temas y menú inferior) y utiliza Supabase para autenticación, feed público y archivos multimedia.

## Estado de conexión

El proyecto Supabase conectado es `p-gina`. La configuración pública está en `supabase-config.js`; la base de datos ya tiene las tablas `posts` y `scripts`, políticas RLS y el bucket público `void-media`.

## Configuración de Supabase

1. En **Authentication → Providers → Email**, habilita Email.
2. En **Authentication → URL Configuration**, agrega `https://p-gina-sigma.vercel.app` como Site URL y también en Redirect URLs.
3. Para pruebas puedes desactivar la confirmación de email; en producción es mejor mantenerla y configurar SMTP.
4. El esquema completo e idempotente está en `supabase-setup.sql`. No necesitas volver a ejecutarlo en el proyecto ya configurado, salvo que estés preparando otro proyecto.

## Biblioteca de scripts y publicaciones

- Publica scripts con título, descripción y código desde Subir; aparecen en Scripts para todos.
- Al abrir un script se muestra el código con botón Copiar código.
- Cada usuario puede eliminar sus propios scripts y publicaciones; las políticas RLS impiden borrar contenido ajeno.
- Las fotos y videos se suben al bucket público `void-media` y se muestran en el feed.
- Los archivos tienen un límite de 50 MB y se permiten imágenes JPEG, PNG, WebP, GIF y videos MP4, WebM y QuickTime.

## Funciones implementadas

- Registro e inicio de sesión por correo y contraseña.
- Sesión persistente con Supabase Auth y cierre de sesión.
- Publicaciones públicas con foto/video en Supabase Storage y metadatos en Postgres.
- Feed que consulta las últimas 50 publicaciones para todos los visitantes.
- Botones Abrir de Scripts muestran el código y permiten copiarlo. Los enlaces externos solo deben agregarse cuando exista un destino real.

## Archivos

- `index.html`: interfaz y carga de dependencias.
- `style.css`: diseño original más estilos de los diálogos.
- `app.js`: navegación, autenticación, feed, subida y fichas de scripts.
- `supabase-config.js`: URL y publishable key públicas del proyecto.
- `supabase-setup.sql`: tablas, grants, políticas RLS, índices y bucket público.

## Despliegue

Al fusionar los cambios en `main`, Vercel debe desplegar automáticamente si el proyecto está conectado a este repositorio y esa rama.

**Importante:** las publicaciones antiguas guardadas en localStorage no se migran automáticamente.
