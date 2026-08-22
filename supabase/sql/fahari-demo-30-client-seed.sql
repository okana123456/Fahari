-- Fahari realistic demo portfolio seed
-- Creates 30 demo clients with active six-month loans, historical repayments,
-- future dues, arrears, charges, M-Pesa records, suspense items and audit data.
--
-- Safety rules:
--   1. Targets the most recently registered active administrator's business.
--   2. Refuses to run when that business already has clients.
--   3. Refuses to run more than once.

begin;

drop table if exists _fahari_demo_loans;
drop table if exists _fahari_demo_rows;
drop table if exists _fahari_demo_target;

create temporary table _fahari_demo_target (
  business_id text primary key,
  admin_id uuid not null
);

do $$
declare
  v_business_id text;
  v_admin_id uuid;
  v_client_count integer;
begin
  select s.business_id, s.id
    into v_business_id, v_admin_id
  from public.loan_staff s
  where s.is_active = true
    and lower(s.role) like '%admin%'
  order by s.created_at desc
  limit 1;

  if v_business_id is null then
    raise exception 'No active Fahari administrator was found. Register the demo business first.';
  end if;

  if exists (
    select 1
    from public.loan_audit_log
    where business_id = v_business_id
      and action = 'fahari_demo_seed_completed'
  ) then
    raise exception 'Demo data has already been installed for business %.', v_business_id;
  end if;

  select count(*) into v_client_count
  from public.loan_clients
  where business_id = v_business_id;

  if v_client_count > 0 then
    raise exception 'Business % already has % client(s). This seed only runs on an empty demo business.', v_business_id, v_client_count;
  end if;

  insert into _fahari_demo_target (business_id, admin_id)
  values (v_business_id, v_admin_id);
end $$;

-- Demo team members are visible in Staff and Officer Performance. They do not
-- have login accounts; the registered administrator remains the login owner.
insert into public.loan_staff (
  business_id, name, email, phone, role, is_active, created_at
)
select t.business_id, v.name, v.email, v.phone, v.role, true, now() - interval '6 months'
from _fahari_demo_target t
cross join (values
  ('Grace Wanjiku',  'demo.manager@fahari.invalid',  '0708000101', 'branch_manager'),
  ('Daniel Kiptoo',  'demo.officer1@fahari.invalid', '0708000102', 'loan_officer'),
  ('Mercy Achieng',  'demo.officer2@fahari.invalid', '0708000103', 'loan_officer'),
  ('Samuel Mutua',   'demo.officer3@fahari.invalid', '0708000104', 'loan_officer'),
  ('Faith Njeri',    'demo.cashier@fahari.invalid',  '0708000105', 'cashier')
) as v(name, email, phone, role)
on conflict (business_id, email) do nothing;

