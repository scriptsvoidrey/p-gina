# P-GINA / VOID Hub

Aplicación web estática con navegación inferior, biblioteca local de scripts, publicaciones locales y autenticación de usuarios mediante Supabase Auth.

## Cuentas

- El usuario crea su cuenta con un nombre de usuario, contraseña y confirmación de contraseña.
- Para iniciar sesión solo necesita el nombre de usuario y la contraseña.
- El nombre admite entre 3 y 24 caracteres: letras ASCII, números, punto, guion y guion bajo.
- La contraseña debe tener al menos 8 caracteres.
- Supabase Auth gestiona las credenciales y la sesión; la contraseña nunca se guarda en localStorage.
- El nombre se convierte internamente en un identificador de correo técnico bajo el dominio reservado `.invalid`; no se solicita un correo real.
- En Supabase → Authentication → Providers → Email, desactiva la confirmación de correo electrónico. Si está activa, Supabase no puede iniciar sesión con el correo técnico reservado y el registro mostrará una advertencia.
- Como no se solicita un correo real, no hay recuperación de contraseña por correo. El usuario debe recordar su contraseña.

## Configuración de Supabase

La configuración pública está en `supabase-config.js`. Solo contiene la URL y la publishable/anon key, que son aptas para el navegador. Nunca pongas la `service_role` o una secret key en el frontend.

En Authentication → URL Configuration, configura `https://p-gina-sigma.vercel.app` como Site URL y añádela a Redirect URLs.

El esquema `supabase-setup.sql` define las tablas `posts` y `scripts`, sus políticas RLS y el bucket público `void-media`. No hace falta volver a ejecutarlo si el proyecto Supabase ya está preparado.

## Funciones actuales

- Navegación entre Inicio, Scripts, Subir, Comunidad, Soporte y Ajustes.
- Registro, inicio y cierre de sesión con Supabase Auth.
- Validación de contraseña y confirmación al crear la cuenta.
- Selector de tema persistente.
- Publicación de scripts y fotos/videos en el almacenamiento local del navegador. Estos datos no se sincronizan entre dispositivos ni usuarios.
- El botón de soporte copia el mensaje; no hay un canal de soporte conectado todavía.

## Archivos

- `index.html`: interfaz y controles de la aplicación.
- `style.css`: estilos.
- `app.js`: navegación, autenticación y acciones de interfaz.
- `supabase-config.js`: configuración pública de Supabase.
- `supabase-setup.sql`: esquema SQL y políticas RLS para la futura sincronización en Supabase.

## Despliegue

Al integrar los cambios en `main`, Vercel desplegará automáticamente si el proyecto está conectado al repositorio y a esa rama.
