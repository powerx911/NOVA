-- Run with: supabase test db
-- Verify the server recipe, actual consumption, and exact cancellation refund.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(13);

select extensions.ok(
  position(
    'v_cost:=320; v_xp:=16; v_required:=2; v_inputs:=' ||
    quote_literal('[{"itemId":"biotech_gel","qty":2},{"itemId":"quantum_dust","qty":1}]') ||
    '::jsonb;'
    in pg_get_functiondef('nexora.manufacture_recipe(text,text,integer)'::regprocedure)
  ) > 0,
  'the server biotechnology recipe matches the canonical catalog inputs and rewards'
);

select extensions.ok(
  position('v_cost:=60; v_xp:=18; v_required:=3' in
    pg_get_functiondef('nexora.manufacture_recipe(text,text,integer)'::regprocedure)
  ) = 0,
  'hidden quantum-server assignments are not appended to the biotechnology recipe'
);

insert into nexora.player_profiles(user_id, username, username_lower, skills, stats)
values (
  'pgtap_biotech_recipe_owner',
  'pgTAP_BiotechRecipe',
  'pgtap_biotechrecipe',
  '{"industry":2}'::jsonb,
  '{"tradesCount":0,"companiesOwned":0,"totalProduced":0}'::jsonb
);

insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values ('pgtap_biotech_recipe_owner', 1000, 1000, 0);

insert into nexora.inventory(user_id, item_id, quantity)
values
  ('pgtap_biotech_recipe_owner', 'biotech_gel', 4),
  ('pgtap_biotech_recipe_owner', 'quantum_dust', 2);

select extensions.lives_ok(
  $$select nexora.manufacture_recipe('pgtap_biotech_recipe_owner', 'rec_biotech_module', 1)$$,
  'industry level two can start the biotechnology recipe'
);

select extensions.is(
  (select output_item_id from nexora.manufacturing_jobs where user_id='pgtap_biotech_recipe_owner' and status='running'),
  'bio_module',
  'the biotechnology recipe creates a bio module'
);

select extensions.is(
  (select output_qty from nexora.manufacturing_jobs where user_id='pgtap_biotech_recipe_owner' and status='running'),
  1,
  'one batch creates exactly one bio module'
);

select extensions.is(
  (select xp_reward from nexora.manufacturing_jobs where user_id='pgtap_biotech_recipe_owner' and status='running'),
  16,
  'the biotechnology recipe grants the catalog XP reward'
);

select extensions.is(
  (select input_snapshot from nexora.manufacturing_jobs where user_id='pgtap_biotech_recipe_owner' and status='running'),
  '[{"itemId":"biotech_gel","qty":2},{"itemId":"quantum_dust","qty":1}]'::jsonb,
  'the refund snapshot records the exact biotechnology inputs'
);

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_biotech_recipe_owner'),
  718::bigint,
  'processing cost is 320 with the level-two industry discount applied'
);

select extensions.is(
  (
    select string_agg(item_id || ':' || quantity::text, ',' order by item_id)
    from nexora.inventory where user_id='pgtap_biotech_recipe_owner'
  ),
  'biotech_gel:2,quantum_dust:1',
  'starting the recipe consumes only the catalog inputs'
);

select extensions.lives_ok(
  $$select nexora.cancel_manufacturing_job(
    'pgtap_biotech_recipe_owner',
    (select id from nexora.manufacturing_jobs where user_id='pgtap_biotech_recipe_owner' and status='running')
  )$$,
  'the biotechnology job can be cancelled before completion'
);

select extensions.is(
  (
    select string_agg(item_id || ':' || quantity::text, ',' order by item_id)
    from nexora.inventory where user_id='pgtap_biotech_recipe_owner'
  ),
  'biotech_gel:4,quantum_dust:2',
  'cancellation restores every biotechnology input exactly once'
);

select extensions.is(
  (select status from nexora.manufacturing_jobs where user_id='pgtap_biotech_recipe_owner'),
  'cancelled',
  'the biotechnology job is marked cancelled'
);

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_biotech_recipe_owner'),
  718::bigint,
  'cancelling returns materials without refunding the processing fee'
);

select * from extensions.finish();
rollback;