-- Build the 30 synthetic clients. Every identity, phone number and email is
-- reserved for demonstration and is visibly tagged in Notes.
with demo_names as (
  select * from (values
    (1, 'Amina Hassan Juma',        'female', 'Mombasa',   'Retail Trader'),
    (2, 'Brian Otieno Ouma',        'male',   'Kisumu',    'Motorcycle Rider'),
    (3, 'Catherine Wambui Njoroge', 'female', 'Nakuru',    'Salon Owner'),
    (4, 'David Mwangi Kamau',       'male',   'Thika',     'Hardware Trader'),
    (5, 'Esther Chebet Rono',       'female', 'Eldoret',   'Cereal Merchant'),
    (6, 'Felix Musyoka Mutiso',     'male',   'Machakos',  'Transporter'),
    (7, 'Gladys Akinyi Onyango',    'female', 'Kisumu',    'Clothes Vendor'),
    (8, 'Hassan Ali Salim',         'male',   'Mombasa',   'Fisheries Trader'),
    (9, 'Irene Njeri Maina',        'female', 'Nairobi',   'Catering Services'),
    (10,'John Kipkemoi Bett',       'male',   'Kericho',   'Tea Farmer'),
    (11,'Kevin Muriithi Kiragu',    'male',   'Nyeri',     'Electronics Shop'),
    (12,'Lucy Atieno Odhiambo',     'female', 'Homabay',   'Grocery Shop'),
    (13,'Martin Njuguna Kariuki',   'male',   'Naivasha',  'Mechanic'),
    (14,'Naomi Jepchirchir Langat', 'female', 'Bomet',     'Dairy Farmer'),
    (15,'Omar Bakari Suleiman',     'male',   'Kilifi',    'General Merchant'),
    (16,'Pauline Wairimu Karanja',  'female', 'Muranga',   'Boutique Owner'),
    (17,'Quinter Auma Were',        'female', 'Kakamega',  'Farm Produce Dealer'),
    (18,'Robert Mutua Kilonzo',     'male',   'Kitui',     'Building Contractor'),
    (19,'Sarah Moraa Nyaboke',      'female', 'Kisii',     'Restaurant Owner'),
    (20,'Thomas Wafula Wekesa',     'male',   'Bungoma',   'Agrovet Dealer'),
    (21,'Ummu Kulthum Noor',        'female', 'Garissa',   'Textile Trader'),
    (22,'Victor Ochieng Okello',    'male',   'Siaya',     'Phone Repair Shop'),
    (23,'Winnie Muthoni Gichuru',   'female', 'Embu',      'Poultry Farmer'),
    (24,'Yusuf Abdalla Mohamed',    'male',   'Mombasa',   'Spare Parts Dealer'),
    (25,'Zainab Fatuma Rashid',     'female', 'Kwale',     'Cosmetics Vendor'),
    (26,'Andrew Kibet Cheruiyot',   'male',   'Nandi',     'Farm Inputs Dealer'),
    (27,'Beatrice Mbithe Nzioka',   'female', 'Makueni',   'Fruit Wholesaler'),
    (28,'Collins Barasa Simiyu',    'male',   'Busia',     'Cyber Cafe Owner'),
    (29,'Diana Nyambura Wambugu',   'female', 'Laikipia',  'Household Goods Shop'),
    (30,'Eric Mwashigadi Mcharo',   'male',   'Voi',       'Tour Van Operator')
  ) as n(i, full_name, gender, address, occupation)
), officers as (
  select array_agg(s.id order by s.email) as ids
  from public.loan_staff s
  join _fahari_demo_target t on t.business_id = s.business_id
  where s.email like 'demo.officer%@fahari.invalid'
)
insert into public.loan_clients (
  business_id, full_name, id_number, phone, alternative_phone, email, gender,
  dob, address, occupation, employer, monthly_income, next_of_kin_name,
  next_of_kin_phone, next_of_kin_relation, notes, status, loan_officer_id,
  created_by, created_at
)
select
  t.business_id,
  n.full_name,
  (90000000 + n.i)::text,
  '0709' || lpad(n.i::text, 6, '0'),
  '0719' || lpad(n.i::text, 6, '0'),
  'demo.client' || lpad(n.i::text, 2, '0') || '@fahari.invalid',
  n.gender,
  (date '1980-01-01' + (n.i * 173))::date,
  n.address,
  n.occupation,
  'Self Employed',
  18000 + (n.i * 1350),
  'Demo Next of Kin ' || lpad(n.i::text, 2, '0'),
  '0729' || lpad(n.i::text, 6, '0'),
  case when n.i % 3 = 0 then 'Sibling' when n.i % 3 = 1 then 'Spouse' else 'Parent' end,
  '[DEMO DATA - NOT A REAL CUSTOMER] [REG_FEE:' ||
    (case
      when n.i % 10 in (1,2,3) then 200
      when n.i % 10 in (4,5,6) then 300
      else 400
    end)::text || ':' || (current_date - interval '5 months')::date::text || ']',
  'active',
  o.ids[((n.i - 1) % 3) + 1],
  t.admin_id,
  now() - interval '6 months' + (n.i || ' days')::interval
from demo_names n
cross join _fahari_demo_target t
cross join officers o;

