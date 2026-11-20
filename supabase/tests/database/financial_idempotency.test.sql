begin;
select extensions.plan(21);
select extensions.ok(to_regclass('nexora.idempotency_requests') is not null, 'private idempotency ledger exists');
select extensions.ok((select relrowsecurity from pg_class where oid = 'nexora.idempotency_requests'::regclass), 'idempotency ledger has RLS enabled');
select extensions.ok(not has_table_privilege('anon', 'nexora.idempotency_requests', 'SELECT'), 'anon cannot read idempotency responses');
select extensions.ok(not has_table_privilege('authenticated', 'nexora.idempotency_requests', 'SELECT'), 'players cannot read idempotency responses');
select extensions.ok(has_table_privilege('service_role', 'nexora.idempotency_requests', 'SELECT') and has_table_privilege('service_role', 'nexora.idempotency_requests', 'INSERT') and has_table_privilege('service_role', 'nexora.idempotency_requests', 'UPDATE'), 'service role has ledger access');
select extensions.ok(has_function_privilege('service_role', 'nexora.transfer_credits_idempotent(text,text,bigint,text,text)', 'EXECUTE'), 'service role can execute idempotent transfers');
select extensions.ok(not has_function_privilege('authenticated', 'nexora.transfer_credits_idempotent(text,text,bigint,text,text)', 'EXECUTE'), 'players cannot call privileged transfer wrapper');
select extensions.ok(has_function_privilege('service_role', 'nexora.deposit_org_treasury_idempotent(text,text,bigint,text)', 'EXECUTE'), 'service role can execute idempotent treasury deposits');
select extensions.ok(has_function_privilege('service_role', 'nexora.buy_market_listings_at_quote_idempotent(text,jsonb,jsonb,text)', 'EXECUTE'), 'service role can execute quote-checked market batches');
select extensions.ok(not has_function_privilege('authenticated', 'nexora.buy_market_listings_at_quote_idempotent(text,jsonb,jsonb,text)', 'EXECUTE'), 'players cannot bypass quote confirmation or idempotency');
select extensions.ok(exists (select 1 from pg_trigger where tgrelid='nexora.player_profiles'::regclass and tgname='player_profiles_cleanup_idempotency_requests' and not tgisinternal), 'account deletion trigger clears idempotency receipts');

-- Functional replay test: a retry with the same key must not move money twice.
insert into nexora.player_profiles(user_id,username,username_lower,level)
values
  ('pgtap_transfer_sender','PgtapTransferSender','pgtaptransfersender',1),
  ('pgtap_transfer_recipient','PgtapTransferRecipient','pgtaptransferrecipient',1);

update nexora.player_profiles set level=10 where user_id='pgtap_transfer_sender';

insert into nexora.usernames(username_lower,uid,username)
values ('pgtaptransferrecipient','pgtap_transfer_recipient','PgtapTransferRecipient');

insert into nexora.wallets(user_id,balance) values
  ('pgtap_transfer_sender',1000),
  ('pgtap_transfer_recipient',0);

create temporary table pgtap_transfer_idempotency_results (
  first_response jsonb,
  replay_response jsonb
);

insert into pgtap_transfer_idempotency_results(first_response)
values (
  nexora.transfer_credits_idempotent(
    'pgtap_transfer_sender',
    'PgtapTransferRecipient',
    100,
    'idempotency replay test',
    'pgtap-transfer-replay-0001'
  )
);

update pgtap_transfer_idempotency_results
set replay_response = nexora.transfer_credits_idempotent(
  'pgtap_transfer_sender',
  'PgtapTransferRecipient',
  100,
  'idempotency replay test',
  'pgtap-transfer-replay-0001'
);

select extensions.ok(
  (select (first_response->>'ok')::boolean from pgtap_transfer_idempotency_results),
  'first transfer request executes successfully'
);

select extensions.ok(
  (select coalesce((replay_response->>'idempotent_replay')::boolean,false) from pgtap_transfer_idempotency_results),
  'retry with the same key returns the stored replay response'
);

select extensions.is(
  (select replay_response->>'transaction_id' from pgtap_transfer_idempotency_results),
  (select first_response->>'transaction_id' from pgtap_transfer_idempotency_results),
  'retry returns the original transaction ID'
);

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_transfer_sender'),
  900::bigint,
  'sender is debited exactly once'
);

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_transfer_recipient'),
  97::bigint,
  'recipient receives the net transfer exactly once'
);

select extensions.is(
  (select count(*)::integer from nexora.transactions where from_uid='pgtap_transfer_sender' and type='transfer'),
  1,
  'only one transfer ledger row is created'
);

select extensions.is(
  (select count(*)::integer from nexora.idempotency_requests where user_id='pgtap_transfer_sender' and action='transfer_credits' and request_id='pgtap-transfer-replay-0001'),
  1,
  'only one idempotency receipt is stored'
);

do $test$
declare v_rejected boolean := false;
begin
  begin
    perform nexora.transfer_credits_idempotent(
      'pgtap_transfer_sender',
      'PgtapTransferRecipient',
      101,
      'idempotency replay test',
      'pgtap-transfer-replay-0001'
    );
  exception when others then
    if sqlerrm = 'IDEMPOTENCY_KEY_REUSED' then
      v_rejected := true;
    else
      raise;
    end if;
  end;
  if not v_rejected then
    raise exception 'expected IDEMPOTENCY_KEY_REUSED for a different payload';
  end if;
end
$test$;

select extensions.ok(true, 'same key with a different transfer payload is rejected');

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_transfer_sender'),
  900::bigint,
  'rejected key reuse does not change the sender balance'
);

select extensions.is(
  (select count(*)::integer from nexora.transactions where from_uid='pgtap_transfer_sender' and type='transfer'),
  1,
  'rejected key reuse does not create another transaction'
);

select * from extensions.finish();
rollback;
