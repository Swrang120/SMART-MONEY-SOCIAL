-- Bank details required before Smart Money Social earnings withdrawals.
create table if not exists public.social_user_bank_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  holder_name text not null,
  account_number text not null,
  ifsc_code text not null,
  updated_at timestamptz not null default now(),
  constraint social_bank_holder_len check (char_length(holder_name) between 2 and 100),
  constraint social_bank_account_len check (account_number ~ '^[0-9]{6,20}$'),
  constraint social_bank_ifsc_format check (ifsc_code ~ '^[A-Z]{4}0[A-Z0-9]{6}$')
);
alter table public.social_user_bank_accounts enable row level security;
revoke all on public.social_user_bank_accounts from anon, authenticated;

create or replace function public.social_save_my_bank_details(
  p_holder_name text, p_account_number text, p_ifsc_code text
) returns void
language plpgsql security definer
set search_path = ''
as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Please sign in first'; end if;
  if p_holder_name is null or length(trim(p_holder_name)) < 2 or length(trim(p_holder_name)) > 100 then
    raise exception 'Enter a valid account holder name';
  end if;
  if p_account_number is null or p_account_number !~ '^[0-9]{6,20}$' then
    raise exception 'Enter a valid bank account number';
  end if;
  if p_ifsc_code is null or upper(trim(p_ifsc_code)) !~ '^[A-Z]{4}0[A-Z0-9]{6}$' then
    raise exception 'Enter a valid IFSC code';
  end if;
  insert into public.social_user_bank_accounts(user_id,holder_name,account_number,ifsc_code,updated_at)
  values(v_user,trim(p_holder_name),p_account_number,upper(trim(p_ifsc_code)),now())
  on conflict(user_id) do update set holder_name=excluded.holder_name,
    account_number=excluded.account_number,ifsc_code=excluded.ifsc_code,updated_at=now();
end;
$$;
revoke all on function public.social_save_my_bank_details(text,text,text) from public, anon;
grant execute on function public.social_save_my_bank_details(text,text,text) to authenticated;

drop function if exists public.social_request_earning_withdrawal(numeric,text);
create or replace function public.social_request_earning_withdrawal(p_amount numeric)
returns uuid language plpgsql security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_earned numeric(12,2);
  v_reserved numeric(12,2);
  v_account text;
  v_id uuid;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if p_amount is null or p_amount < 100 or p_amount > 10000 then
    raise exception 'Withdrawal amount must be between ₹100 and ₹10,000';
  end if;
  select account_number into v_account
  from public.social_user_bank_accounts where user_id=v_user;
  if v_account is null then raise exception 'Please add your bank details before withdrawing'; end if;

  select coalesce(sum(amount),0) into v_earned
  from public.earnings where user_id=v_user;
  select coalesce(sum(amount),0) into v_reserved
  from public.social_earning_withdrawals
  where user_id=v_user and status in ('pending','approved','paid');
  if p_amount > greatest(v_earned-v_reserved,0) then
    raise exception 'Insufficient available earnings';
  end if;

  insert into public.social_earning_withdrawals(user_id,amount,bank_last4)
  values(v_user,round(p_amount,2),right(v_account,4)) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.social_request_earning_withdrawal(numeric) from public, anon;
grant execute on function public.social_request_earning_withdrawal(numeric) to authenticated;