-- A reusable calculation table keeps the loan, schedule and repayment maths
-- aligned with Fahari's flat-interest product rules.
create temporary table _fahari_demo_rows as
with numbered_clients as (
  select
    c.*,
    row_number() over (order by c.id_number)::integer as i
  from public.loan_clients c
  join _fahari_demo_target t on t.business_id = c.business_id
  where c.notes like '[DEMO DATA%'
), base as (
  select
    c.i,
    c.id as client_id,
    c.business_id,
    c.loan_officer_id,
    case c.i % 10
      when 1 then 5000::numeric
      when 2 then 8000::numeric
      when 3 then 10000::numeric
      when 4 then 11000::numeric
      when 5 then 13000::numeric
      when 6 then 15000::numeric
      when 7 then 16000::numeric
      when 8 then 18000::numeric
      when 9 then 20000::numeric
      else 30000::numeric
    end as principal,
    case
      when c.i % 10 in (1,2,3) then 'INUA BIZ'
      when c.i % 10 in (4,5,6) then 'KUZA'
      when c.i % 10 in (7,8,9) then 'NAWIRI'
      else 'KOMANZA'
    end as product_name,
    case when c.i % 10 = 0 then 2 else 1 end as interval_weeks,
    case when c.i % 10 = 0 then 18::numeric else 20::numeric end as monthly_rate,
    case
      when c.i % 10 in (1,2,3) then 200::numeric
      when c.i % 10 in (4,5,6) then 300::numeric
      else 400::numeric
    end as registration_fee,
    case
      when c.i % 10 in (1,2,3) then 500::numeric
      when c.i % 10 in (4,5,6) then round((case c.i % 10 when 4 then 11000 when 5 then 13000 else 15000 end) * 0.05, 2)
      when c.i % 10 in (7,8,9) then round((case c.i % 10 when 7 then 16000 when 8 then 18000 else 20000 end) * 0.06, 2)
      else 3000::numeric
    end as processing_fee,
    case
      when c.i >= 28 then current_date - ((c.i - 28) * 3)
      else current_date - ((2 + (((c.i - 1) * 5) % 21)) * 7)
    end as disbursement_date
  from numbered_clients c
), calculated as (
  select
    b.*,
    26 as term_weeks,
    ceil(26.0 / b.interval_weeks)::integer as installments,
    (b.monthly_rate / 4 * b.interval_weeks)::numeric as period_rate,
    (b.disbursement_date + (b.interval_weeks * 7))::date as first_repayment_date
  from base b
)
select
  c.*,
  round(c.principal * (c.period_rate / 100) * c.installments, 2) as total_interest,
  round(c.principal + (c.principal * (c.period_rate / 100) * c.installments), 2) as total_payable,
  round(c.principal / c.installments, 2) as base_principal_due,
  round((c.principal * (c.period_rate / 100) * c.installments) / c.installments, 2) as base_interest_due
from calculated c;

insert into public.loan_applications (
  business_id, application_no, client_id, product_id, loan_officer_id,
  applied_amount, applied_term_weeks, purpose, loan_type, guarantor_name,
  guarantor_phone, guarantor_relationship, status, application_date,
  approved_by, approved_at, reviewed_by, reviewed_at, created_at
)
select
  d.business_id,
  'DEMO-APP-' || lpad(d.i::text, 3, '0'),
  d.client_id,
  p.id,
  d.loan_officer_id,
  d.principal,
  d.term_weeks,
  '[DEMO] Working capital and business stock expansion',
  'new_loan',
  'Demo Guarantor ' || lpad(d.i::text, 2, '0'),
  '0739' || lpad(d.i::text, 6, '0'),
  case when d.i % 2 = 0 then 'Sibling' else 'Business Partner' end,
  'disbursed',
  d.disbursement_date - 3,
  t.admin_id,
  (d.disbursement_date - 1)::timestamp + time '09:00',
  t.admin_id,
  (d.disbursement_date - 1)::timestamp + time '09:00',
  (d.disbursement_date - 3)::timestamp + time '10:00'
from _fahari_demo_rows d
join public.loan_products p
  on p.business_id = d.business_id and p.name = d.product_name
cross join _fahari_demo_target t;

