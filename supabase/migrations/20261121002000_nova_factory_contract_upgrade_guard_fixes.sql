-- Follow-up corrections for the 2026-11-20 production parity migration.
-- Keep historical production migration sources immutable; apply these corrections
-- as a new, independently tracked migration on the hardening branches.

-- Restore the ten resource-specific factory progression curves.
create or replace function nexora.factory_progression_multiplier(p_resource_id text, p_level integer)
returns numeric
language sql
immutable
set search_path = ''
as $function$
  with curve as (
    select
      case p_resource_id
        when 'copper_wire' then 0.028::numeric
        when 'silicon_ore' then 0.030::numeric
        when 'energy_cells' then 0.032::numeric
        when 'crude_alloy' then 0.034::numeric
        when 'carbon_fiber' then 0.036::numeric
        when 'rare_minerals' then 0.038::numeric
        when 'titanium_ore' then 0.040::numeric
        when 'polymer_resin' then 0.042::numeric
        when 'biotech_gel' then 0.044::numeric
        when 'quantum_dust' then 0.046::numeric
        else 0.028::numeric
      end as linear_growth,
      case p_resource_id
        when 'copper_wire' then 0.00020::numeric
        when 'silicon_ore' then 0.00022::numeric
        when 'energy_cells' then 0.00024::numeric
        when 'crude_alloy' then 0.00026::numeric
        when 'carbon_fiber' then 0.00028::numeric
        when 'rare_minerals' then 0.00030::numeric
        when 'titanium_ore' then 0.00032::numeric
        when 'polymer_resin' then 0.00034::numeric
        when 'biotech_gel' then 0.00036::numeric
        when 'quantum_dust' then 0.00038::numeric
        else 0.00020::numeric
      end as quadratic_growth
  )
  select 1
    + linear_growth * greatest(0, coalesce(p_level, 1) - 1)
    + quadratic_growth * power(greatest(0, coalesce(p_level, 1) - 1)::numeric, 2)
  from curve
$function$;

-- Keep the database's one-active-organization-contract rule aligned with its
-- partial unique index and the established contract lifecycle behavior.
do $patch$
declare
  v_definition text;
  v_old text := $old$select count(*) into v_active from nexora.contract_offers
      where scope='organization' and claimed_by=p_uid and status in ('accepted','processing','ready');
    if v_active>=3 then raise exception 'ORG_ACTIVE_CONTRACT_LIMIT'; end if;$old$;
  v_new text := $new$if exists(select 1 from nexora.contract_offers where scope='organization' and claimed_by=p_uid
      and status in ('accepted','processing','ready')) then raise exception 'ORG_ACTIVE_CONTRACT_LIMIT'; end if;$new$;
begin
  select pg_get_functiondef('nexora.accept_dynamic_contract(text,text)'::regprocedure)
    into v_definition;

  if position(v_new in v_definition)=0 then
    if position(v_old in v_definition)=0 then
      raise exception 'ORG_ACTIVE_CONTRACT_GUARD_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := replace(v_definition,v_old,v_new);
  end if;
  execute v_definition;
end
$patch$;

-- Do not start a second factory/warehouse upgrade while the first one is still
-- awaiting its completion RPC, even if its timer has elapsed.
do $patch$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)'::regprocedure)
    into v_definition;

  v_old := $old$if v_factory.warehouse_upgrade_ends_at is not null and v_factory.warehouse_upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;$old$;
  v_new := $new$if v_factory.warehouse_upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;$new$;
  if position(v_new in v_definition)=0 then
    if position(v_old in v_definition)=0 then
      raise exception 'WAREHOUSE_UPGRADE_GUARD_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := replace(v_definition,v_old,v_new);
  end if;

  v_old := $old$if v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;$old$;
  v_new := $new$if v_factory.upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;$new$;
  if position(v_new in v_definition)=0 then
    if position(v_old in v_definition)=0 then
      raise exception 'FACTORY_UPGRADE_GUARD_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := replace(v_definition,v_old,v_new);
  end if;

  if position('UPGRADE_NOT_FINISHED' in v_definition)=0 then
    raise exception 'FACTORY_UPGRADE_GUARD_PATCH_VALIDATION_FAILED';
  end if;
  execute v_definition;
end
$patch$;
