-- VOID Hub · Supabase setup
-- Ejecuta este archivo completo en Supabase > SQL Editor.

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null default 'Usuario VOID',
  title text not null check (char_length(title) between 1 and 80),
  comment text not null default '' check (char_length(comment) <= 400),
  media_url text not null,
  media_path text not null,
  media_type text not null check (media_type in ('image','video')),
  created_at timestamptz not null default now()
);
alter table public.posts enable row level security;
drop policy if exists "Public can read posts" on public.posts;
create policy "Public can read posts" on public.posts for select to anon, authenticated using (true);
drop policy if exists "Signed-in users can publish as themselves" on public.posts;
create policy "Signed-in users can publish as themselves" on public.posts for insert to authenticated with check ((select auth.uid()) = author_id);
drop policy if exists "Authors can delete own posts" on public.posts;
create policy "Authors can delete own posts" on public.posts for delete to authenticated using ((select auth.uid()) = author_id);
grant select on public.posts to anon, authenticated;
grant insert, delete on public.posts to authenticated;
create index if not exists posts_author_id_idx on public.posts(author_id);

create table if not exists public.scripts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null default 'Usuario VOID',
  title text not null check (char_length(title) between 1 and 80),
  description text not null default '' check (char_length(description) <= 400),
  code text not null check (char_length(code) between 1 and 100000),
  created_at timestamptz not null default now()
);
alter table public.scripts enable row level security;
drop policy if exists "Public can read scripts" on public.scripts;
create policy "Public can read scripts" on public.scripts for select to anon, authenticated using (true);
drop policy if exists "Authenticated users publish scripts" on public.scripts;
create policy "Authenticated users publish scripts" on public.scripts for insert to authenticated with check ((select auth.uid()) = author_id);
drop policy if exists "Authors delete own scripts" on public.scripts;
create policy "Authors delete own scripts" on public.scripts for delete to authenticated using ((select auth.uid()) = author_id);
grant select on public.scripts to anon, authenticated;
grant insert, delete on public.scripts to authenticated;
create index if not exists scripts_author_id_idx on public.scripts(author_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('void-media','void-media',true,52428800,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "Public can view VOID media" on storage.objects;
create policy "Public can view VOID media" on storage.objects for select to anon, authenticated using (bucket_id='void-media');
drop policy if exists "Users upload to own VOID folder" on storage.objects;
create policy "Users upload to own VOID folder" on storage.objects for insert to authenticated with check (bucket_id='void-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Users delete own VOID media" on storage.objects;
create policy "Users delete own VOID media" on storage.objects for delete to authenticated using (bucket_id='void-media' and (storage.foldername(name))[1]=(select auth.uid())::text);

-- Las publicaciones y archivos se pueden ver públicamente.
-- Nunca expongas la service_role o secret key en el navegador.