insert into public.loans (
  business_id, loan_no, application_id, client_id, loan_officer_id,
  principal_amount, disbursed_amount, interest_rate, interest_type, term_weeks,
  processing_fee, total_interest, total_payable, weekly_installment,
  disbursement_method, disbursement_reference, disbursement_date,
  first_repayment_date, maturity_date, status, outstanding_balance,
  total_paid, arrears_amount, overdue_days, loan_type, created_at
)
select
  d.business_id,
  'DEMO-LN-' || lpad(d.i::text, 3, '0'),
  a.id,
  d.client_id,
  d.loan_officer_id,
  d.principal,
  d.principal,
  d.period_rate,
  'flat',
  d.term_weeks,
  d.processing_fee,
  d.total_interest,
  d.total_payable,
  round(d.total_payable / d.installments, 2),
  case when d.i % 4 = 0 then 'cash' else 'mpesa' end,
  'DEMO-DISB-' || lpad(d.i::text, 3, '0'),
  d.disbursement_date,
  d.first_repayment_date,
  d.first_repayment_date + ((d.installments - 1) * d.interval_weeks * 7),
  'active',
  d.total_payable,
  0,
  0,
  0,
  'new_loan',
  d.disbursement_date::timestamp + time '11:00'
from _fahari_demo_rows d
join public.loan_applications a
  on a.business_id = d.business_id
 and a.application_no = 'DEMO-APP-' || lpad(d.i::text, 3, '0');

create temporary table _fahari_demo_loans as
select
  d.*,
  l.id as loan_id,
  l.loan_no
from _fahari_demo_rows d
join public.loans l
  on l.business_id = d.business_id
 and l.loan_no = 'DEMO-LN-' || lpad(d.i::text, 3, '0');

insert into public.loan_schedules (
  business_id, loan_id, installment_no, due_date, principal_due,
  interest_due, total_due, principal_paid, interest_paid, total_paid,
  penalty_charged, status, created_at
)
select
  d.business_id,
  d.loan_id,
  n.installment_no,
  d.first_repayment_date + ((n.installment_no - 1) * d.interval_weeks * 7),
  case
    when n.installment_no < d.installments then d.base_principal_due
    else round(d.principal - (d.base_principal_due * (d.installments - 1)), 2)
  end,
  case
    when n.installment_no < d.installments then d.base_interest_due
    else round(d.total_interest - (d.base_interest_due * (d.installments - 1)), 2)
  end,
  case
    when n.installment_no < d.installments then d.base_principal_due + d.base_interest_due
    else round(
      (d.principal - (d.base_principal_due * (d.installments - 1))) +
      (d.total_interest - (d.base_interest_due * (d.installments - 1))), 2
    )
  end,
  0, 0, 0, 0, 'pending',
  d.disbursement_date::timestamp + time '11:05'
from _fahari_demo_loans d
cross join lateral generate_series(1, d.installments) as n(installment_no);

-- Payment behaviour cycles through current, advance-paid, one missed,
-- two missed and partially paid portfolios.
with due_info as (
  select
    l.loan_id,
    l.i,
    coalesce(max(s.installment_no) filter (where s.due_date <= current_date), 0) as max_due
  from _fahari_demo_loans l
  join public.loan_schedules s on s.loan_id = l.loan_id
  group by l.loan_id, l.i
), plan as (
  select
    d.*,
    case d.i % 5
      when 0 then d.max_due
      when 1 then d.max_due
      when 2 then greatest(0, d.max_due - 1)
      when 3 then greatest(0, d.max_due - 2)
      else greatest(0, d.max_due - 1)
    end as fully_paid_through
  from due_info d
)
update public.loan_schedules s
set total_paid = case
  when s.installment_no <= p.fully_paid_through then s.total_due
  when p.i % 5 = 4 and s.installment_no = p.max_due and p.max_due > 0
    then round(s.total_due * 0.50, 2)
  when p.i % 10 = 0 and s.installment_no = p.max_due + 1
    then s.total_due
  else 0
end
from plan p
where s.loan_id = p.loan_id;

update public.loan_schedules s
set
  principal_paid = case when s.total_due > 0
    then least(s.principal_due, round(s.total_paid * s.principal_due / s.total_due, 2))
    else 0 end,
  interest_paid = case when s.total_due > 0
    then greatest(0, s.total_paid - least(s.principal_due, round(s.total_paid * s.principal_due / s.total_due, 2)))
    else 0 end,
  status = case
    when s.total_paid >= s.total_due - 0.01 then 'paid'
    when s.total_paid > 0 then 'partial'
    when s.due_date < current_date then 'overdue'
    else 'pending'
  end,
  paid_at = case when s.total_paid > 0
    then least(current_date, s.due_date + ((s.installment_no % 3) - 1))::timestamp + time '10:15'
    else null end;

