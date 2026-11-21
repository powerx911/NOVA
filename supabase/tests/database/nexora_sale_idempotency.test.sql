begin;

select extensions.plan(4);

select extensions.ok(
  to_regprocedure('nexora.sell_to_nexora_idempotent(text,text,integer,text)') is not null,
  'idempotent NEXORA sale RPC exists'
);

select extensions.ok(
  not has_function_privilege('anon', 'nexora.sell_to_nexora_idempotent(text,text,integer,text)', 'EXECUTE'),
  'anonymous clients cannot execute the idempotent sale RPC'
);

select extensions.ok(
  not has_function_privilege('authenticated', 'nexora.sell_to_nexora_idempotent(text,text,integer,text)', 'EXECUTE'),
  'authenticated clients cannot bypass the trusted API for the idempotent sale RPC'
);

select extensions.ok(
  has_function_privilege('service_role', 'nexora.sell_to_nexora_idempotent(text,text,integer,text)', 'EXECUTE'),
  'trusted service role can execute the idempotent sale RPC'
);

select * from extensions.finish();

rollback;
