create table if not exists nexora.player_account_bans (
  user_id text primary key,
  reason text not null check (char_length(reason) between 3 and 500),
  expires_at timestamptz,
  banned_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists player_account_bans_expires_at_idx on nexora.player_account_bans (expires_at);
alter table nexora.player_account_bans enable row level security;
revoke all on nexora.player_account_bans from public, anon, authenticated;
grant select, insert, update, delete on nexora.player_account_bans to service_role;
create or replace function nexora.admin_adjust_player_wallet(p_user_id text,p_amount bigint,p_operation text,p_reason text default '')
returns jsonb language plpgsql set search_path=nexora,pg_temp as $$
declare v_balance bigint; v_new_balance bigint; v_tx_id text := 'admin-wallet-' || gen_random_uuid()::text; v_description text;
begin
 if p_user_id is null or length(trim(p_user_id))=0 or p_amount is null or p_amount<=0 or p_operation not in ('add','remove') or coalesce(length(trim(p_reason)),0)>500 then raise exception 'INVALID_ADMIN_WALLET_ADJUSTMENT'; end if;
 select balance into v_balance from wallets where user_id=p_user_id for update;
 if not found then raise exception 'PLAYER_WALLET_NOT_FOUND'; end if;
 if p_operation='remove' and v_balance<p_amount then raise exception 'INSUFFICIENT_PLAYER_BALANCE'; end if;
 v_new_balance:=case when p_operation='add' then v_balance+p_amount else v_balance-p_amount end;
 if v_new_balance<0 or v_new_balance>9000000000000000 then raise exception 'PLAYER_BALANCE_OUT_OF_RANGE'; end if;
 update wallets set balance=v_new_balance,last_tx_id=v_tx_id,updated_at=now() where user_id=p_user_id;
 v_description:=case when p_operation='add' then 'إضافة رصيد بواسطة إدارة اللعبة' else 'خصم رصيد بواسطة إدارة اللعبة' end;
 if coalesce(trim(p_reason),'')<>'' then v_description:=v_description || ' — ' || trim(p_reason); end if;
 insert into transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status,created_at)
 values(v_tx_id,case when p_operation='remove' then p_user_id else null end,case when p_operation='add' then p_user_id else null end,p_amount,0,p_amount,'admin_adjustment',v_tx_id,v_description,'completed',now());
 return jsonb_build_object('balance',v_new_balance,'transaction_id',v_tx_id);
end; $$;
revoke all on function nexora.admin_adjust_player_wallet(text,bigint,text,text) from public,anon,authenticated;
grant execute on function nexora.admin_adjust_player_wallet(text,bigint,text,text) to service_role;