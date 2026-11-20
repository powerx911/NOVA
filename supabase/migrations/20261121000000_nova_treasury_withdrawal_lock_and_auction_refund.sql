-- NOVA hardening: permanently disable organization treasury withdrawals and
-- refund a reserved auction escrow before cancelling an auction whose asset vanished.
-- This migration is safe to replay: function replacement and guarded source patches
-- do not mutate existing player balances or historical transactions.

create or replace function nexora.withdraw_org_treasury(
  p_uid text,
  p_org_id text,
  p_amount bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
begin
  -- The treasury is a one-way organization fund. No role may withdraw,
  -- transfer, or route its balance back into a personal wallet.
  raise exception 'ORG_TREASURY_WITHDRAWALS_DISABLED';
end;
$function$;

do $patch$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('nexora.settle_company_auction(text)'::regprocedure)
    into v_definition;

  v_old := $old$
  select * into v_company from nexora.companies where id=v_auction.company_id for update;
  if not found then
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    return jsonb_build_object('settled',true,'status','cancelled');
  end if;
$old$;

  v_new := $new$
  select * into v_company from nexora.companies where id=v_auction.company_id for update;
  if not found then
    if v_auction.highest_bidder_uid is not null then
      perform 1 from nexora.wallets where user_id=v_auction.highest_bidder_uid for update;
      if not found then raise exception 'AUCTION_REFUND_WALLET_MISSING'; end if;
      select * into v_escrow from nexora.company_auction_escrows
        where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid and status='reserved'
        for update;
      if found then
        update nexora.wallets
        set balance=balance+v_escrow.amount,
            total_spent=greatest(0,total_spent-v_escrow.amount),
            updated_at=now()
        where user_id=v_auction.highest_bidder_uid;
        update nexora.company_auction_escrows
        set status='refunded',updated_at=now()
        where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
        v_tx:='tx_'||gen_random_uuid()::text;
        insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
        values(v_tx,'SYSTEM',v_auction.highest_bidder_uid,v_escrow.amount,0,v_escrow.amount,
          'company_auction_refund',p_auction_id,'Refund because the auction company no longer exists','completed');
      end if;
    end if;
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    return jsonb_build_object('settled',true,'status','cancelled','reason','AUCTION_ASSET_MISSING');
  end if;
$new$;

  if position(v_old in v_definition)=0 then
    raise exception 'COMPANY_AUCTION_MISSING_ASSET_PATCH_ANCHOR_NOT_FOUND';
  end if;
  v_definition:=replace(v_definition,v_old,v_new);
  if position('AUCTION_ASSET_MISSING' in v_definition)=0
     or position('company_auction_refund' in v_definition)=0 then
    raise exception 'COMPANY_AUCTION_MISSING_ASSET_PATCH_VALIDATION_FAILED';
  end if;
  execute v_definition;
end
$patch$;

do $patch$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('nexora.settle_factory_auction(text)'::regprocedure)
    into v_definition;

  v_old := $old$
  select * into v_f from nexora.factories where id=v_a.factory_id for update;
  if not found then
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    return jsonb_build_object('settled',true,'status','cancelled');
  end if;
$old$;

  v_new := $new$
  select * into v_f from nexora.factories where id=v_a.factory_id for update;
  if not found then
    if v_a.highest_bidder_uid is not null then
      perform 1 from nexora.wallets where user_id=v_a.highest_bidder_uid for update;
      if not found then raise exception 'AUCTION_REFUND_WALLET_MISSING'; end if;
      select * into v_e from nexora.company_auction_escrows
        where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid and status='reserved'
        for update;
      if found then
        update nexora.wallets
        set balance=balance+v_e.amount,
            total_spent=greatest(0,total_spent-v_e.amount),
            updated_at=now()
        where user_id=v_a.highest_bidder_uid;
        update nexora.company_auction_escrows
        set status='refunded',updated_at=now()
        where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
        v_tx:='tx_'||gen_random_uuid()::text;
        insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
        values(v_tx,'SYSTEM',v_a.highest_bidder_uid,v_e.amount,0,v_e.amount,
          'factory_auction_refund',p_auction_id,'Refund because the auction factory no longer exists','completed');
      end if;
    end if;
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    return jsonb_build_object('settled',true,'status','cancelled','reason','AUCTION_ASSET_MISSING');
  end if;
$new$;

  if position(v_old in v_definition)=0 then
    raise exception 'FACTORY_AUCTION_MISSING_ASSET_PATCH_ANCHOR_NOT_FOUND';
  end if;
  v_definition:=replace(v_definition,v_old,v_new);
  if position('AUCTION_ASSET_MISSING' in v_definition)=0
     or position('factory_auction_refund' in v_definition)=0 then
    raise exception 'FACTORY_AUCTION_MISSING_ASSET_PATCH_VALIDATION_FAILED';
  end if;
  execute v_definition;
end
$patch$;

revoke all on function nexora.withdraw_org_treasury(text,text,bigint) from public,anon,authenticated;
grant execute on function nexora.withdraw_org_treasury(text,text,bigint) to service_role;
