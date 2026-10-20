create table programs(
 id serial primary key, name text unique not null,
 max_gwa numeric(3,2) not null, min_units int not null,
 max_failed int not null, max_incomplete int not null, max_dropped int not null,
 deadline timestamptz not null);
insert into programs(name,max_gwa,min_units,max_failed,max_incomplete,max_dropped,deadline) values
('Merit Scholar',1.75,18,0,0,0,'2026-10-30 17:00:00+08'),
('Community Scholar',2.25,15,0,0,1,'2026-10-30 17:00:00+08');
create table profiles(
 id uuid primary key default gen_random_uuid(),
 auth_user_id uuid unique references auth.users(id),
 student_id text unique, full_name text not null,
 role text not null check (role in ('scholar','staff')));
create table scholar_assignments(
 id uuid primary key default gen_random_uuid(),
 scholar_id uuid not null unique references profiles(id),
 program_id int not null references programs(id),
 assigned_at timestamptz default now());
create table submissions(
 id uuid primary key default gen_random_uuid(),
 scholar_id uuid not null references profiles(id),
 academic_year text not null,
 semester int not null check (semester in (1,2)),
 gwa numeric(3,2) not null check (gwa between 1.00 and 5.00),
 units int not null check (units>=0),
 failed_count int not null check (failed_count>=0),
 incomplete_count int not null check (incomplete_count>=0),
 dropped_count int not null check (dropped_count>=0),
 evidence_ref text not null check (length(trim(evidence_ref))>0),
 submitted_at timestamptz not null default now(),
 verification_status text not null default 'Pending' check (verification_status in ('Pending','Verified','Returned')),
 verification_reason text,
 compliance_result text not null default 'Not Evaluated' check (compliance_result in ('Not Evaluated','Compliant','With Deficiency')),
 deficiency_reasons text[] not null default '{}',
 renewal_decision text not null default 'None' check (renewal_decision in ('None','Approved','Held')),
 decision_note text,
 unique(scholar_id,academic_year,semester));
create table audit_log(
 id bigserial primary key,
 submission_id uuid references submissions(id),
 actor_id uuid references profiles(id),
 action text, old_value text, new_value text, note text,
 created_at timestamptz default now());
