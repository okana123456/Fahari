-- Fahari complete fresh-project installation
-- Generated from the current Fahari schema and reusable feature migrations.
-- Run this complete file once in the Fahari Supabase SQL Editor.

-- ============================================================================
-- SOURCE: fahari-database-setup.sql
-- ============================================================================
-- Fahari complete database setup
-- Run this entire file once in the NEW Fahari Supabase SQL Editor.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.loan_staff (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  auth_user_id uuid unique,
  name text not null,
  email text not null,
  phone text,
  role text not null default 'loan_officer',
  is_active boolean not null default true,
  last_login timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, email)
);

create table if not exists public.loan_settings (
  id uuid primary key default gen_random_uuid(),
  business_id text not null unique,
  company_name text not null default 'Fahari',
  company_phone text,
  company_email text,
  company_address text,
  currency text not null default 'KES',
  default_grace_period integer not null default 7,
  default_late_penalty_pct numeric(8,4) not null default 5,
  default_processing_fee_pct numeric(8,4) not null default 0,
  standard_weekly_rate numeric(8,4) not null default 5,
  micro_weekly_rate numeric(8,4) not null default 5,
  micro_threshold numeric(14,2) not null default 5000,
  loan_no_prefix text not null default 'LN',
  app_no_prefix text not null default 'APP',
  receipt_no_prefix text not null default 'RCP',
  disbursement_method text not null default 'mpesa',
  mpesa_consumer_key text,
  mpesa_consumer_secret text,
  mpesa_passkey text,
  mpesa_shortcode text,
  daraja_environment text not null default 'production',
  daraja_credentials_saved boolean not null default false,
  mpesa_auto_confirm boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Daraja credentials are backend-only. No anon/authenticated policies are added.
create table if not exists public.fahari_daraja_credentials (
  business_id text primary key,
  consumer_key text not null,
  consumer_secret text not null,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.fahari_daraja_credentials enable row level security;
revoke all on table public.fahari_daraja_credentials from anon, authenticated;
grant all on table public.fahari_daraja_credentials to service_role;

create table if not exists public.loan_clients (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  full_name text not null,
  id_number text,
  phone text,
  alternative_phone text,
  email text,
  gender text,
  dob date,
  address text,
  occupation text,
  employer text,
  monthly_income numeric(14,2) not null default 0,
  next_of_kin_name text,
  next_of_kin_phone text,
  next_of_kin_relation text,
  notes text,
  status text not null default 'active',
  loan_officer_id uuid references public.loan_staff(id) on delete set null,
  created_by uuid references public.loan_staff(id) on delete set null,
  photo_path text,
  asset_photo_paths jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.loan_products (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  name text not null,
  description text,
  min_amount numeric(14,2) not null default 0,
  max_amount numeric(14,2) not null default 0,
  interest_rate numeric(8,4) not null default 5,
  interest_type text not null default 'flat',
  interest_period text not null default 'weekly',
  min_term_weeks integer not null default 1,
  max_term_weeks integer not null default 52,
  processing_fee_pct numeric(8,4) not null default 0,
  late_penalty_pct numeric(8,4) not null default 5,
  grace_period_days integer not null default 3,
  requires_guarantor boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, name)
);

create table if not exists public.loan_applications (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  application_no text not null,
  client_id uuid not null references public.loan_clients(id) on delete cascade,
  product_id uuid references public.loan_products(id) on delete set null,
  loan_officer_id uuid references public.loan_staff(id) on delete set null,
  applied_amount numeric(14,2) not null,
  applied_term_weeks integer not null,
  purpose text,
  loan_type text default 'new_loan',
  guarantor_name text,
  guarantor_phone text,
  guarantor_relationship text,
  status text not null default 'submitted',
  application_date date not null default current_date,
  approved_by uuid references public.loan_staff(id) on delete set null,
  approved_at timestamptz,
  reviewed_by uuid references public.loan_staff(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, application_no)
);

create table if not exists public.loans (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  loan_no text not null,
  application_id uuid references public.loan_applications(id) on delete set null,
  client_id uuid not null references public.loan_clients(id) on delete cascade,
  loan_officer_id uuid references public.loan_staff(id) on delete set null,
  principal_amount numeric(14,2) not null default 0,
  disbursed_amount numeric(14,2) not null default 0,
  interest_rate numeric(8,4) not null default 5,
  interest_type text not null default 'flat',
  term_weeks integer not null default 1,
  processing_fee numeric(14,2) not null default 0,
  total_interest numeric(14,2) not null default 0,
  total_payable numeric(14,2) not null default 0,
  weekly_installment numeric(14,2) not null default 0,
  disbursement_method text,
  disbursement_reference text,
  disbursement_date date,
  first_repayment_date date,
  maturity_date date,
  status text not null default 'active',
  outstanding_balance numeric(14,2) not null default 0,
  total_paid numeric(14,2) not null default 0,
  arrears_amount numeric(14,2) not null default 0,
  overdue_days integer not null default 0,
  loan_type text default 'new_loan',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, loan_no)
);

create table if not exists public.loan_schedules (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  loan_id uuid not null references public.loans(id) on delete cascade,
  installment_no integer not null,
  due_date date not null,
  principal_due numeric(14,2) not null default 0,
  interest_due numeric(14,2) not null default 0,
  total_due numeric(14,2) not null default 0,
  principal_paid numeric(14,2) not null default 0,
  interest_paid numeric(14,2) not null default 0,
  total_paid numeric(14,2) not null default 0,
  penalty_charged numeric(14,2) not null default 0,
  status text not null default 'pending',
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (loan_id, installment_no)
);

create table if not exists public.loan_repayments (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  loan_id uuid not null references public.loans(id) on delete cascade,
  receipt_no text not null,
  amount numeric(14,2) not null check (amount > 0),
  payment_method text not null default 'cash',
  payment_reference text,
  payment_date timestamptz not null default now(),
  principal_portion numeric(14,2) not null default 0,
  interest_portion numeric(14,2) not null default 0,
  penalty_portion numeric(14,2) not null default 0,
  mpesa_confirmed boolean not null default false,
  collected_by uuid references public.loan_staff(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, receipt_no)
);

create table if not exists public.loan_penalties (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  loan_id uuid not null references public.loans(id) on delete cascade,
  penalty_amount numeric(14,2) not null default 0,
  reason text,
  date_charged date not null default current_date,
  is_waived boolean not null default false,
  waived_reason text,
  waived_by uuid references public.loan_staff(id) on delete set null,
  waived_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.loan_follow_ups (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  loan_id uuid references public.loans(id) on delete cascade,
  client_id uuid references public.loan_clients(id) on delete cascade,
  officer_id uuid references public.loan_staff(id) on delete set null,
  follow_up_type text,
  notes text,
  outcome text,
  follow_up_date date not null default current_date,
  next_follow_up_date date,
  created_at timestamptz not null default now()
);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  date date not null default current_date,
  ref text,
  description text,
  debit text,
  credit text,
  amount numeric(14,2) not null default 0,
  synced boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.loan_audit_log (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  user_id uuid references public.loan_staff(id) on delete set null,
  action text not null,
  table_name text,
  record_id text,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.loan_billing_cycles (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  billing_month date not null,
  amount numeric(14,2) not null default 3000,
  status text not null default 'pending',
  phone text,
  merchant_request_id text,
  checkout_request_id text,
  receipt_number text,
  result_code text,
  result_description text,
  paid_at timestamptz,
  paid_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, billing_month)
);

create table if not exists public.mpesa_callback_queue (
  id uuid primary key default gen_random_uuid(),
  business_id text,
  transaction_type text,
  trans_id text not null unique,
  trans_time text,
  trans_amount numeric(14,2) not null default 0,
  business_short_code text,
  bill_ref_number text,
  msisdn text,
  first_name text,
  raw_payload jsonb,
  confirmed boolean not null default false,
  unmatched boolean not null default false,
  unmatched_reason text,
  loan_id uuid references public.loans(id) on delete set null,
  repayment_id uuid references public.loan_repayments(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.unmatched_payments (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  account_number text,
  amount numeric(14,2) not null default 0,
  payer_phone text,
  payer_name text,
  mpesa_reference text,
  invoice_id text,
  payment_date timestamptz not null default now(),
  raw_payload jsonb,
  resolved boolean not null default false,
  resolved_at timestamptz,
  resolved_by uuid references public.loan_staff(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Attach incoming callback rows to the correct business even when an older
-- callback function only sends the Paybill shortcode or business code.
create or replace function public.set_callback_business_id()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.business_id is null or trim(new.business_id) = '' then
    select s.business_id into new.business_id
    from public.loan_settings s
    where s.mpesa_shortcode = new.business_short_code
       or s.business_id = new.business_short_code
    limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists set_callback_business_id on public.mpesa_callback_queue;
create trigger set_callback_business_id
before insert or update on public.mpesa_callback_queue
for each row execute function public.set_callback_business_id();

-- Prevent duplicate clients and duplicate M-Pesa repayments within one business.
create unique index if not exists loan_clients_business_id_number_unique
  on public.loan_clients (business_id, lower(trim(id_number)))
  where id_number is not null and trim(id_number) <> '';
create unique index if not exists loan_clients_business_phone_unique
  on public.loan_clients (business_id, regexp_replace(phone, '\D', '', 'g'))
  where phone is not null and trim(phone) <> '';
create unique index if not exists loan_repayments_mpesa_reference_unique
  on public.loan_repayments (business_id, payment_reference)
  where payment_reference is not null
    and trim(payment_reference) <> ''
    and upper(payment_reference) <> 'IMPORT';

-- Speed indexes for daily operations and reports.
create index if not exists loan_staff_business_idx on public.loan_staff (business_id, is_active);
create index if not exists loan_clients_business_name_idx on public.loan_clients (business_id, full_name);
create index if not exists loan_applications_business_status_idx on public.loan_applications (business_id, status, created_at desc);
create index if not exists loans_business_status_idx on public.loans (business_id, status, created_at desc);
create index if not exists loans_client_idx on public.loans (client_id, status);
create index if not exists loans_officer_idx on public.loans (business_id, loan_officer_id);
create index if not exists schedules_business_due_idx on public.loan_schedules (business_id, due_date, status);
create index if not exists schedules_loan_idx on public.loan_schedules (loan_id, installment_no);
create index if not exists repayments_business_date_idx on public.loan_repayments (business_id, payment_date desc);
create index if not exists repayments_loan_idx on public.loan_repayments (loan_id, payment_date);
create index if not exists penalties_business_date_idx on public.loan_penalties (business_id, date_charged desc);
create index if not exists callback_pending_idx on public.mpesa_callback_queue (confirmed, created_at desc);
create index if not exists unmatched_business_idx on public.unmatched_payments (business_id, resolved, created_at desc);

-- Keep updated_at accurate.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'loan_staff','loan_settings','loan_clients','loan_products','loan_applications',
    'loans','loan_schedules','loan_repayments','loan_billing_cycles',
    'mpesa_callback_queue','unmatched_payments'
  ] loop
    execute format('drop trigger if exists set_updated_at on public.%I', table_name);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()', table_name);
  end loop;
end $$;

-- Resolve the logged-in user's business securely.
create or replace function public.current_fahari_business_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select business_id
  from public.loan_staff
  where auth_user_id = auth.uid() and is_active = true
  limit 1;
$$;

revoke all on function public.current_fahari_business_id() from public;
grant execute on function public.current_fahari_business_id() to anon, authenticated, service_role;

-- Enable row-level security on every business table.
alter table public.loan_staff enable row level security;
alter table public.loan_settings enable row level security;
alter table public.loan_clients enable row level security;
alter table public.loan_products enable row level security;
alter table public.loan_applications enable row level security;
alter table public.loans enable row level security;
alter table public.loan_schedules enable row level security;
alter table public.loan_repayments enable row level security;
alter table public.loan_penalties enable row level security;
alter table public.loan_follow_ups enable row level security;
alter table public.journal_entries enable row level security;
alter table public.loan_audit_log enable row level security;
alter table public.loan_billing_cycles enable row level security;
alter table public.mpesa_callback_queue enable row level security;
alter table public.unmatched_payments enable row level security;

-- A new business is provisioned only by the registration Edge Function.
-- Existing administrators can add staff only inside their own business.
drop policy if exists fahari_staff_select on public.loan_staff;
create policy fahari_staff_select on public.loan_staff for select to authenticated
using (auth_user_id = auth.uid() or business_id = public.current_fahari_business_id());
drop policy if exists fahari_staff_insert on public.loan_staff;
create policy fahari_staff_insert on public.loan_staff for insert to authenticated
with check (business_id = public.current_fahari_business_id());
drop policy if exists fahari_staff_update on public.loan_staff;
create policy fahari_staff_update on public.loan_staff for update to authenticated
using (auth_user_id = auth.uid() or business_id = public.current_fahari_business_id())
with check (business_id = public.current_fahari_business_id());
drop policy if exists fahari_staff_delete on public.loan_staff;
create policy fahari_staff_delete on public.loan_staff for delete to authenticated
using (business_id = public.current_fahari_business_id());

-- Apply the same business isolation to the remaining tables.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'loan_settings','loan_clients','loan_products','loan_applications','loans',
    'loan_schedules','loan_repayments','loan_penalties','loan_follow_ups',
    'journal_entries','loan_audit_log','loan_billing_cycles','mpesa_callback_queue',
    'unmatched_payments'
  ] loop
    execute format('drop policy if exists fahari_business_select on public.%I', table_name);
    execute format('drop policy if exists fahari_business_insert on public.%I', table_name);
    execute format('drop policy if exists fahari_business_update on public.%I', table_name);
    execute format('drop policy if exists fahari_business_delete on public.%I', table_name);
    execute format('create policy fahari_business_select on public.%I for select to authenticated using (business_id = public.current_fahari_business_id())', table_name);
    execute format('create policy fahari_business_insert on public.%I for insert to authenticated with check (business_id = public.current_fahari_business_id())', table_name);
    execute format('create policy fahari_business_update on public.%I for update to authenticated using (business_id = public.current_fahari_business_id()) with check (business_id = public.current_fahari_business_id())', table_name);
    execute format('create policy fahari_business_delete on public.%I for delete to authenticated using (business_id = public.current_fahari_business_id())', table_name);
  end loop;
end $$;

-- Storage buckets for compressed profile and asset photos.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('fahari-client-photos', 'fahari-client-photos', true, 524288, array['image/jpeg','image/png','image/webp']),
  ('fahari-client-assets', 'fahari-client-assets', true, 524288, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists fahari_photo_read on storage.objects;
create policy fahari_photo_read on storage.objects for select
using (bucket_id in ('fahari-client-photos','fahari-client-assets'));
drop policy if exists fahari_photo_insert on storage.objects;
create policy fahari_photo_insert on storage.objects for insert to authenticated
with check (bucket_id in ('fahari-client-photos','fahari-client-assets'));
drop policy if exists fahari_photo_update on storage.objects;
create policy fahari_photo_update on storage.objects for update to authenticated
using (bucket_id in ('fahari-client-photos','fahari-client-assets'))
with check (bucket_id in ('fahari-client-photos','fahari-client-assets'));
drop policy if exists fahari_photo_delete on storage.objects;
create policy fahari_photo_delete on storage.objects for delete to authenticated
using (bucket_id in ('fahari-client-photos','fahari-client-assets'));

-- Verification result: this final query should return 15 rows.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'loan_staff','loan_settings','loan_clients','loan_products','loan_applications',
    'loans','loan_schedules','loan_repayments','loan_penalties','loan_follow_ups',
    'journal_entries','loan_audit_log','loan_billing_cycles','mpesa_callback_queue',
    'unmatched_payments'
  )
order by table_name;


-- ============================================================================
-- SOURCE: fahari-photo-storage.sql
-- ============================================================================
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


-- ============================================================================
-- SOURCE: fahari-daraja-secure-credentials.sql
-- ============================================================================
-- Run once in the Fahari Supabase SQL Editor before deploying register-daraja.
-- Credentials are available only to backend functions using the service role.

alter table public.loan_settings
  add column if not exists daraja_credentials_saved boolean not null default false;

create table if not exists public.fahari_daraja_credentials (
  business_id text primary key,
  consumer_key text not null,
  consumer_secret text not null,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.fahari_daraja_credentials enable row level security;
revoke all on table public.fahari_daraja_credentials from anon, authenticated;
grant all on table public.fahari_daraja_credentials to service_role;

-- Preserve and migrate credentials that may already exist in legacy settings.
insert into public.fahari_daraja_credentials (business_id, consumer_key, consumer_secret)
select business_id, trim(mpesa_consumer_key), trim(mpesa_consumer_secret)
from public.loan_settings
where nullif(trim(mpesa_consumer_key), '') is not null
  and nullif(trim(mpesa_consumer_secret), '') is not null
on conflict (business_id) do nothing;

update public.loan_settings s
set daraja_credentials_saved = true
where exists (
  select 1
  from public.fahari_daraja_credentials c
  where c.business_id = s.business_id
);


-- ============================================================================
-- SOURCE: fahari-secure-registration.sql
-- ============================================================================
-- Fahari secure business registration
-- Run this once in the Supabase SQL Editor after the main database setup.

-- Resolve the signed-in staff member's business. Keeping this helper here
-- makes this security patch safe to run even if an earlier setup was partial.
create or replace function public.current_fahari_business_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select business_id
  from public.loan_staff
  where auth_user_id = auth.uid()
    and is_active = true
  limit 1;
$$;

revoke all on function public.current_fahari_business_id() from public;
grant execute on function public.current_fahari_business_id()
to anon, authenticated, service_role;

alter table public.loan_staff enable row level security;

drop policy if exists fahari_staff_insert on public.loan_staff;

create policy fahari_staff_insert
on public.loan_staff
for insert
to authenticated
with check (
  business_id = public.current_fahari_business_id()
);

-- The register-fahari-business Edge Function uses the service role and
-- can create the first administrator. Signed-in users cannot create a new
-- business or attach themselves to another business through the public API.


-- ============================================================================
-- SOURCE: fahari-multi-business-access-fix.sql
-- ============================================================================
-- Fahari multi-business access fix
-- Run this if the same login email/user can belong to more than one Fahari
-- business and one browser shows zero records while another business has data.

create or replace function public.fahari_can_access_business(target_business_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.loan_staff s
    where (
        s.auth_user_id = auth.uid()
        or lower(trim(s.email)) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
      )
      and s.is_active = true
      and s.business_id = target_business_id
  );
$$;

revoke all on function public.fahari_can_access_business(text) from public;
grant execute on function public.fahari_can_access_business(text) to anon, authenticated, service_role;

-- Keep the old helper for compatibility, but make normal policies use the
-- safer fahari_can_access_business(...) check below.
create or replace function public.current_fahari_business_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select business_id
  from public.loan_staff
  where (
      auth_user_id = auth.uid()
      or lower(trim(email)) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
    )
    and is_active = true
  order by last_login desc nulls last, created_at desc
  limit 1;
$$;

grant execute on function public.current_fahari_business_id() to anon, authenticated, service_role;

alter table public.loan_staff enable row level security;

drop policy if exists fahari_staff_select on public.loan_staff;
create policy fahari_staff_select on public.loan_staff
for select to authenticated
using (
  auth_user_id = auth.uid()
  or lower(trim(email)) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
  or public.fahari_can_access_business(business_id)
);

drop policy if exists fahari_staff_insert on public.loan_staff;
create policy fahari_staff_insert on public.loan_staff
for insert to authenticated
with check (public.fahari_can_access_business(business_id));

drop policy if exists fahari_staff_update on public.loan_staff;
create policy fahari_staff_update on public.loan_staff
for update to authenticated
using (
  auth_user_id = auth.uid()
  or lower(trim(email)) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
  or public.fahari_can_access_business(business_id)
)
with check (public.fahari_can_access_business(business_id));

drop policy if exists fahari_staff_delete on public.loan_staff;
create policy fahari_staff_delete on public.loan_staff
for delete to authenticated
using (public.fahari_can_access_business(business_id));

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'loan_settings','loan_clients','loan_products','loan_applications','loans',
    'loan_schedules','loan_repayments','loan_penalties','loan_follow_ups',
    'journal_entries','loan_audit_log','loan_billing_cycles',
    'mpesa_callback_queue','unmatched_payments'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);

    execute format('drop policy if exists fahari_business_select on public.%I', table_name);
    execute format('create policy fahari_business_select on public.%I for select to authenticated using (public.fahari_can_access_business(business_id))', table_name);

    execute format('drop policy if exists fahari_business_insert on public.%I', table_name);
    execute format('create policy fahari_business_insert on public.%I for insert to authenticated with check (public.fahari_can_access_business(business_id))', table_name);

    execute format('drop policy if exists fahari_business_update on public.%I', table_name);
    execute format('create policy fahari_business_update on public.%I for update to authenticated using (public.fahari_can_access_business(business_id)) with check (public.fahari_can_access_business(business_id))', table_name);

    execute format('drop policy if exists fahari_business_delete on public.%I', table_name);
    execute format('create policy fahari_business_delete on public.%I for delete to authenticated using (public.fahari_can_access_business(business_id))', table_name);
  end loop;
end $$;


-- ============================================================================
-- SOURCE: fahari-client-charge-wallet.sql
-- ============================================================================
-- Fahari client charges wallet
-- Run this file once in the Fahari Supabase SQL Editor before deploying index.html.

create table if not exists public.client_charge_transactions (
  id uuid primary key default gen_random_uuid(),
  business_id text not null,
  client_id uuid not null references public.loan_clients(id) on delete cascade,
  loan_id uuid references public.loans(id) on delete set null,
  transaction_type text not null check (transaction_type in ('deposit','excess_deposit','fee_debit','adjustment_credit','adjustment_debit')),
  charge_type text not null default 'other' check (charge_type in ('processing','registration','excess','other')),
  amount numeric(14,2) not null check (amount > 0),
  transaction_date date not null default current_date,
  reference text,
  payment_method text,
  description text,
  source_key text,
  created_by uuid references public.loan_staff(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists client_charge_transactions_source_key_idx
  on public.client_charge_transactions (business_id, source_key)
  where source_key is not null;

create index if not exists client_charge_transactions_client_idx
  on public.client_charge_transactions (business_id, client_id, transaction_date, created_at);

alter table public.client_charge_transactions enable row level security;

drop policy if exists fahari_business_select on public.client_charge_transactions;
create policy fahari_business_select on public.client_charge_transactions for select to authenticated
using (business_id = public.current_fahari_business_id());

drop policy if exists fahari_business_insert on public.client_charge_transactions;
create policy fahari_business_insert on public.client_charge_transactions for insert to authenticated
with check (business_id = public.current_fahari_business_id());

drop policy if exists fahari_business_update on public.client_charge_transactions;
create policy fahari_business_update on public.client_charge_transactions for update to authenticated
using (business_id = public.current_fahari_business_id())
with check (business_id = public.current_fahari_business_id());

drop policy if exists fahari_business_delete on public.client_charge_transactions;
create policy fahari_business_delete on public.client_charge_transactions for delete to authenticated
using (business_id = public.current_fahari_business_id());

create or replace function public.fahari_client_charge_balance(p_client_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(
    case
      when transaction_type in ('deposit','excess_deposit','adjustment_credit') then amount
      else -amount
    end
  ),0)::numeric(14,2)
  from public.client_charge_transactions
  where business_id = public.current_fahari_business_id()
    and client_id = p_client_id;
$$;

create or replace function public.fahari_deposit_client_charge(
  p_client_id uuid,
  p_amount numeric,
  p_transaction_type text,
  p_charge_type text,
  p_transaction_date date,
  p_reference text default null,
  p_payment_method text default null,
  p_description text default null,
  p_source_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id text := public.current_fahari_business_id();
  v_staff_id uuid;
  v_transaction_id uuid;
  v_balance numeric(14,2);
begin
  if v_business_id is null then
    raise exception 'No active Fahari staff account was found.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Deposit amount must be greater than zero.';
  end if;
  if p_transaction_type not in ('deposit','excess_deposit','adjustment_credit') then
    raise exception 'Invalid wallet deposit transaction type.';
  end if;
  if not exists (
    select 1 from public.loan_clients
    where id = p_client_id and business_id = v_business_id
  ) then
    raise exception 'Client does not belong to this business.';
  end if;

  perform pg_advisory_xact_lock(hashtext(v_business_id || ':' || p_client_id::text));
  select id into v_staff_id from public.loan_staff
  where auth_user_id = auth.uid() and business_id = v_business_id and is_active = true
  limit 1;

  insert into public.client_charge_transactions (
    business_id,client_id,transaction_type,charge_type,amount,transaction_date,
    reference,payment_method,description,source_key,created_by
  ) values (
    v_business_id,p_client_id,p_transaction_type,
    case when p_charge_type in ('processing','registration','excess','other') then p_charge_type else 'other' end,
    round(p_amount,2),coalesce(p_transaction_date,current_date),nullif(trim(p_reference),''),
    nullif(trim(p_payment_method),''),nullif(trim(p_description),''),nullif(trim(p_source_key),''),v_staff_id
  )
  on conflict (business_id, source_key) where source_key is not null do nothing
  returning id into v_transaction_id;

  select public.fahari_client_charge_balance(p_client_id) into v_balance;
  return jsonb_build_object('ok',true,'transaction_id',v_transaction_id,'balance',v_balance,'duplicate',v_transaction_id is null);
end;
$$;

create or replace function public.fahari_consume_client_charges(
  p_client_id uuid,
  p_loan_id uuid,
  p_processing_amount numeric,
  p_registration_amount numeric,
  p_transaction_date date,
  p_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id text := public.current_fahari_business_id();
  v_staff_id uuid;
  v_balance numeric(14,2);
  v_required numeric(14,2) := round(coalesce(p_processing_amount,0) + coalesce(p_registration_amount,0),2);
begin
  if v_business_id is null then
    raise exception 'No active Fahari staff account was found.';
  end if;
  if coalesce(p_processing_amount,0) < 0 or coalesce(p_registration_amount,0) < 0 then
    raise exception 'Fee amounts cannot be negative.';
  end if;
  if not exists (
    select 1 from public.loans
    where id = p_loan_id and client_id = p_client_id and business_id = v_business_id
  ) then
    raise exception 'Loan does not belong to this client and business.';
  end if;

  perform pg_advisory_xact_lock(hashtext(v_business_id || ':' || p_client_id::text));
  select public.fahari_client_charge_balance(p_client_id) into v_balance;

  if v_balance < v_required then
    return jsonb_build_object(
      'ok',false,'balance',v_balance,'required',v_required,
      'shortfall',round(v_required-v_balance,2)
    );
  end if;

  select id into v_staff_id from public.loan_staff
  where auth_user_id = auth.uid() and business_id = v_business_id and is_active = true
  limit 1;

  if coalesce(p_processing_amount,0) > 0 then
    insert into public.client_charge_transactions (
      business_id,client_id,loan_id,transaction_type,charge_type,amount,
      transaction_date,reference,description,source_key,created_by
    ) values (
      v_business_id,p_client_id,p_loan_id,'fee_debit','processing',round(p_processing_amount,2),
      coalesce(p_transaction_date,current_date),nullif(trim(p_reference),''),
      'Processing/application fee used during disbursement','disbursement:'||p_loan_id::text||':processing',v_staff_id
    ) on conflict (business_id, source_key) where source_key is not null do nothing;
  end if;

  if coalesce(p_registration_amount,0) > 0 then
    insert into public.client_charge_transactions (
      business_id,client_id,loan_id,transaction_type,charge_type,amount,
      transaction_date,reference,description,source_key,created_by
    ) values (
      v_business_id,p_client_id,p_loan_id,'fee_debit','registration',round(p_registration_amount,2),
      coalesce(p_transaction_date,current_date),nullif(trim(p_reference),''),
      'One-time registration fee used during first-loan disbursement','disbursement:'||p_loan_id::text||':registration',v_staff_id
    ) on conflict (business_id, source_key) where source_key is not null do nothing;
  end if;

  select public.fahari_client_charge_balance(p_client_id) into v_balance;
  return jsonb_build_object('ok',true,'balance',v_balance,'required',v_required,'shortfall',0);
end;
$$;

revoke all on function public.fahari_client_charge_balance(uuid) from public;
revoke all on function public.fahari_deposit_client_charge(uuid,numeric,text,text,date,text,text,text,text) from public;
revoke all on function public.fahari_consume_client_charges(uuid,uuid,numeric,numeric,date,text) from public;
grant execute on function public.fahari_client_charge_balance(uuid) to authenticated, service_role;
grant execute on function public.fahari_deposit_client_charge(uuid,numeric,text,text,date,text,text,text,text) to authenticated, service_role;
grant execute on function public.fahari_consume_client_charges(uuid,uuid,numeric,numeric,date,text) to authenticated, service_role;

-- Migrate existing excess deposits. Loan numbers identify the client reliably.
insert into public.client_charge_transactions (
  business_id,client_id,loan_id,transaction_type,charge_type,amount,
  transaction_date,reference,payment_method,description,source_key
)
select
  j.business_id,l.client_id,l.id,'excess_deposit','excess',j.amount,j.date,j.ref,j.debit,
  j.description,'legacy-journal:'||j.id::text
from public.journal_entries j
join public.loans l
  on l.business_id = j.business_id
 and (
   lower(j.description) like '%loan '||lower(l.loan_no)||' |%'
   or lower(j.description) like '%loan '||lower(l.loan_no)
 )
where lower(coalesce(j.description,'')) like '%excess repayment%'
on conflict (business_id, source_key) where source_key is not null do nothing;

-- Migrate charge payments manually uploaded against a client. These remain available
-- until a future disbursement consumes them.
insert into public.client_charge_transactions (
  business_id,client_id,transaction_type,charge_type,amount,transaction_date,
  reference,payment_method,description,source_key
)
select
  j.business_id,c.id,'deposit',
  case when lower(coalesce(j.credit,'')) like '%registration%' then 'registration' else 'processing' end,
  j.amount,j.date,j.ref,j.debit,j.description,'legacy-journal:'||j.id::text
from public.journal_entries j
join public.loan_clients c
  on c.business_id = j.business_id
 and (
   lower(j.description) like '%client id: '||lower(c.id::text)||'%'
   or lower(j.description) like '%paid by '||lower(c.full_name)||'%'
 )
where lower(coalesce(j.description,'')) like '%paid by%'
  and lower(coalesce(j.description,'')) not like '%excess repayment%'
on conflict (business_id, source_key) where source_key is not null do nothing;

-- Historic fees created directly during disbursement had no separate wallet deposit.
-- Add an equal opening deposit and fee debit so history is visible without producing
-- a false negative balance.
with historic_fees as (
  select distinct on (j.id)
    j.id journal_id,j.business_id,j.date,j.ref,j.description,j.amount,
    coalesce(l.client_id,c.id) client_id,l.id loan_id,
    case when lower(coalesce(j.credit,'')) like '%registration%' then 'registration' else 'processing' end charge_type
  from public.journal_entries j
  left join public.loans l
    on l.business_id = j.business_id
   and (
     lower(j.description) like '%loan '||lower(l.loan_no)||' |%'
     or lower(j.description) like '%loan '||lower(l.loan_no)
   )
  left join public.loan_clients c
    on c.business_id = j.business_id
   and (
     lower(j.description) like '%client id: '||lower(c.id::text)||'%'
     or lower(j.description) like '%registration fee%'||lower(c.full_name)||'%'
   )
  where (lower(coalesce(j.credit,'')) like '%processing fee income%'
      or lower(coalesce(j.credit,'')) like '%registration fee income%')
    and lower(coalesce(j.description,'')) not like '%paid by%'
    and coalesce(l.client_id,c.id) is not null
)
insert into public.client_charge_transactions (
  business_id,client_id,loan_id,transaction_type,charge_type,amount,
  transaction_date,reference,payment_method,description,source_key
)
select business_id,client_id,loan_id,'deposit',charge_type,amount,date,ref,'legacy',
  'Historic fee payment received before wallet tracking',
  'legacy-fee-deposit:'||journal_id::text
from historic_fees
union all
select business_id,client_id,loan_id,'fee_debit',charge_type,amount,date,ref,null,
  'Historic fee used during disbursement',
  'legacy-fee-debit:'||journal_id::text
from historic_fees
on conflict (business_id, source_key) where source_key is not null do nothing;

select
  count(*) as wallet_transactions,
  coalesce(sum(case when transaction_type in ('deposit','excess_deposit','adjustment_credit') then amount else -amount end),0) as available_balance
from public.client_charge_transactions;


-- ============================================================================
-- SOURCE: fahari-application-guarantor-update.sql
-- ============================================================================
alter table public.loan_applications
  add column if not exists guarantor_name text,
  add column if not exists guarantor_phone text,
  add column if not exists guarantor_relationship text;

create index if not exists loan_applications_guarantor_phone_idx
  on public.loan_applications (business_id, guarantor_phone);


-- ============================================================================
-- SOURCE: fahari-loan-restructure.sql
-- ============================================================================
-- Fahari loan restructuring
-- Run this file once in Supabase SQL Editor before using the Restructure action.

create or replace function public.fahari_restructure_loan(
  p_loan_id uuid,
  p_term_weeks integer,
  p_first_due_date date,
  p_interval_weeks integer,
  p_reason text
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_business_id text := public.current_fahari_business_id();
  v_staff_id uuid;
  v_staff_role text;
  v_loan public.loans%rowtype;
  v_installments integer;
  v_existing_interval_weeks integer := 1;
  v_next_installment integer;
  v_archived_count integer;
  v_maturity_date date;
  v_regular_amount numeric(14,2);
  v_total_due numeric(14,2);
  v_principal_due numeric(14,2);
  v_interest_due numeric(14,2);
  v_penalty_due numeric(14,2);
  v_paid_principal numeric(14,2) := 0;
  v_paid_interest numeric(14,2) := 0;
  v_paid_penalty numeric(14,2) := 0;
  v_repayments_total numeric(14,2) := 0;
  v_allocated_total numeric(14,2) := 0;
  v_unallocated_paid numeric(14,2) := 0;
  v_original_principal_ratio numeric := 1;
  v_remaining_principal numeric(14,2) := 0;
  v_remaining_penalty numeric(14,2) := 0;
  v_new_interest numeric(14,2) := 0;
  v_new_outstanding numeric(14,2) := 0;
  v_weekly_rate numeric := 0;
  v_new_period_rate numeric := 0;
  v_inserted_total numeric(14,2) := 0;
  v_inserted_principal numeric(14,2) := 0;
  v_inserted_interest numeric(14,2) := 0;
  v_inserted_penalty numeric(14,2) := 0;
  v_due_date date;
  i integer;
begin
  if v_business_id is null then
    raise exception 'Your Fahari session is not linked to an active business. Please sign in again.';
  end if;

  select id, role
    into v_staff_id, v_staff_role
  from public.loan_staff
  where auth_user_id = auth.uid()
    and business_id = v_business_id
    and is_active = true
  limit 1;

  if v_staff_id is null or not (
    regexp_split_to_array(lower(coalesce(v_staff_role, '')), '\s*,\s*')
      && array['admin','branch_manager']::text[]
  ) then
    raise exception 'Only an administrator or manager can restructure a loan.';
  end if;

  if p_term_weeks is null or p_term_weeks < 1 or p_term_weeks > 260 then
    raise exception 'The remaining term must be between 1 and 260 weeks.';
  end if;

  if p_interval_weeks is null or p_interval_weeks not in (1, 2) then
    raise exception 'Repayment frequency must be weekly or biweekly.';
  end if;

  if p_first_due_date is null or p_first_due_date < current_date then
    raise exception 'The first restructured repayment date cannot be in the past.';
  end if;

  if length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'Enter a reason for restructuring the loan.';
  end if;

  select *
    into v_loan
  from public.loans
  where id = p_loan_id
    and business_id = v_business_id
  for update;

  if not found then
    raise exception 'Loan not found for this business.';
  end if;

  if v_loan.status <> 'active' or v_loan.outstanding_balance <= 0 then
    raise exception 'Only an active loan with an outstanding balance can be restructured.';
  end if;

  v_installments := ceil(p_term_weeks::numeric / p_interval_weeks)::integer;
  v_maturity_date := p_first_due_date + ((v_installments - 1) * p_interval_weeks * 7);

  select case
    when count(*) >= 2 then greatest(
      1,
      least(2, round((max(due_date) - min(due_date)) / 7.0)::integer)
    )
    else 1
  end
  into v_existing_interval_weeks
  from (
    select due_date
    from public.loan_schedules
    where loan_id = p_loan_id
      and installment_no > coalesce((
        select max(archived.installment_no)
        from public.loan_schedules archived
        where archived.loan_id = p_loan_id
          and archived.status = 'restructured'
      ), 0)
    order by due_date, installment_no
    limit 2
  ) current_schedule_dates;

  v_weekly_rate := case
    when v_existing_interval_weeks > 0 then v_loan.interest_rate / v_existing_interval_weeks
    else v_loan.interest_rate
  end;
  v_new_period_rate := round(v_weekly_rate * p_interval_weeks, 4);

  select
    coalesce(sum(principal_portion), 0),
    coalesce(sum(interest_portion), 0),
    coalesce(sum(penalty_portion), 0),
    coalesce(sum(amount), 0)
  into v_paid_principal, v_paid_interest, v_paid_penalty, v_repayments_total
  from public.loan_repayments
  where loan_id = p_loan_id
    and business_id = v_business_id;

  -- Older imported repayments can have zero allocation columns. Allocate only
  -- their missing portion using the original principal/interest proportions.
  v_allocated_total := v_paid_principal + v_paid_interest + v_paid_penalty;
  v_unallocated_paid := greatest(
    0,
    greatest(v_repayments_total, v_loan.total_paid) - v_allocated_total
  );
  v_original_principal_ratio := case
    when v_loan.total_payable > 0
      then greatest(0, least(1, v_loan.principal_amount / v_loan.total_payable))
    else 1
  end;
  v_paid_principal := least(
    v_loan.principal_amount,
    v_paid_principal + round(v_unallocated_paid * v_original_principal_ratio, 2)
  );
  v_paid_interest := v_paid_interest + greatest(
    0,
    v_unallocated_paid - round(v_unallocated_paid * v_original_principal_ratio, 2)
  );

  v_remaining_principal := greatest(0, v_loan.principal_amount - v_paid_principal);

  select greatest(0, coalesce(sum(penalty_amount), 0) - v_paid_penalty)
  into v_remaining_penalty
  from public.loan_penalties
  where loan_id = p_loan_id
    and business_id = v_business_id
    and is_waived = false;

  -- interest_rate is stored per repayment period: weekly loans use the weekly
  -- rate and biweekly loans use the biweekly rate.
  v_new_interest := round(
    v_remaining_principal * (v_new_period_rate / 100) * v_installments,
    2
  );
  v_new_outstanding := round(
    v_remaining_principal + v_new_interest + v_remaining_penalty,
    2
  );
  if v_new_outstanding <= 0 then
    raise exception 'This loan has no principal, interest or penalty balance to restructure.';
  end if;
  v_regular_amount := round(v_new_outstanding / v_installments, 2);

  select coalesce(max(installment_no), 0) + 1
    into v_next_installment
  from public.loan_schedules
  where loan_id = p_loan_id;

  update public.loan_schedules
  set status = 'restructured', updated_at = now()
  where loan_id = p_loan_id
    and status in ('pending', 'partial', 'overdue');
  get diagnostics v_archived_count = row_count;

  for i in 1..v_installments loop
    v_due_date := p_first_due_date + ((i - 1) * p_interval_weeks * 7);
    if i = v_installments then
      v_principal_due := round(v_remaining_principal - v_inserted_principal, 2);
      v_interest_due := round(v_new_interest - v_inserted_interest, 2);
      v_penalty_due := round(v_remaining_penalty - v_inserted_penalty, 2);
    else
      v_principal_due := round(v_remaining_principal / v_installments, 2);
      v_interest_due := round(v_new_interest / v_installments, 2);
      v_penalty_due := round(v_remaining_penalty / v_installments, 2);
    end if;
    v_total_due := round(v_principal_due + v_interest_due + v_penalty_due, 2);

    insert into public.loan_schedules (
      business_id, loan_id, installment_no, due_date,
      principal_due, interest_due, total_due,
      principal_paid, interest_paid, total_paid,
      penalty_charged, status
    ) values (
      v_business_id, p_loan_id, v_next_installment + i - 1, v_due_date,
      v_principal_due, v_interest_due, v_total_due,
      0, 0, 0,
      v_penalty_due, 'pending'
    );

    v_inserted_total := v_inserted_total + v_total_due;
    v_inserted_principal := v_inserted_principal + v_principal_due;
    v_inserted_interest := v_inserted_interest + v_interest_due;
    v_inserted_penalty := v_inserted_penalty + v_penalty_due;
  end loop;

  update public.loans
  set term_weeks = p_term_weeks,
      first_repayment_date = p_first_due_date,
      maturity_date = v_maturity_date,
      weekly_installment = v_regular_amount,
      interest_rate = v_new_period_rate,
      total_interest = round(v_paid_interest + v_new_interest, 2),
      total_payable = round(v_loan.total_paid + v_new_outstanding, 2),
      outstanding_balance = v_new_outstanding,
      arrears_amount = 0,
      overdue_days = 0,
      updated_at = now()
  where id = p_loan_id
    and business_id = v_business_id;

  insert into public.loan_audit_log (
    business_id, user_id, action, table_name, record_id, old_value, new_value
  ) values (
    v_business_id,
    v_staff_id,
    'loan_restructured',
    'loans',
    p_loan_id::text,
    jsonb_build_object(
      'term_weeks', v_loan.term_weeks,
      'first_repayment_date', v_loan.first_repayment_date,
      'maturity_date', v_loan.maturity_date,
      'weekly_installment', v_loan.weekly_installment,
      'interest_rate_per_period', v_loan.interest_rate,
      'total_interest', v_loan.total_interest,
      'total_payable', v_loan.total_payable,
      'outstanding_balance', v_loan.outstanding_balance,
      'arrears_amount', v_loan.arrears_amount,
      'overdue_days', v_loan.overdue_days
    ),
    jsonb_build_object(
      'term_weeks', p_term_weeks,
      'repayment_interval_weeks', p_interval_weeks,
      'installments', v_installments,
      'first_repayment_date', p_first_due_date,
      'maturity_date', v_maturity_date,
      'installment_amount', v_regular_amount,
      'remaining_principal', v_remaining_principal,
      'recalculated_interest', v_new_interest,
      'interest_rate_per_period', v_new_period_rate,
      'remaining_penalty', v_remaining_penalty,
      'outstanding_balance', v_new_outstanding,
      'total_interest', round(v_paid_interest + v_new_interest, 2),
      'total_payable', round(v_loan.total_paid + v_new_outstanding, 2),
      'reason', trim(p_reason),
      'archived_schedules', v_archived_count
    )
  );

  return jsonb_build_object(
    'ok', true,
    'loan_id', p_loan_id,
    'loan_no', v_loan.loan_no,
    'remaining_principal', v_remaining_principal,
    'recalculated_interest', v_new_interest,
    'interest_rate_per_period', v_new_period_rate,
    'remaining_penalty', v_remaining_penalty,
    'remaining_balance', v_new_outstanding,
    'term_weeks', p_term_weeks,
    'repayment_interval_weeks', p_interval_weeks,
    'installments', v_installments,
    'installment_amount', v_regular_amount,
    'first_due_date', p_first_due_date,
    'maturity_date', v_maturity_date,
    'archived_schedules', v_archived_count
  );
end;
$$;

revoke all on function public.fahari_restructure_loan(uuid, integer, date, integer, text) from public, anon;
grant execute on function public.fahari_restructure_loan(uuid, integer, date, integer, text) to authenticated;

comment on function public.fahari_restructure_loan(uuid, integer, date, integer, text)
is 'Archives the unpaid schedule, preserves prior payments, and recalculates interest from remaining principal using the new term.';


-- ============================================================================
-- SOURCE: fahari-mpesa-transactions-audit.sql
-- ============================================================================
-- Fahari: consolidated M-Pesa transaction audit support.
-- Run once before deploying the updated fahari-payment-callback function.

begin;

alter table public.mpesa_callback_queue
  add column if not exists delivery_count integer not null default 1,
  add column if not exists last_received_at timestamptz,
  add column if not exists processing_status text,
  add column if not exists processing_message text;

update public.mpesa_callback_queue
set
  delivery_count = greatest(1, coalesce(delivery_count, 1)),
  last_received_at = coalesce(last_received_at, created_at),
  processing_status = coalesce(
    nullif(processing_status, ''),
    case
      when unmatched then 'suspense'
      when repayment_id is not null then 'processed_repayment'
      when confirmed then 'processed'
      when loan_id is not null then 'pending_confirmation'
      else 'received'
    end
  );

alter table public.mpesa_callback_queue
  drop constraint if exists mpesa_callback_queue_delivery_count_check;

alter table public.mpesa_callback_queue
  add constraint mpesa_callback_queue_delivery_count_check
  check (delivery_count >= 1);

create index if not exists mpesa_callback_queue_business_created_idx
  on public.mpesa_callback_queue (business_id, created_at desc);

create index if not exists mpesa_callback_queue_business_account_idx
  on public.mpesa_callback_queue (business_id, bill_ref_number);

commit;

select
  count(*) as callback_transactions_prepared,
  count(*) filter (where confirmed) as confirmed,
  count(*) filter (where unmatched) as suspense,
  count(*) filter (where not confirmed and not unmatched) as pending
from public.mpesa_callback_queue;

