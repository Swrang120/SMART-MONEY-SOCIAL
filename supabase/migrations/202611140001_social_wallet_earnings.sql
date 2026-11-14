-- Smart Money Social wallet foundation
-- Keep the existing Smart Money earnings ledger shape consistent across installs.
create table if not exists public.earnings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(12,2) not null check (amount >= 0),
  earning_type text not null default 'reward',
  created_at timestamptz not null default now()
);
alter table public.earnings enable row level security;
drop policy if exists "Users can read own earnings" on public.earnings;
create policy "Users can read own earnings" on public.earnings for select to authenticated using (user_id = auth.uid());

-- Apply this migration to the Supabase project actually used by index.html.
create table if not exists public.social_coin_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null check (amount <> 0),
  entry_type text not null check (entry_type in ('topup','reward','spend','adjustment')),
  note text not null default '',
  reference_id text,
  created_at timestamptz not null default now()
);
create index if not exists social_coin_ledger_user_created_idx on public.social_coin_ledger(user_id, created_at desc);
alter table public.social_coin_ledger enable row level security;
drop policy if exists "Users can read own coin ledger" on public.social_coin_ledger;
create policy "Users can read own coin ledger" on public.social_coin_ledger for select to authenticated using (user_id = auth.uid());

create table if not exists public.social_coin_topup_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  coins integer not null check (coins in (100,500,1000,5000)),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  payment_reference text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id)
);
create index if not exists social_coin_topup_user_created_idx on public.social_coin_topup_requests(user_id, created_at desc);
alter table public.social_coin_topup_requests enable row level security;
drop policy if exists "Users can create own coin topup requests" on public.social_coin_topup_requests;
create policy "Users can create own coin topup requests" on public.social_coin_topup_requests for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users can read own coin topup requests" on public.social_coin_topup_requests;
create policy "Users can read own coin topup requests" on public.social_coin_topup_requests for select to authenticated using (user_id = auth.uid());

create table if not exists public.social_earning_withdrawals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  bank_last4 text not null check (bank_last4 ~ '^[0-9]{4}$'),
  status text not null default 'pending' check (status in ('pending','approved','paid','rejected')),
  admin_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id)
);
create index if not exists social_earning_withdrawals_user_created_idx on public.social_earning_withdrawals(user_id, created_at desc);
alter table public.social_earning_withdrawals enable row level security;
drop policy if exists "Users can read own earning withdrawals" on public.social_earning_withdrawals;
create policy "Users can read own earning withdrawals" on public.social_earning_withdrawals for select to authenticated using (user_id = auth.uid());

create or replace function public.social_get_my_coin_wallet()
returns bigint language sql stable security invoker
set search_path = public
as $$
  select coalesce(sum(amount),0)::bigint
  from public.social_coin_ledger
  where user_id = auth.uid();
$$;
grant execute on function public.social_get_my_coin_wallet() to authenticated;

create or replace function public.social_request_earning_withdrawal(p_amount numeric, p_bank_last4 text)
returns uuid language plpgsql security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_earned numeric(12,2);
  v_reserved numeric(12,2);
  v_account text;
  v_id uuid;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if p_amount is null or p_amount <= 0 or p_amount > 100000 then raise exception 'Invalid withdrawal amount'; end if;
  if p_bank_last4 is null or p_bank_last4 !~ '^[0-9]{4}$' then raise exception 'Enter the last four bank digits'; end if;

  select coalesce(nullif(account_number,''), nullif(bank_account_number,'')) into v_account
  from public.profiles where user_id = v_user and coalesce(is_deleted,false) = false;
  if v_account is null or right(regexp_replace(v_account,'[^0-9]','','g'),4) <> p_bank_last4 then
    raise exception 'Saved bank account does not match. Update your bank details first.';
  end if;

  select coalesce(sum(amount),0) into v_earned from public.earnings where user_id = v_user;
  select coalesce(sum(amount),0) into v_reserved from public.social_earning_withdrawals
    where user_id = v_user and status in ('pending','approved','paid');
  if p_amount > greatest(v_earned-v_reserved,0) then raise exception 'Insufficient available earnings'; end if;

  insert into public.social_earning_withdrawals(user_id,amount,bank_last4)
  values(v_user,round(p_amount,2),p_bank_last4) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.social_request_earning_withdrawal(numeric,text) from public;
grant execute on function public.social_request_earning_withdrawal(numeric,text) to authenticated;

-- Only trusted server/service-role code should call this after verifying a successful payment.
create or replace function public.social_admin_credit_coin_topup(p_request_id uuid, p_payment_reference text)
returns void language plpgsql security definer
set search_path = public
as $$
declare v_req public.social_coin_topup_requests%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception 'Service role required'; end if;
  select * into v_req from public.social_coin_topup_requests where id=p_request_id for update;
  if not found then raise exception 'Top-up request not found'; end if;
  if v_req.status='approved' then return; end if;
  if v_req.status<>'pending' then raise exception 'Request is not pending'; end if;
  update public.social_coin_topup_requests set status='approved',payment_reference=p_payment_reference,reviewed_at=now()
    where id=p_request_id;
  insert into public.social_coin_ledger(user_id,amount,entry_type,note,reference_id)
    values(v_req.user_id,v_req.coins,'topup','Verified S-Coin top-up',p_request_id::text);
end;
$$;
revoke all on function public.social_admin_credit_coin_topup(uuid,text) from public, authenticated;
grant execute on function public.social_admin_credit_coin_topup(uuid,text) to service_role;
