-- Fahari client and asset photo storage.
-- Run this after the main Bripta/Loanflow database structure has been copied
-- into the new Fahari Supabase project.

alter table public.loan_clients
  add column if not exists photo_path text,
  add column if not exists asset_photo_paths jsonb not null default '[]'::jsonb;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('fahari-client-photos', 'fahari-client-photos', true, 524288, array['image/jpeg', 'image/png', 'image/webp']),
  ('fahari-client-assets', 'fahari-client-assets', true, 524288, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "fahari photo read" on storage.objects;
create policy "fahari photo read"
on storage.objects for select
using (bucket_id in ('fahari-client-photos', 'fahari-client-assets'));

drop policy if exists "fahari photo upload" on storage.objects;
create policy "fahari photo upload"
on storage.objects for insert to authenticated
with check (bucket_id in ('fahari-client-photos', 'fahari-client-assets'));

drop policy if exists "fahari photo update" on storage.objects;
create policy "fahari photo update"
on storage.objects for update to authenticated
using (bucket_id in ('fahari-client-photos', 'fahari-client-assets'))
with check (bucket_id in ('fahari-client-photos', 'fahari-client-assets'));

drop policy if exists "fahari photo delete" on storage.objects;
create policy "fahari photo delete"
on storage.objects for delete to authenticated
using (bucket_id in ('fahari-client-photos', 'fahari-client-assets'));

create index if not exists loan_clients_business_id_number_idx
  on public.loan_clients (business_id, id_number);

create index if not exists loan_clients_business_phone_idx
  on public.loan_clients (business_id, phone);
