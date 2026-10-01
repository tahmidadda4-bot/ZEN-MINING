-- Production hardening for Supabase/PostgreSQL.
-- Run after database/schema.sql.
-- This removes client-side authority over balances/rewards and makes withdrawal/reward writes atomic.

alter table devices add column if not exists last_reward_at timestamptz;
alter table devices add column if not exists monitor_token_hash text;

-- Never allow the public/authenticated roles to write authoritative financial records directly.
drop policy if exists devices_owner_admin on devices;
create policy devices_read_owner_admin on devices for select using(user_id=auth.uid() or is_admin());

drop policy if exists rewards_owner_admin on reward_transactions;
create policy rewards_read_owner_admin on reward_transactions for select using(is_admin() or exists(select 1 from wallets w where w.id=wallet_id and w.user_id=auth.uid()));

drop policy if exists wallets_owner_admin on wallets;
create policy wallets_read_owner_admin on wallets for select using(user_id=auth.uid() or is_admin());

drop policy if exists withdrawals_owner_admin on withdrawals;
create policy withdrawals_read_owner_admin on withdrawals for select using(user_id=auth.uid() or is_admin());

-- Atomic withdrawal reservation. The caller must be the authenticated user.
create or replace function request_withdrawal_secure(p_user_id uuid,p_device_id uuid,p_amount numeric,p_method text,p_destination text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare cfg mining_configs; w wallets; wd withdrawals;
begin
 if auth.uid() is distinct from p_user_id then raise exception 'unauthorized'; end if;
 select * into cfg from public.mining_configs limit 1;
 if cfg.id is null or not cfg.withdrawal_enabled then raise exception 'withdrawal locked'; end if;
 if p_amount < cfg.min_withdrawal or p_amount > cfg.max_withdrawal then raise exception 'amount outside allowed range'; end if;
 if length(trim(coalesce(p_method,'')))=0 or length(trim(coalesce(p_destination,'')))=0 then raise exception 'payment details required'; end if;
 select * into w from public.wallets where user_id=p_user_id for update;
 if w.id is null or w.available_balance < p_amount then raise exception 'insufficient balance'; end if;
 insert into public.withdrawals(user_id,device_id,amount,payment_method,payment_destination)
 values(p_user_id,p_device_id,p_amount,p_method,p_destination) returning * into wd;
 update public.wallets set available_balance=available_balance-p_amount,pending_amount=pending_amount+p_amount,updated_at=clock_timestamp() where id=w.id;
 return jsonb_build_object('id',wd.id,'status','pending');
end $$;

-- Atomic reward accrual. The scheduler calls this through the trusted service-role Edge Function.
create or replace function accrue_device_reward(p_device_id uuid,p_reference text,p_amount numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare d devices; w wallets; existing reward_transactions;
begin
 if p_amount<=0 then raise exception 'invalid reward'; end if;
 select * into d from public.devices where id=p_device_id for update;
 if d.id is null or d.mining_status <> 'active' then raise exception 'device not actively mining'; end if;
 if d.last_seen_at is not null and d.last_seen_at < now()-interval '30 minutes' then raise exception 'device stale'; end if;
 select * into existing from public.reward_transactions where reference=p_reference;
 if existing.id is not null then return jsonb_build_object('duplicate',true,'transaction_id',existing.id); end if;
 select * into w from public.wallets where user_id=d.user_id for update;
 if w.id is null then raise exception 'wallet not found'; end if;
 insert into public.reward_transactions(wallet_id,device_id,type,amount,reference) values(w.id,d.id,'mining',p_amount,p_reference);
 update public.wallets set available_balance=available_balance+p_amount,total_earned=total_earned+p_amount,updated_at=now() where id=w.id;
 update public.devices set last_reward_at=now(),updated_at=now() where id=d.id;
 return jsonb_build_object('duplicate',false,'amount',p_amount);
end $$;

revoke all on function public.request_withdrawal_secure(uuid,uuid,numeric,text,text) from public;
revoke all on function public.accrue_device_reward(uuid,text,numeric) from public,anon,authenticated;
grant execute on function public.request_withdrawal_secure(uuid,uuid,numeric,text,text) to authenticated;
grant execute on function public.accrue_device_reward(uuid,text,numeric) to service_role;

-- Audit indexes.
create index if not exists idx_audit_created on admin_audit_logs(created_at desc);
create index if not exists idx_notifications_user_created on notifications(user_id,created_at desc);

-- Lock admin RPCs to the authenticated admin who is making the call.
create or replace function approve_withdrawal_secure(p_withdrawal_id uuid,p_admin_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare w withdrawals; wall wallets;
begin
 if auth.uid() is distinct from p_admin_id then raise exception 'unauthorized'; end if;
 if not exists(select 1 from public.profiles where id=p_admin_id and role='admin') then raise exception 'admin only'; end if;
 select * into w from public.withdrawals where id=p_withdrawal_id for update;
 if w.id is null or w.status<>'pending' then raise exception 'withdrawal unavailable'; end if;
 select * into wall from public.wallets where user_id=w.user_id for update;
 update public.withdrawals set status='approved',processed_at=clock_timestamp(),processed_by=p_admin_id where id=w.id;
 update public.wallets set pending_amount=greatest(0,pending_amount-w.amount),total_withdrawn=total_withdrawn+w.amount,updated_at=clock_timestamp() where id=wall.id;
 insert into public.admin_audit_logs(admin_id,action,entity_type,entity_id) values(p_admin_id,'approve','withdrawal',w.id);
 return jsonb_build_object('status','approved','withdrawal_id',w.id);
end $$;

create or replace function reject_withdrawal_secure(p_withdrawal_id uuid,p_admin_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare w withdrawals; wall wallets;
begin
 if auth.uid() is distinct from p_admin_id then raise exception 'unauthorized'; end if;
 if not exists(select 1 from public.profiles where id=p_admin_id and role='admin') then raise exception 'admin only'; end if;
 select * into w from public.withdrawals where id=p_withdrawal_id for update;
 if w.id is null or w.status<>'pending' then raise exception 'withdrawal unavailable'; end if;
 select * into wall from public.wallets where user_id=w.user_id for update;
 update public.withdrawals set status='rejected',rejection_reason=p_reason,processed_at=clock_timestamp(),processed_by=p_admin_id where id=w.id;
 update public.wallets set pending_amount=greatest(0,pending_amount-w.amount),available_balance=available_balance+w.amount,updated_at=clock_timestamp() where id=wall.id;
 insert into public.admin_audit_logs(admin_id,action,entity_type,entity_id,metadata) values(p_admin_id,'reject','withdrawal',w.id,jsonb_build_object('reason',p_reason));
 return jsonb_build_object('status','rejected','withdrawal_id',w.id);
end $$;
revoke all on function public.approve_withdrawal_secure(uuid,uuid) from public,anon;
revoke all on function public.reject_withdrawal_secure(uuid,uuid,text) from public,anon;
grant execute on function public.approve_withdrawal_secure(uuid,uuid) to authenticated;
grant execute on function public.reject_withdrawal_secure(uuid,uuid,text) to authenticated;
