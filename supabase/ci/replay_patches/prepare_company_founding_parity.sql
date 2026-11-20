-- CI-only precondition: the local economy rebalance migration is replayed
-- before the immutable production company-founding parity migration. Restore
-- the exact pre-migration sector literals so the production migration is tested
-- against the state it originally expects. This file must never be deployed.
do $patch$
declare
  v_definition text;
  v_pair text[];
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('nexora.found_company(text,text,text)'::regprocedure)
    into v_definition;

  foreach v_pair slice 1 in array array[
    array['trade','1200','160','30','900','140','35'],
    array['services','2200','220','60','1100','175','45'],
    array['logistics','3800','300','85','1400','225','60'],
    array['manufacturing','6000','410','120','1800','290','80'],
    array['tech','9000','550','160','2200','365','95']
  ] loop
    v_new := 'when '''||v_pair[1]||''' then v_cost:='||v_pair[2]||'; v_revenue:='||v_pair[3]||'; v_expense:='||v_pair[4]||';';
    v_old := 'when '''||v_pair[1]||''' then v_cost:='||v_pair[5]||'; v_revenue:='||v_pair[6]||'; v_expense:='||v_pair[7]||';';

    if position(v_new in v_definition)>0 then
      v_definition := replace(v_definition,v_new,v_old);
    elsif position(v_old in v_definition)=0 then
      raise exception 'COMPANY_FOUNDING_REPLAY_PRECONDITION_NOT_FOUND: %',v_pair[1];
    end if;
  end loop;

  execute v_definition;
end
$patch$;
