type SocialAction = { rpc: string; args: Record<string, unknown> };

/** Build the authenticated social/chat RPC request for a supported action. */
export function getSocialAction(
  action: string,
  body: Record<string, unknown>,
  uid: string,
): SocialAction | undefined {
  const targetUid = typeof body.targetUid === "string" ? body.targetUid : "";
  const requestId = typeof body.requestId === "string" ? body.requestId : "";

  const actions: Record<string, SocialAction> = {
    get_public_player_profile: { rpc: "get_public_player_profile", args: { p_target_uid: targetUid } },
    get_org_donation_ranking: { rpc: "get_org_donation_ranking", args: { p_org_id: typeof body.orgId === "string" ? body.orgId : "", p_user_id: uid } },
    touch_player_presence: { rpc: "touch_player_presence", args: { p_user_id: uid } },
    get_players_presence: { rpc: "get_players_presence", args: { p_user_ids: Array.isArray(body.userIds) ? body.userIds.filter((id): id is string => typeof id === "string").slice(0, 60) : [] } },
    search_players: { rpc: "search_players", args: { p_user_id: uid, p_prefix: typeof body.prefix === "string" ? body.prefix : "" } },
    list_blocked_players: { rpc: "list_blocked_players", args: { p_user_id: uid } },
    block_player: { rpc: "block_player", args: { p_user_id: uid, p_target_uid: targetUid } },
    unblock_player: { rpc: "unblock_player", args: { p_user_id: uid, p_target_uid: targetUid } },
    submit_player_report: { rpc: "submit_player_report", args: { p_user_id: uid, p_target_uid: targetUid, p_reason: body.reason, p_request_id: requestId } },
    open_direct_conversation: { rpc: "open_direct_conversation", args: { p_user_id: uid, p_target_uid: targetUid } },
    send_direct_message: { rpc: "send_direct_message", args: { p_user_id: uid, p_target_uid: targetUid, p_text: body.text, p_request_id: requestId } },
    send_global_chat_message: { rpc: "send_global_chat_message", args: { p_user_id: uid, p_text: body.text, p_request_id: requestId } },
    list_direct_conversations: { rpc: "list_direct_conversations", args: { p_user_id: uid } },
    list_direct_messages: { rpc: "list_direct_messages", args: { p_user_id: uid, p_conversation_id: body.conversationId } },
    list_global_chat_messages: { rpc: "list_global_chat_messages", args: { p_user_id: uid } },
    list_organization_invites: { rpc: "list_organization_invites", args: { p_user_id: uid } },
    list_organization_chat_messages: { rpc: "list_organization_chat_messages", args: { p_user_id: uid, p_org_id: typeof body.orgId === "string" ? body.orgId : "" } },
    send_organization_chat_message: { rpc: "send_organization_chat_message", args: { p_user_id: uid, p_org_id: typeof body.orgId === "string" ? body.orgId : "", p_text: body.text, p_request_id: requestId } },
    invite_player_to_organization: { rpc: "invite_player_to_organization", args: { p_user_id: uid, p_target_uid: targetUid } },
    respond_organization_invite: { rpc: "respond_organization_invite", args: { p_user_id: uid, p_invite_id: body.inviteId, p_response: body.response } },
  };

  return actions[action];
}
