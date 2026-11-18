create or replace function nexora.manufacture_recipe(p_uid text,p_recipe_id text,p_batches integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_inputs jsonb; v_output text; v_output_qty integer; v_cost integer; v_xp integer; v_required integer;
  v_profile nexora.player_profiles%rowtype; v_wallet nexora.wallets%rowtype;
  v_item record; v_qty integer; v_discount numeric; v_unit_cost integer; v_total bigint;
  v_tx text := 'tx_' || gen_random_uuid()::text; v_new_xp bigint;
  v_level integer := 1; v_remaining bigint; v_step bigint; v_levels_gained integer; v_leadership numeric; v_stats jsonb;
begin
  if p_batches is null or p_batches < 1 or p_batches > 999 then raise exception 'INVALID_QUANTITY'; end if;
  case p_recipe_id
    when 'rec_microchips' then v_output:='microchips'; v_output_qty:=2; v_cost:=40; v_xp:=45; v_required:=0; v_inputs:='[{"itemId":"silicon_ore","qty":2},{"itemId":"copper_wire","qty":2}]'::jsonb;
    when 'rec_precision_frame' then v_output:='precision_frame'; v_output_qty:=2; v_cost:=50; v_xp:=55; v_required:=0; v_inputs:='[{"itemId":"crude_alloy","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    when 'rec_synth_polymer' then v_output:='synth_polymer'; v_output_qty:=2; v_cost:=60; v_xp:=65; v_required:=1; v_inputs:='[{"itemId":"energy_cells","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb;
    when 'rec_quantum_server' then v_output:='quantum_server'; v_output_qty:=1; v_cost:=90; v_xp:=110; v_required:=1; v_inputs:='[{"itemId":"microchips","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    when 'rec_logistics_drone' then v_output:='logistics_drone'; v_output_qty:=1; v_cost:=110; v_xp:=125; v_required:=2; v_inputs:='[{"itemId":"precision_frame","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    when 'rec_bio_module' then v_output:='bio_module'; v_output_qty:=1; v_cost:=125; v_xp:=140; v_required:=2; v_inputs:='[{"itemId":"synth_polymer","qty":2},{"itemId":"rare_minerals","qty":2}]'::jsonb;
    else raise exception 'INVALID_RECIPE';
  end case;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if coalesce((v_profile.skills->>'industry')::integer,0) < v_required then raise exception 'INDUSTRY_SKILL_TOO_LOW'; end if;
  v_discount:=least(0.45,greatest(0,coalesce((v_profile.skills->>'industry')::integer,0))*0.06);
  v_unit_cost:=greatest(10,round(v_cost*(1-v_discount))::integer); v_total:=v_unit_cost*p_batches;
  if v_wallet.balance<v_total then raise exception 'INSUFFICIENT_FUNDS'; end if;
  for v_item in select value->>'itemId' as item_id,(value->>'qty')::integer as qty from jsonb_array_elements(v_inputs) order by value->>'itemId' loop
    select quantity into v_qty from nexora.inventory where user_id=p_uid and item_id=v_item.item_id for update;
    if not found or v_qty<v_item.qty*p_batches then raise exception 'MISSING_INPUTS'; end if;
  end loop;
  update nexora.wallets set balance=balance-v_total,total_spent=total_spent+v_total,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  for v_item in select value->>'itemId' as item_id,(value->>'qty')::integer as qty from jsonb_array_elements(v_inputs) loop
    update nexora.inventory set quantity=quantity-v_item.qty*p_batches,updated_at=now() where user_id=p_uid and item_id=v_item.item_id;
  end loop;
  insert into nexora.inventory(user_id,item_id,quantity) values(p_uid,v_output,v_output_qty*p_batches)
  on conflict(user_id,item_id) do update set quantity=nexora.inventory.quantity+excluded.quantity,updated_at=now();
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_total,0,v_total,'manufacturing',p_recipe_id,'Manufactured ' || (v_output_qty*p_batches)::text || 'x ' || v_output || ' (' || p_batches::text || ' batches)','completed');
  v_new_xp:=v_profile.xp+v_xp*p_batches; v_remaining:=v_new_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120; exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step; v_level:=v_level+1;
  end loop;
  v_levels_gained:=greatest(0,v_level-v_profile.level); v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{totalProduced}',to_jsonb(coalesce((v_profile.stats->>'totalProduced')::integer,0)+v_output_qty*p_batches),true);
  update nexora.player_profiles set xp=v_new_xp,level=v_level,skill_points=skill_points+v_levels_gained*2,
    reputation=reputation+round(3*v_leadership)::bigint,influence=influence+round(2*v_leadership)::bigint,
    stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'output_item',v_output,'output_qty',v_output_qty*p_batches,'cost',v_total);
end;
$$;
revoke all on function nexora.manufacture_recipe(text,text,integer) from public,anon,authenticated;
grant execute on function nexora.manufacture_recipe(text,text,integer) to service_role;
