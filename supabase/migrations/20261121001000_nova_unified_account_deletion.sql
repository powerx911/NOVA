-- NOVA account deletion: one transactional Supabase cleanup, followed by Firebase Auth deletion
-- in the authenticated Edge Function. Immutable financial/legal records are retained
-- and narrowly pseudonymized; gameplay state and personal profile data are removed.

alter table nexora.organizations
  add column if not exists is_archived boolean not null default false;

alter table nexora.factories
  add column if not exists is_deleted boolean not null default false;

create or replace function nexora.reject_immutable_mutation()
returns trigger
language plpgsql
set search_path = 'pg_catalog', 'nexora'
as $function$
declare
  v_uid text;
  v_pseudonym text;
begin
  if current_setting('nexora.account_deletion', true) = 'on' then
    v_uid := current_setting('nexora.account_deletion_uid', true);
    v_pseudonym := 'deleted:' || md5(coalesce(v_uid, ''));

    if tg_op = 'DELETE'
       and tg_table_schema = 'nexora'
       and tg_table_name = any(array['player_achievements','player_missions','contract_claims','daily_claims']) then
      return old;
    end if;

    if tg_op = 'UPDATE' and tg_table_schema = 'nexora' then
      if tg_table_name = 'transactions'
         and (to_jsonb(new) - 'from_uid' - 'to_uid' - 'description')
             = (to_jsonb(old) - 'from_uid' - 'to_uid' - 'description')
         and ((old.from_uid = v_uid and new.from_uid is null)
              or (old.from_uid is distinct from v_uid and new.from_uid is not distinct from old.from_uid))
         and ((old.to_uid = v_uid and new.to_uid is null)
              or (old.to_uid is distinct from v_uid and new.to_uid is not distinct from old.to_uid))
         and new.description = 'Historical transaction (anonymized)' then
        return new;
      end if;

      if tg_table_name = 'audit_logs'
         and old.user_id = v_uid
         and new.user_id is null
         and new.details = jsonb_build_object('redacted', 'account_deleted')
         and (to_jsonb(new) - 'user_id' - 'details') = (to_jsonb(old) - 'user_id' - 'details') then
        return new;
      end if;

      if tg_table_name = 'company_logs'
         and old.owner_uid = v_uid
         and new.owner_uid = v_pseudonym
         and (to_jsonb(new) - 'owner_uid') = (to_jsonb(old) - 'owner_uid') then
        return new;
      end if;

      if tg_table_name = 'organization_transactions'
         and old.user_id = v_uid
         and new.user_id = v_pseudonym
         and new.username = 'Deleted Player'
         and new.note = 'Historical organization transaction (anonymized)'
         and (to_jsonb(new) - 'user_id' - 'username' - 'note')
             = (to_jsonb(old) - 'user_id' - 'username' - 'note') then
        return new;
      end if;
    end if;
  end if;

  raise exception 'NEXORA immutable records cannot be updated or deleted';
end;
$function$;