insert into public.loan_repayments (
  business_id, loan_id, receipt_no, amount, payment_method, payment_reference,
  payment_date, principal_portion, interest_portion, penalty_portion,
  mpesa_confirmed, collected_by, notes, created_at
)
select
  l.business_id,
  s.loan_id,
  'DEMO-RCP-' || lpad(l.i::text, 3, '0') || '-' || lpad(s.installment_no::text, 2, '0'),
  s.total_paid,
  case (l.i + s.installment_no) % 4
    when 0 then 'cash'
    when 1 then 'mpesa_c2b'
    when 2 then 'bank_transfer'
    else 'mpesa'
  end,
  case when (l.i + s.installment_no) % 4 in (1,3)
    then 'DM' || lpad(l.i::text, 3, '0') || lpad(s.installment_no::text, 2, '0') || 'FAH'
    else 'DEMO-PAY-' || lpad(l.i::text, 3, '0') || '-' || lpad(s.installment_no::text, 2, '0')
  end,
  s.paid_at,
  s.principal_paid,
  s.interest_paid,
  0,
  ((l.i + s.installment_no) % 4 = 1),
  case when (l.i + s.installment_no) % 4 = 0 then cashier.id else l.loan_officer_id end,
  '[DEMO DATA] Historical instalment payment',
  s.paid_at
from public.loan_schedules s
join _fahari_demo_loans l on l.loan_id = s.loan_id
left join lateral (
  select st.id
  from public.loan_staff st
  where st.business_id = l.business_id
    and st.email = 'demo.cashier@fahari.invalid'
  limit 1
) cashier on true
where s.total_paid > 0;

-- Synchronize each loan snapshot from its schedules and repayments.
with totals as (
  select
    l.loan_id,
    coalesce(sum(s.total_paid), 0) as total_paid,
    coalesce(sum(greatest(0, s.total_due - s.total_paid))
      filter (where s.due_date < current_date), 0) as arrears_amount,
    min(s.due_date) filter (
      where s.due_date < current_date
        and s.total_due - s.total_paid > 0.01
    ) as oldest_unpaid_date
  from _fahari_demo_loans l
  join public.loan_schedules s on s.loan_id = l.loan_id
  group by l.loan_id
)
update public.loans l
set
  total_paid = round(t.total_paid, 2),
  outstanding_balance = greatest(0, round(l.total_payable - t.total_paid, 2)),
  arrears_amount = round(t.arrears_amount, 2),
  overdue_days = case when t.oldest_unpaid_date is null then 0 else current_date - t.oldest_unpaid_date end,
  status = 'active'
from totals t
where l.id = t.loan_id;

-- Upfront registration and processing/application fees, plus a few unused
-- excess balances so Charges & Excess reports have meaningful examples.
insert into public.client_charge_transactions (
  business_id, client_id, loan_id, transaction_type, charge_type, amount,
  transaction_date, reference, payment_method, description, source_key,
  created_by, created_at
)
select d.business_id, d.client_id, d.loan_id, x.transaction_type, x.charge_type,
       x.amount, d.disbursement_date, x.reference, 'mpesa', x.description,
       x.source_key, t.admin_id, d.disbursement_date::timestamp + x.created_time
from _fahari_demo_loans d
cross join _fahari_demo_target t
cross join lateral (values
  ('deposit',   'registration', d.registration_fee,
   'DEMO-REG-' || lpad(d.i::text,3,'0'),
   '[DEMO DATA] Registration fee deposited',
   'demo-reg-deposit-' || lpad(d.i::text,3,'0'), time '08:30'),
  ('fee_debit', 'registration', d.registration_fee,
   'DEMO-REG-' || lpad(d.i::text,3,'0'),
   '[DEMO DATA] One-time registration fee used',
   'demo-reg-debit-' || lpad(d.i::text,3,'0'), time '09:00'),
  ('deposit',   'processing', d.processing_fee,
   'DEMO-PROC-' || lpad(d.i::text,3,'0'),
   '[DEMO DATA] Processing/application fee deposited',
   'demo-proc-deposit-' || lpad(d.i::text,3,'0'), time '09:15'),
  ('fee_debit', 'processing', d.processing_fee,
   'DEMO-PROC-' || lpad(d.i::text,3,'0'),
   '[DEMO DATA] Processing/application fee used at disbursement',
   'demo-proc-debit-' || lpad(d.i::text,3,'0'), time '10:00')
) as x(transaction_type, charge_type, amount, reference, description, source_key, created_time);

