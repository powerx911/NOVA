-- Restore company founding parity with the current client catalog.
-- Existing company baselines are updated without changing wallets or transaction history.

do $patch$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('nexora.found_company(text,text,text)'::regprocedure)
    into v_definition;

  v_old := 'when ''trade'' then v_cost:=900; v_revenue:=140; v_expense:=35;';
  v_new := 'when ''trade'' then v_cost:=1200; v_revenue:=160; v_expense:=30;';
  if position(v_old in v_definition)=0 then raise exception 'COMPANY_FOUNDING_TRADE_PATCH_NOT_MATCHED'; end if;
  v_definition := replace(v_definition,v_old,v_new);

  v_old := 'when ''services'' then v_cost:=1100; v_revenue:=175; v_expense:=45;';
  v_new := 'when ''services'' then v_cost:=2200; v_revenue:=220; v_expense:=60;';
  if position(v_old in v_definition)=0 then raise exception 'COMPANY_FOUNDING_SERVICES_PATCH_NOT_MATCHED'; end if;
  v_definition := replace(v_definition,v_old,v_new);

  v_old := 'when ''logistics'' then v_cost:=1400; v_revenue:=225; v_expense:=60;';
  v_new := 'when ''logistics'' then v_cost:=3800; v_revenue:=300; v_expense:=85;';
  if position(v_old in v_definition)=0 then raise exception 'COMPANY_FOUNDING_LOGISTICS_PATCH_NOT_MATCHED'; end if;
  v_definition := replace(v_definition,v_old,v_new);

  v_old := 'when ''manufacturing'' then v_cost:=1800; v_revenue:=290; v_expense:=80;';
  v_new := 'when ''manufacturing'' then v_cost:=6000; v_revenue:=410; v_expense:=120;';
  if position(v_old in v_definition)=0 then raise exception 'COMPANY_FOUNDING_MANUFACTURING_PATCH_NOT_MATCHED'; end if;
  v_definition := replace(v_definition,v_old,v_new);

  v_old := 'when ''tech'' then v_cost:=2200; v_revenue:=365; v_expense:=95;';
  v_new := 'when ''tech'' then v_cost:=9000; v_revenue:=550; v_expense:=160;';
  if position(v_old in v_definition)=0 then raise exception 'COMPANY_FOUNDING_TECH_PATCH_NOT_MATCHED'; end if;
  v_definition := replace(v_definition,v_old,v_new);

  if position('v_cost:=900;' in v_definition)>0
     or position('v_revenue:=365;' in v_definition)>0 then
    raise exception 'COMPANY_FOUNDING_LEGACY_VALUES_REMAIN';
  end if;

  execute v_definition;
end
$patch$;

-- Bring existing companies onto the same baseline used by the current UI.
-- No wallet, XP, reputation, inventory, or transaction records are modified.
update nexora.companies
set base_revenue_per_hour = case sector
      when 'trade' then 160
      when 'services' then 220
      when 'logistics' then 300
      when 'manufacturing' then 410
      when 'tech' then 550
      else base_revenue_per_hour
    end,
    expense_per_hour = case sector
      when 'trade' then 30
      when 'services' then 60
      when 'logistics' then 85
      when 'manufacturing' then 120
      when 'tech' then 160
      else expense_per_hour
    end,
    updated_at = now()
where sector in ('trade','services','logistics','manufacturing','tech')
  and (
    base_revenue_per_hour is distinct from case sector
      when 'trade' then 160 when 'services' then 220 when 'logistics' then 300
      when 'manufacturing' then 410 when 'tech' then 550 else base_revenue_per_hour end
    or expense_per_hour is distinct from case sector
      when 'trade' then 30 when 'services' then 60 when 'logistics' then 85
      when 'manufacturing' then 120 when 'tech' then 160 else expense_per_hour end
  );
