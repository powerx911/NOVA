create or replace function nexora.reset_player_skills(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_refund integer;
  v_cost bigint := 2500;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_profile from nexora.player_profiles where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_refund :=
    coalesce((v_profile.skills->>'trade')::integer, 0) +
    coalesce((v_profile.skills->>'management')::integer, 0) +
    coalesce((v_profile.skills->>'industry')::integer, 0) +
    coalesce((v_profile.skills->>'negotiation')::integer, 0) +
    coalesce((v_profile.skills->>'finance')::integer, 0) +
    coalesce((v_profile.skills->>'leadership')::integer, 0);
  if v_refund < 1 then raise exception 'NO_SKILLS_TO_RESET'; end if;

  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;

  update nexora.wallets
    set balance = balance - v_cost,
        total_spent = total_spent + v_cost,
        last_tx_id = v_tx,
        updated_at = now()
    where user_id = p_uid;

  update nexora.player_profiles
    set skills = jsonb_build_object(
      'trade', 0, 'management', 0, 'industry', 0,
      'negotiation', 0, 'finance', 0, 'leadership', 0
    ),
    skill_points = skill_points + v_refund,
    updated_at = now()
    where user_id = p_uid;

  insert into nexora.transactions(
    id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status
  ) values (
    v_tx, p_uid, 'SYSTEM', v_cost, 0, v_cost, 'skill_reset', p_uid,
    'Skill reset; refunded ' || v_refund::text || ' skill points', 'completed'
  );

  return jsonb_build_object('ok', true, 'refunded_points', v_refund, 'cost', v_cost);
end;
$$;

revoke all on function nexora.reset_player_skills(text) from public, anon, authenticated;
grant execute on function nexora.reset_player_skills(text) to service_role;