insert into public.client_charge_transactions (
  business_id, client_id, loan_id, transaction_type, charge_type, amount,
  transaction_date, reference, payment_method, description, source_key,
  created_by
)
select
  d.business_id, d.client_id, d.loan_id, 'excess_deposit', 'excess',
  150 + ((d.i % 4) * 100), current_date - (d.i % 12),
  'DEMO-EXCESS-' || lpad(d.i::text,3,'0'), 'mpesa',
  '[DEMO DATA] Unused excess repayment balance',
  'demo-excess-' || lpad(d.i::text,3,'0'), t.admin_id
from _fahari_demo_loans d
cross join _fahari_demo_target t
where d.i % 6 = 0;

insert into public.journal_entries (
  business_id, date, ref, description, debit, credit, amount, synced, created_at
)
select d.business_id, d.disbursement_date,
       'DEMO-REG-' || lpad(d.i::text,3,'0'),
       '[DEMO DATA] Registration fee - client ' || lpad(d.i::text,3,'0'),
       'Charges & Excess Account', 'Registration Fee Income',
       d.registration_fee, false, d.disbursement_date::timestamp + time '09:00'
from _fahari_demo_loans d
union all
select d.business_id, d.disbursement_date,
       'DEMO-PROC-' || lpad(d.i::text,3,'0'),
       '[DEMO DATA] Processing/application fee - loan ' || d.loan_no,
       'Charges & Excess Account', 'Processing Fee Income',
       d.processing_fee, false, d.disbursement_date::timestamp + time '10:00'
from _fahari_demo_loans d;

-- Overdue loans receive realistic collection follow-ups and a small mixture of
-- active and waived penalty records.
insert into public.loan_follow_ups (
  business_id, loan_id, client_id, officer_id, follow_up_type, notes,
  outcome, follow_up_date, next_follow_up_date, created_at
)
select
  l.business_id, l.id, l.client_id, l.loan_officer_id, 'phone_call',
  '[DEMO DATA] Follow-up on missed instalment',
  case when l.overdue_days > 14 then 'Promise to pay' else 'Client contacted' end,
  current_date - 2, current_date + 3, now() - interval '2 days'
from public.loans l
join _fahari_demo_target t on t.business_id = l.business_id
where l.loan_no like 'DEMO-LN-%'
  and l.arrears_amount > 0;

insert into public.loan_penalties (
  business_id, loan_id, penalty_amount, reason, date_charged,
  is_waived, waived_reason, waived_by, waived_at, created_at
)
select
  l.business_id, l.id, 100 + ((d.i % 3) * 50),
  '[DEMO DATA] Late instalment follow-up charge',
  current_date - 5,
  (d.i % 2 = 0),
  case when d.i % 2 = 0 then 'Waived during demo review' else null end,
  case when d.i % 2 = 0 then t.admin_id else null end,
  case when d.i % 2 = 0 then now() - interval '2 days' else null end,
  now() - interval '5 days'
from public.loans l
join _fahari_demo_loans d on d.loan_id = l.id
cross join _fahari_demo_target t
where l.arrears_amount > 0
  and d.i % 3 = 0;

-- Mirror C2B repayments into the M-Pesa transaction audit queue.
insert into public.mpesa_callback_queue (
  business_id, transaction_type, trans_id, trans_time, trans_amount,
  business_short_code, bill_ref_number, msisdn, first_name, raw_payload,
  confirmed, unmatched, loan_id, repayment_id, created_at
)
select
  r.business_id, 'Pay Bill', r.payment_reference,
  to_char(r.payment_date at time zone 'Africa/Nairobi', 'YYYYMMDDHH24MISS'),
  r.amount, 'DEMO-PAYBILL', c.id_number, c.phone,
  split_part(c.full_name, ' ', 1),
  jsonb_build_object('demo', true, 'TransID', r.payment_reference,
    'BillRefNumber', c.id_number, 'TransAmount', r.amount),
  true, false, r.loan_id, r.id, r.created_at