create or replace function nexora.delete_player_account(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_pseudonym text;
  v_org record;
  v_auction nexora.company_auctions%rowtype;
  v_escrow nexora.company_auction_escrows%rowtype;
  v_tx text;
  v_refunds integer := 0;
  v_archived_companies integer := 0;
  v_archived_factories integer := 0;
begin
  if p_uid is null or length(trim(p_uid)) < 1 or length(p_uid) > 128 then
    raise exception 'INVALID_ACCOUNT';
  end if;

  if not exists(select 1 from nexora.player_profiles where user_id=p_uid)
     and not exists(select 1 from nexora.wallets where user_id=p_uid)
     and not exists(select 1 from nexora.player_private where user_id=p_uid) then
    return jsonb_build_object('ok',true,'already_deleted',true);
  end if;

  perform 1 from nexora.player_profiles where user_id=p_uid for update;
  perform 1 from nexora.wallets where user_id=p_uid for update;

  v_pseudonym := 'deleted:' || md5(p_uid);
  perform set_config('nexora.account_deletion','on',true);
  perform set_config('nexora.account_deletion_uid',p_uid,true);

  -- A current winning bid on another player's live auction cannot be removed
  -- without changing the auction's valid bid history. Ask the player to wait.
  if exists (
    select 1 from nexora.company_auctions
    where highest_bidder_uid=p_uid and seller_uid<>p_uid and status='active' and ends_at>now()
  ) then
    raise exception 'ACCOUNT_HAS_ACTIVE_AUCTION_BID';
  end if;

  -- Cancel auctions owned by the deleting player and return any live bidder's escrow.
  for v_auction in
    select * from nexora.company_auctions
    where seller_uid=p_uid and status='active'
    order by id
    for update
  loop
    if v_auction.highest_bidder_uid is not null then
      perform 1 from nexora.wallets where user_id=v_auction.highest_bidder_uid for update;
      if not found then raise exception 'AUCTION_REFUND_WALLET_MISSING'; end if;

      select * into v_escrow
      from nexora.company_auction_escrows
      where auction_id=v_auction.id
        and bidder_uid=v_auction.highest_bidder_uid
        and status='reserved'
      for update;

      if found then
        update nexora.wallets
        set balance=balance+v_escrow.amount,
            total_spent=greatest(0,total_spent-v_escrow.amount),
            updated_at=now()
        where user_id=v_auction.highest_bidder_uid;

        update nexora.company_auction_escrows
        set status='refunded',updated_at=now()
        where auction_id=v_auction.id and bidder_uid=v_auction.highest_bidder_uid;

        v_tx := 'tx_' || gen_random_uuid()::text;
        insert into nexora.transactions(
          id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
        ) values (
          v_tx,'SYSTEM',v_auction.highest_bidder_uid,v_escrow.amount,0,v_escrow.amount,
          case when v_auction.asset_type='factory' then 'factory_auction_refund' else 'company_auction_refund' end,
          v_auction.id,'Refund because the seller deleted their account','completed'
        );
        v_refunds := v_refunds + 1;
      end if;
    end if;

    update nexora.company_auctions
    set status='cancelled',settled_at=now(),seller_uid=v_pseudonym,
        seller_name='Deleted Player',updated_at=now()
    where id=v_auction.id;

    update nexora.companies
    set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now()
    where id=v_auction.company_id;

    update nexora.factories
    set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now()
    where id=v_auction.factory_id;
  end loop;

  -- Refund any other reserved escrow belonging to this account (including stale rows).
  for v_escrow in
    select * from nexora.company_auction_escrows
    where bidder_uid=p_uid and status='reserved'
    order by auction_id
    for update
  loop
    perform 1 from nexora.wallets where user_id=p_uid for update;
    if not found then raise exception 'ACCOUNT_WALLET_MISSING_FOR_ESCROW_REFUND'; end if;

    update nexora.wallets
    set balance=balance+v_escrow.amount,
        total_spent=greatest(0,total_spent-v_escrow.amount),
        updated_at=now()
    where user_id=p_uid;

    update nexora.company_auction_escrows
    set status='refunded',updated_at=now()
    where auction_id=v_escrow.auction_id and bidder_uid=p_uid;

    v_tx := 'tx_' || gen_random_uuid()::text;
    insert into nexora.transactions(
      id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
    ) values (
      v_tx,'SYSTEM',p_uid,v_escrow.amount,0,v_escrow.amount,
      'company_auction_refund',v_escrow.auction_id,'Refund of reserved auction funds during account deletion','completed'
    );
    v_refunds := v_refunds + 1;
  end loop;

  -- A leader must transfer leadership if other members remain. A solo organization
  -- is archived, not deleted, so its treasury and immutable financial history survive.
  for v_org in
    select id from nexora.organizations where leader_uid=p_uid for update
  loop
    if exists (
      select 1 from nexora.organization_members
      where org_id=v_org.id and user_id<>p_uid
    ) then
      raise exception 'LEADER_MUST_TRANSFER';
    end if;

    update nexora.organizations
    set is_archived=true,
        leader_uid=v_pseudonym,
        leader_name='Deleted Player',
        member_count=0,
        name='Archived organization',
        tag='DEL_' || substr(md5(id),1,12),
        updated_at=now()
    where id=v_org.id;
  end loop;

  update nexora.player_profiles set org_id=null,updated_at=now() where user_id=p_uid;
  delete from nexora.organization_members where user_id=p_uid;
  update nexora.organizations o
  set member_count=(select count(*) from nexora.organization_members m where m.org_id=o.id)
  where member_count<>(select count(*) from nexora.organization_members m where m.org_id=o.id);

  -- Retain legally/financially relevant records while removing direct account identifiers.
  update nexora.transactions
  set from_uid=case when from_uid=p_uid then null else from_uid end,
      to_uid=case when to_uid=p_uid then null else to_uid end,
      description='Historical transaction (anonymized)'
  where from_uid=p_uid or to_uid=p_uid;

  update nexora.audit_logs
  set user_id=null,details=jsonb_build_object('redacted','account_deleted')
  where user_id=p_uid;

  update nexora.company_logs set owner_uid=v_pseudonym where owner_uid=p_uid;
  update nexora.organization_transactions
  set user_id=v_pseudonym,username='Deleted Player',
      note='Historical organization transaction (anonymized)'
  where user_id=p_uid;

  update nexora.org_goal_contributions set user_id=v_pseudonym where user_id=p_uid;
  update nexora.player_reports
  set reporter_uid=case when reporter_uid=p_uid then v_pseudonym else reporter_uid end,
      target_uid=case when target_uid=p_uid then v_pseudonym else target_uid end
  where reporter_uid=p_uid or target_uid=p_uid;

  update nexora.company_auction_bids
  set bidder_uid=v_pseudonym,bidder_name='Deleted Player'
  where bidder_uid=p_uid;
  update nexora.company_auction_escrows set bidder_uid=v_pseudonym where bidder_uid=p_uid;
  update nexora.company_auctions
  set seller_uid=case when seller_uid=p_uid then v_pseudonym else seller_uid end,
      seller_name=case when seller_uid=p_uid then 'Deleted Player' else seller_name end,
      highest_bidder_uid=case when highest_bidder_uid=p_uid then v_pseudonym else highest_bidder_uid end,
      highest_bidder_name=case when highest_bidder_uid=p_uid then 'Deleted Player' else highest_bidder_name end,
      updated_at=now()
  where seller_uid=p_uid or highest_bidder_uid=p_uid;

  update nexora.market_orders
  set buyer_uid=case when buyer_uid=p_uid then v_pseudonym else buyer_uid end,
      seller_uid=case when seller_uid=p_uid then v_pseudonym else seller_uid end
  where buyer_uid=p_uid or seller_uid=p_uid;

  update nexora.market_listings
  set seller_uid=v_pseudonym,seller_name='Deleted Player',
      status='cancelled',remaining_qty=0,updated_at=now()
  where seller_uid=p_uid and status='active';
  update nexora.market_listings
  set seller_uid=v_pseudonym,seller_name='Deleted Player',updated_at=now()
  where seller_uid=p_uid;

  update nexora.companies
  set is_deleted=true,deleted_at=coalesce(deleted_at,now()),
      owner_uid=v_pseudonym,owner_name='Deleted Player',
      vault_balance=0,auction_id=null,auction_ends_at=null,
      auction_status='cancelled',updated_at=now()
  where owner_uid=p_uid and not is_deleted;
  get diagnostics v_archived_companies = row_count;

  update nexora.factories
  set is_deleted=true,is_active=false,warehouse_qty=0,
      owner_uid=v_pseudonym,owner_name='Deleted Player',
      auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now()
  where owner_uid=p_uid and not is_deleted;
  get diagnostics v_archived_factories = row_count;

  update nexora.contract_offers set claimed_by=null where claimed_by=p_uid;
  delete from nexora.contract_offers where scope='personal' and user_id=p_uid;
  delete from nexora.contract_daily_limits where user_id=p_uid;
  delete from nexora.organization_requests where user_id=p_uid;
  delete from nexora.organization_invites where target_uid=p_uid or inviter_uid=p_uid;
  delete from nexora.organization_chat_messages where sender_uid=p_uid;
  delete from nexora.global_chat_messages where sender_uid=p_uid;
  delete from nexora.conversations where participants @> array[p_uid]::text[];
  delete from nexora.user_blocks where owner_uid=p_uid or target_uid=p_uid;
  delete from nexora.notifications where user_id=p_uid;
  delete from nexora.notification_events where user_id=p_uid;
  delete from nexora.player_presence where user_id=p_uid;
  delete from nexora.inventory where user_id=p_uid;
  delete from nexora.diagnostics_admins where user_id=p_uid;

  -- These tables have immutable-history triggers; the narrowly scoped transaction-local
  -- deletion context above permits deleting player progression only during this RPC.
  delete from nexora.player_achievements where user_id=p_uid;
  delete from nexora.player_missions where user_id=p_uid;
  delete from nexora.contract_claims where user_id=p_uid;
  delete from nexora.daily_claims where user_id=p_uid;

  delete from nexora.usernames where uid=p_uid;
  delete from nexora.player_private where user_id=p_uid;
  delete from nexora.wallets where user_id=p_uid;
  delete from nexora.player_profiles where user_id=p_uid;

  return jsonb_build_object(
    'ok',true,
    'already_deleted',false,
    'auction_refunds',v_refunds,
    'archived_companies',v_archived_companies,
    'archived_factories',v_archived_factories
  );
end;
$function$;

revoke all on function nexora.delete_player_account(text) from public,anon,authenticated;
grant execute on function nexora.delete_player_account(text) to service_role;

