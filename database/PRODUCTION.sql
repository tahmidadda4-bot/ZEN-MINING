-- ZEN MINING PRODUCTION DATABASE
-- Supabase / PostgreSQL. Run once in Supabase SQL Editor.
-- Never expose the service-role key to the Flutter app or Admin web.

create extension if not exists pgcrypto;

do $$ begin create type device_status as enum ('online','offline','uninstalled'); exception when duplicate_object then null; end $$;
do $$ begin create type mining_status as enum ('active','inactive','paused'); exception when duplicate_object then null; end $$;
do $$ begin create type withdrawal_status as enum ('pending','approved','rejected','cancelled'); exception when duplicate_object then null; end $$;

create table if not exists profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 role text not null default 'user' check(role in('user','admin')),
 display_name text, created_at timestamptz default now(), updated_at timestamptz default now()
);

create table if not exists devices(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references profiles(id) on delete cascade,
 device_name text not null, model text, android_version text, app_version text,
 device_fingerprint text unique,
 status device_status default 'offline',
 mining_status mining_status default 'inactive',
 last_seen_at timestamptz,
 monitoring_last_sync_at timestamptz,
 mining_started_at timestamptz,
 mining_ends_at timestamptz,
 last_reward_at timestamptz,
 mining_rate numeric(18,8) not null default 5,
 monitor_token_hash text,
 created_at timestamptz default now(), updated_at timestamptz default now()
);

alter table devices add column if not exists monitoring_last_sync_at timestamptz;
alter table devices add column if not exists mining_ends_at timestamptz;
alter table devices add column if not exists last_reward_at timestamptz;
alter table devices add column if not exists monitor_token_hash text;

create unique index if not exists idx_devices_monitor_hash on devices(monitor_token_hash) where monitor_token_hash is not null;

create table if not exists device_activities(
 id uuid primary key default gen_random_uuid(),
 device_id uuid not null references devices(id) on delete cascade,
 session_key text not null,
 package_name text not null,
 app_name text not null,
 started_at timestamptz not null,
 ended_at timestamptz,
 duration_seconds integer,
 created_at timestamptz default now(),
 updated_at timestamptz default now(),
 unique(device_id, session_key)
);
alter table device_activities add column if not exists session_key text;
alter table device_activities add column if not exists updated_at timestamptz default now();
create unique index if not exists idx_activity_session on device_activities(device_id,session_key);

create table if not exists wallets(
 id uuid primary key default gen_random_uuid(),
 user_id uuid unique not null references profiles(id) on delete cascade,
 available_balance numeric(18,8) not null default 0,
 total_earned numeric(18,8) not null default 0,
 total_withdrawn numeric(18,8) not null default 0,
 pending_amount numeric(18,8) not null default 0,
 updated_at timestamptz default now()
);

create table if not exists reward_transactions(
 id uuid primary key default gen_random_uuid(),
 wallet_id uuid not null references wallets(id) on delete cascade,
 device_id uuid references devices(id) on delete set null,
 type text not null check(type in ('mining','adjustment','withdrawal_reversal')),
 amount numeric(18,8) not null,
 reference text unique,
 created_at timestamptz default now()
);

create table if not exists mining_configs(
 id uuid primary key default gen_random_uuid(),
 global_enabled boolean default true,
 global_rate numeric(18,8) not null default 5,
 min_withdrawal numeric(18,8) not null default 100,
 max_withdrawal numeric(18,8) not null default 10000,
 withdrawal_enabled boolean default false,
 maintenance_mode boolean default false,
 updated_at timestamptz default now()
);

create table if not exists withdrawals(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references profiles(id),
 device_id uuid references devices(id) on delete set null,
 amount numeric(18,8) not null check(amount>0),
 payment_method text not null,
 payment_destination text not null,
 status withdrawal_status default 'pending',
 rejection_reason text,
 requested_at timestamptz default now(),
 processed_at timestamptz,
 processed_by uuid references profiles(id)
);

create table if not exists notifications(
 id uuid primary key default gen_random_uuid(),
 user_id uuid references profiles(id) on delete cascade,
 event_type text not null, title text not null, body text,
 read_at timestamptz, created_at timestamptz default now()
);

create table if not exists admin_audit_logs(
 id uuid primary key default gen_random_uuid(),
 admin_id uuid references profiles(id) on delete set null,
 action text not null, entity_type text, entity_id uuid,
 metadata jsonb default '{}', created_at timestamptz default now()
);

