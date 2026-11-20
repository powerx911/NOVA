-- Raise company upgrade costs to target roughly one day of payback at the
-- current incremental-profit curve, without reconnecting costs to founding price.

create or replace function nexora.company_upgrade_cost(p_sector text, p_level integer)
returns bigint
language sql immutable
set search_path = ''
as $function$
  select ceil(
    nexora.company_sector_level_gain(p_sector)
    * (8 + greatest(1, least(99, coalesce(p_level, 1))))
  )::bigint
$function$;