from public.loan_repayments r
join public.loans l on l.id = r.loan_id
join public.loan_clients c on c.id = l.client_id
join _fahari_demo_target t on t.business_id = r.business_id
where l.loan_no like 'DEMO-LN-%'
  and r.payment_method = 'mpesa_c2b';

-- Three deliberately unmatched demo receipts make the Suspense workflow real.
insert into public.unmatched_payments (
  business_id, account_number, amount, payer_phone, payer_name,
  mpesa_reference, payment_date, raw_payload, resolved, created_at
)
select
  t.business_id, v.account_number, v.amount, v.phone, v.payer,
  v.reference, v.payment_date::timestamp + time '14:20',
  jsonb_build_object('demo', true, 'reason', 'Account number not registered'),
  false, v.payment_date::timestamp + time '14:20'
from _fahari_demo_target t
cross join (values
  ('DEMO-UNKNOWN-01', 700::numeric, '254700000901', 'Demo Unmatched One',   'DEMO-SUSP-001', current_date - 12),
  ('DEMO-UNKNOWN-02', 500::numeric, '254700000902', 'Demo Unmatched Two',   'DEMO-SUSP-002', current_date - 5),
  ('DEMO-UNKNOWN-03', 900::numeric, '254700000903', 'Demo Unmatched Three', 'DEMO-SUSP-003', current_date - 1)
) as v(account_number, amount, phone, payer, reference, payment_date);

insert into public.mpesa_callback_queue (
  business_id, transaction_type, trans_id, trans_time, trans_amount,
  business_short_code, bill_ref_number, msisdn, first_name, raw_payload,
  confirmed, unmatched, unmatched_reason, created_at
)
select
  u.business_id, 'Pay Bill', u.mpesa_reference,
  to_char(u.payment_date at time zone 'Africa/Nairobi', 'YYYYMMDDHH24MISS'),
  u.amount, 'DEMO-PAYBILL', u.account_number, u.payer_phone, u.payer_name,
  u.raw_payload, false, true, '[DEMO DATA] No matching client account', u.created_at
from public.unmatched_payments u
join _fahari_demo_target t on t.business_id = u.business_id
where u.mpesa_reference like 'DEMO-SUSP-%';

insert into public.loan_audit_log (
  business_id, user_id, action, table_name, record_id, new_value, created_at
)
select
  l.business_id, t.admin_id, 'demo_loan_disbursed', 'loans', l.id::text,
  jsonb_build_object('demo', true, 'loan_no', l.loan_no,
    'principal', l.principal_amount, 'balance', l.outstanding_balance),
  l.created_at
from public.loans l
cross join _fahari_demo_target t
where l.business_id = t.business_id
  and l.loan_no like 'DEMO-LN-%';

insert into public.loan_audit_log (
  business_id, user_id, action, table_name, record_id, new_value
)
select
  t.business_id, t.admin_id, 'fahari_demo_seed_completed', 'system',
  t.business_id,
  jsonb_build_object(
    'demo', true,
    'clients', 30,
    'generated_on', current_date,
    'notice', 'Synthetic demonstration data only; no real customers or M-Pesa receipts.'
  )
from _fahari_demo_target t;

-- Final result shown in Supabase SQL Editor.
select
  t.business_id,
  (select company_name from public.loan_settings where business_id = t.business_id) as business_name,
  (select count(*) from public.loan_clients where business_id = t.business_id and notes like '[DEMO DATA%') as demo_clients,
  (select count(*) from public.loans where business_id = t.business_id and loan_no like 'DEMO-LN-%') as active_demo_loans,
  (select count(*) from public.loan_repayments where business_id = t.business_id and notes like '[DEMO DATA%') as repayment_records,
  (select round(coalesce(sum(outstanding_balance),0),2) from public.loans where business_id = t.business_id and loan_no like 'DEMO-LN-%') as outstanding_portfolio,
  (select round(coalesce(sum(arrears_amount),0),2) from public.loans where business_id = t.business_id and loan_no like 'DEMO-LN-%') as current_arrears,
  (select count(*) from public.unmatched_payments where business_id = t.business_id and mpesa_reference like 'DEMO-SUSP-%') as suspense_examples
from _fahari_demo_target t;

drop table if exists _fahari_demo_loans;
drop table if exists _fahari_demo_rows;
drop table if exists _fahari_demo_target;

commit;
