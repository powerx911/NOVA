-- Advanced resource recipes mirrored by src/data/catalog.ts.
CREATE OR REPLACE FUNCTION nexora.manufacture_recipe(p_uid text, p_recipe_id text, p_batches integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_inputs jsonb; v_output text; v_output_qty integer; v_cost integer; v_xp integer; v_required integer;
  v_profile nexora.player_profiles%rowtype; v_wallet nexora.wallets%rowtype;
  v_item record; v_qty integer; v_discount numeric; v_unit_cost integer; v_total bigint;
  v_tx text := 'tx_' || gen_random_uuid()::text; v_new_xp bigint;
  v_level integer := 1; v_remaining bigint; v_step bigint; v_levels_gained integer; v_leadership numeric; v_stats jsonb;
BEGIN
  IF p_batches IS NULL OR p_batches < 1 OR p_batches > 999 THEN RAISE EXCEPTION 'INVALID_QUANTITY'; END IF;
  CASE p_recipe_id
    WHEN 'rec_microchips' THEN v_output:='microchips'; v_output_qty:=2; v_cost:=40; v_xp:=45; v_required:=0; v_inputs:='[{"itemId":"silicon_ore","qty":2},{"itemId":"copper_wire","qty":2}]'::jsonb;
    WHEN 'rec_precision_frame' THEN v_output:='precision_frame'; v_output_qty:=2; v_cost:=50; v_xp:=55; v_required:=0; v_inputs:='[{"itemId":"crude_alloy","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    WHEN 'rec_synth_polymer' THEN v_output:='synth_polymer'; v_output_qty:=2; v_cost:=60; v_xp:=65; v_required:=1; v_inputs:='[{"itemId":"energy_cells","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb;
    WHEN 'rec_quantum_server' THEN v_output:='quantum_server'; v_output_qty:=1; v_cost:=90; v_xp:=110; v_required:=1; v_inputs:='[{"itemId":"microchips","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    WHEN 'rec_logistics_drone' THEN v_output:='logistics_drone'; v_output_qty:=1; v_cost:=110; v_xp:=125; v_required:=2; v_inputs:='[{"itemId":"precision_frame","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    WHEN 'rec_bio_module' THEN v_output:='bio_module'; v_output_qty:=1; v_cost:=125; v_xp:=140; v_required:=2; v_inputs:='[{"itemId":"synth_polymer","qty":2},{"itemId":"rare_minerals","qty":2}]'::jsonb;
    WHEN 'rec_titanium_frame' THEN v_output:='precision_frame'; v_output_qty:=2; v_cost:=80; v_xp:=75; v_required:=1; v_inputs:='[{"itemId":"titanium_ore","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    WHEN 'rec_polymer_composite' THEN v_output:='synth_polymer'; v_output_qty:=2; v_cost:=90; v_xp:=85; v_required:=1; v_inputs:='[{"itemId":"polymer_resin","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    WHEN 'rec_biotech_module' THEN v_output:='bio_module'; v_output_qty:=1; v_cost:=320; v_xp:=155; v_required:=2; v_inputs:='[{"itemId":"biotech_gel","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb;
    WHEN 'rec_quantum_server_advanced' THEN v_output:='quantum_server'; v_output_qty:=1; v_cost:=60; v_xp:=180; v_required:=3; v_inputs:='[{"itemId":"quantum_dust","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    ELSE RAISE EXCEPTION 'INVALID_RECIPE';
  END CASE;
  SELECT * INTO v_profile FROM nexora.player_profiles WHERE user_id=p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;
  SELECT * INTO v_wallet FROM nexora.wallets WHERE user_id=p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;
  IF coalesce((v_profile.skills->>'industry')::integer,0) < v_required THEN RAISE EXCEPTION 'INDUSTRY_SKILL_TOO_LOW'; END IF;
  v_discount:=least(0.45,greatest(0,coalesce((v_profile.skills->>'industry')::integer,0))*0.06);
  v_unit_cost:=greatest(10,round(v_cost*(1-v_discount))::integer); v_total:=v_unit_cost*p_batches;
  IF v_wallet.balance<v_total THEN RAISE EXCEPTION 'INSUFFICIENT_FUNDS'; END IF;
  FOR v_item IN SELECT value->>'itemId' AS item_id,(value->>'qty')::integer AS qty FROM jsonb_array_elements(v_inputs) ORDER BY value->>'itemId' LOOP
    SELECT quantity INTO v_qty FROM nexora.inventory WHERE user_id=p_uid AND item_id=v_item.item_id FOR UPDATE;
    IF NOT FOUND OR v_qty<v_item.qty*p_batches THEN RAISE EXCEPTION 'MISSING_INPUTS'; END IF;
  END LOOP;
  UPDATE nexora.wallets SET balance=balance-v_total,total_spent=total_spent+v_total,last_tx_id=v_tx,updated_at=now() WHERE user_id=p_uid;
  FOR v_item IN SELECT value->>'itemId' AS item_id,(value->>'qty')::integer AS qty FROM jsonb_array_elements(v_inputs) LOOP
    UPDATE nexora.inventory SET quantity=quantity-v_item.qty*p_batches,updated_at=now() WHERE user_id=p_uid AND item_id=v_item.item_id;
  END LOOP;
  INSERT INTO nexora.inventory(user_id,item_id,quantity) VALUES(p_uid,v_output,v_output_qty*p_batches)
  ON CONFLICT(user_id,item_id) DO UPDATE SET quantity=nexora.inventory.quantity+excluded.quantity,updated_at=now();
  INSERT INTO nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  VALUES(v_tx,p_uid,'SYSTEM',v_total,0,v_total,'manufacturing',p_recipe_id,'Manufactured '||(v_output_qty*p_batches)::text||'x '||v_output||' ('||p_batches::text||' batches)','completed');
  v_new_xp:=v_profile.xp+v_xp*p_batches; v_remaining:=v_new_xp;
  WHILE v_level<200 LOOP v_step:=200+(v_level-1)*120; EXIT WHEN v_remaining<v_step; v_remaining:=v_remaining-v_step; v_level:=v_level+1; END LOOP;
  v_levels_gained:=greatest(0,v_level-v_profile.level); v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{totalProduced}',to_jsonb(coalesce((v_profile.stats->>'totalProduced')::integer,0)+v_output_qty*p_batches),true);
  UPDATE nexora.player_profiles SET xp=v_new_xp,level=v_level,skill_points=skill_points+v_levels_gained*2,
    reputation=reputation+round(3*v_leadership)::bigint,influence=influence+round(2*v_leadership)::bigint,stats=v_stats,updated_at=now()
  WHERE user_id=p_uid;
  RETURN jsonb_build_object('ok',true,'output_item',v_output,'output_qty',v_output_qty*p_batches,'cost',v_total);
END;
$function$;