create index if not exists idx_devices_user on devices(user_id);
create index if not exists idx_activity_device_started on device_activities(device_id,started_at desc);
create index if not exists idx_rewards_wallet_created on reward_transactions(wallet_id,created_at desc);
create index if not exists idx_withdrawals_status on withdrawals(status,requested_at desc);
create index if not exists idx_devices_mining on devices(mining_status,mining_ends_at);
create index if not exists idx_activity_package on device_activities(device_id,package_name,started_at desc);

create or replace function is_admin() returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;

-- User profile + wallet after signup.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 insert into profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'name',new.email))
 on conflict(id) do nothing;
 insert into wallets(user_id) values(new.id) on conflict(user_id) do nothing;
 return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure handle_new_user();

-- Start exactly one 24-hour mining cycle. User must explicitly start it.
create or replace function start_mining_secure(p_device_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare d devices; c mining_configs; now_ts timestamptz:=now(); end_ts timestamptz;
begin
 select * into d from devices where id=p_device_id and user_id=auth.uid() for update;
 if d.id is null then raise exception 'Device not found'; end if;
 select * into c from mining_configs order by created_at asc limit 1;
 if coalesce(c.global_enabled,false)=false then raise exception 'Mining is disabled'; end if;
 if d.mining_status='active' and d.mining_ends_at>now_ts then
   return jsonb_build_object('status','active','ends_at',d.mining_ends_at,'rate',d.mining_rate);
 end if;
 end_ts:=now_ts+interval '24 hours';
 update devices set mining_status='active',mining_started_at=now_ts,mining_ends_at=end_ts,
   last_reward_at=now_ts,mining_rate=coalesce(d.mining_rate,c.global_rate),
   updated_at=now_ts where id=d.id;
 return jsonb_build_object('status','active','started_at',now_ts,'ends_at',end_ts,'rate',coalesce(d.mining_rate,c.global_rate));
end $$;

-- Server-authoritative reward accrual. Amount is proportional to active time
-- within the current 24-hour cycle. It also automatically ends the cycle.
create or replace function accrue_device_reward(p_device_id uuid,p_reference text,p_amount numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare d devices; w wallets; now_ts timestamptz:=now(); until_ts timestamptz; delta numeric:=greatest(0,p_amount);
begin
 select * into d from devices where id=p_device_id for update;
 if d.id is null then raise exception 'Device not found'; end if;
 if d.mining_status<>'active' or d.mining_started_at is null or d.mining_ends_at is null then
   return jsonb_build_object('status','inactive');
 end if;
 if now_ts>=d.mining_ends_at then
   update devices set mining_status='inactive',updated_at=now_ts where id=d.id;
   return jsonb_build_object('status','completed','ends_at',d.mining_ends_at);
 end if;
 until_ts:=least(now_ts,d.mining_ends_at);
 if d.last_reward_at is null or until_ts<=d.last_reward_at then
   return jsonb_build_object('status','no_accrual');
 end if;
 select * into w from wallets where user_id=d.user_id for update;
 if w.id is null then raise exception 'Wallet not found'; end if;
 delta:=greatest(0,least(delta,d.mining_rate * extract(epoch from (until_ts-d.last_reward_at))/86400.0));
 if delta=0 then return jsonb_build_object('status','no_accrual'); end if;
 insert into reward_transactions(wallet_id,device_id,type,amount,reference)
 values(w.id,d.id,'mining',delta,p_reference)
 on conflict(reference) do nothing;
 if found then
   update wallets set available_balance=available_balance+delta,total_earned=total_earned+delta,updated_at=now_ts where id=w.id;
 end if;
 update devices set last_reward_at=until_ts,
   mining_status=case when until_ts>=d.mining_ends_at then 'inactive' else 'active' end,
   updated_at=now_ts where id=d.id;
 return jsonb_build_object('status','accrued','amount',delta,'mining_ends_at',d.mining_ends_at);
end $$;

create or replace function request_withdrawal_secure(
 p_user_id uuid,p_device_id uuid,p_amount numeric,p_method text,p_destination text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare w wallets; c mining_configs; new_id uuid;
begin
 if auth.uid()<>p_user_id then raise exception 'Unauthorized'; end if;
 if p_amount<=0 then raise exception 'Invalid amount'; end if;
 select * into c from mining_configs order by created_at asc limit 1;
 if not coalesce(c.withdrawal_enabled,false) then raise exception 'Withdrawal is locked'; end if;
 if p_amount<c.min_withdrawal or p_amount>c.max_withdrawal then raise exception 'Amount outside withdrawal limits'; end if;
 select * into w from wallets where user_id=p_user_id for update;
 if w.id is null or w.available_balance<p_amount then raise exception 'Insufficient balance'; end if;
 update wallets set available_balance=available_balance-p_amount,pending_amount=pending_amount+p_amount,updated_at=now() where id=w.id;
 insert into withdrawals(user_id,device_id,amount,payment_method,payment_destination)
 values(p_user_id,p_device_id,p_amount,left(p_method,50),left(p_destination,255))
 returning id into new_id;
 return jsonb_build_object('withdrawal_id',new_id,'status','pending');
end $$;

create or replace function approve_withdrawal_secure(p_withdrawal_id uuid,p_admin_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare w withdrawals; wall wallets;
begin
 if not exists(select 1 from profiles where id=p_admin_id and role='admin') then raise exception 'admin only'; end if;
 select * into w from withdrawals where id=p_withdrawal_id for update;
 if w.id is null or w.status<>'pending' then raise exception 'Withdrawal not pending'; end if;
 select * into wall from wallets where user_id=w.user_id for update;
 update withdrawals set status='approved',processed_at=now(),processed_by=p_admin_id where id=w.id;
 update wallets set pending_amount=greatest(0,pending_amount-w.amount),total_withdrawn=total_withdrawn+w.amount,updated_at=now() where id=wall.id;
 insert into admin_audit_logs(admin_id,action,entity_type,entity_id) values(p_admin_id,'approve','withdrawal',w.id);
 return jsonb_build_object('status','approved','withdrawal_id',w.id);
end $$;

create or replace function reject_withdrawal_secure(p_withdrawal_id uuid,p_admin_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare w withdrawals; wall wallets;
begin
 if not exists(select 1 from profiles where id=p_admin_id and role='admin') then raise exception 'admin only'; end if;
 select * into w from withdrawals where id=p_withdrawal_id for update;
 if w.id is null or w.status<>'pending' then raise exception 'Withdrawal not pending'; end if;
 select * into wall from wallets where user_id=w.user_id for update;
 update withdrawals set status='rejected',rejection_reason=left(p_reason,500),processed_at=now(),processed_by=p_admin_id where id=w.id;
 update wallets set pending_amount=greatest(0,pending_amount-w.amount),available_balance=available_balance+w.amount,updated_at=now() where id=wall.id;
 insert into admin_audit_logs(admin_id,action,entity_type,entity_id,metadata)
 values(p_admin_id,'reject','withdrawal',w.id,jsonb_build_object('reason',left(p_reason,500)));
 return jsonb_build_object('status','rejected','withdrawal_id',w.id);
end $$;

-- RLS
alter table profiles enable row level security;
alter table devices enable row level security;
alter table device_activities enable row level security;
alter table wallets enable row level security;
alter table reward_transactions enable row level security;
alter table mining_configs enable row level security;
alter table withdrawals enable row level security;
alter table notifications enable row level security;
alter table admin_audit_logs enable row level security;

drop policy if exists profiles_read on profiles;
create policy profiles_read on profiles for select using(id=auth.uid() or is_admin());
drop policy if exists devices_owner_read on devices;
create policy devices_owner_read on devices for select using(user_id=auth.uid() or is_admin());
drop policy if exists activities_owner_read on device_activities;
create policy activities_owner_read on device_activities for select using(is_admin() or exists(select 1 from devices d where d.id=device_id and d.user_id=auth.uid()));
drop policy if exists wallets_owner_read on wallets;
create policy wallets_owner_read on wallets for select using(user_id=auth.uid() or is_admin());
drop policy if exists rewards_owner_read on reward_transactions;
create policy rewards_owner_read on reward_transactions for select using(is_admin() or exists(select 1 from wallets w where w.id=wallet_id and w.user_id=auth.uid()));
drop policy if exists config_read on mining_configs;
create policy config_read on mining_configs for select using(auth.uid() is not null);
drop policy if exists withdrawals_owner_read on withdrawals;
create policy withdrawals_owner_read on withdrawals for select using(user_id=auth.uid() or is_admin());
drop policy if exists notifications_owner_read on notifications;
create policy notifications_owner_read on notifications for select using(user_id=auth.uid() or is_admin());

insert into mining_configs(global_enabled,global_rate,min_withdrawal,max_withdrawal,withdrawal_enabled)
select true,5,100,10000,false
where not exists(select 1 from mining_configs);
