# VOID Hub

Hub estático de scripts y comunidad. Mantiene la interfaz existente (Outfit, temas y menú inferior) y utiliza Supabase para autenticación, feed público y archivos multimedia.

## Conectar Supabase

1. Crea un proyecto en https://supabase.com/.
2. En **Project Settings → API**, copia **Project URL** y la clave **anon/public**.
3. Sustituye los dos valores de `supabase-config.js`. No uses nunca la clave `service_role` en el frontend.
4. Abre **SQL Editor** en Supabase, pega todo el contenido de `supabase-setup.sql` y pulsa Run.
5. En **Authentication → Providers → Email**, habilita Email. Para pruebas puedes desactivar la confirmación de email; en producción es mejor mantenerla y configurar SMTP.
6. En **Authentication → URL Configuration**, agrega `https://p-gina-sigma.vercel.app` como Site URL y también en Redirect URLs.
7. Sube los cambios a la rama principal de GitHub. Vercel desplegará automáticamente al detectar el commit.

## Biblioteca de scripts y publicaciones

- Publica scripts con título, descripción y código desde Subir; aparecen en Scripts para todos.
- Al abrir un script se muestra el código con botón Copiar código.
- Cada usuario puede eliminar sus propios scripts y publicaciones; las políticas RLS impiden borrar contenido ajeno.
- Las fotos y videos se suben al bucket público `void-media` y se muestran en el feed.
- Ejecuta de nuevo el SQL actualizado en `supabase-setup.sql` para crear la tabla `scripts` y sus políticas.

## Qué queda conectado

- Registro e inicio de sesión por correo y contraseña.
- Sesión persistente con Supabase Auth y cierre de sesión.
- Publicaciones públicas con foto/video en Supabase Storage y metadatos en Postgres.
- Feed que consulta las últimas 50 publicaciones para todos los visitantes.
- Límite de archivo de 50 MB y tipos permitidos definidos en el SQL.
- Botones Abrir de Scripts muestran una ficha del recurso. No se inventan enlaces de descarga: agrega el enlace real cuando publiques cada recurso.

## Archivos

- `index.html`: interfaz y carga de dependencias.
- `style.css`: diseño original más estilos de los diálogos.
- `app.js`: navegación, autenticación, feed, subida y fichas de scripts.
- `supabase-config.js`: credenciales públicas del proyecto (debes completarlo).
- `supabase-setup.sql`: tablas, políticas RLS y bucket público.

## Actualizar GitHub / Vercel

En tu PC, descarga/clona el repo, reemplaza los archivos y ejecuta:

```bash
git add .
git commit -m "Conectar VOID Hub con Supabase"
git push origin main
```

Si trabajas desde GitHub web: abre cada archivo, pulsa Edit, pega el contenido actualizado y confirma el commit en `main`. Si Vercel está conectado a ese repo y rama, desplegará automáticamente.

**Importante:** el feed solo será global después de crear el proyecto Supabase, completar `supabase-config.js` y ejecutar el SQL. Los datos antiguos de localStorage no se migran automáticamente.
