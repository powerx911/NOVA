import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';
import {
  COMPANY_SECTORS,
  ITEM_MAP,
  MANUFACTURING_RECIPES,
  MISSIONS,
  PROPERTY_SPECS,
  ROLE_DEFAULT_PERMISSIONS,
  SEED_MARKET_LISTINGS,
  SEED_WORLD_EVENTS,
  SKILL_DEFINITIONS,
  TRADE_CONTRACTS,
} from '../data/catalog';
import {
  calculateLevelProgress,
  canManageOrgMember,
  getAchievementProgress,
  hasOrgPermission,
  isValidUsername,
  LISTING_MAX_PRICE,
  LISTING_MAX_QTY,
  timestampToMs as parseTimestampMs,
} from '../lib/economy';
import { auth, db, handleFirestoreError, OperationType } from '../lib/firebase';
import { nexoraApi } from '../lib/nexoraApi';
import type {
  Company,
  CompanySector,
  InventoryItem,
  Language,
  MarketListing,
  Organization,
  OrganizationMember,
  OrgRole,
  PlayerProfile,
  PropertyAsset,
  PropertyType,
  SkillKey,
  Wallet,
} from '../types/game';

function genId(prefix: string): string {
  const rand = Math.random().toString(36).slice(2, 10);
  return `${prefix}_${Date.now()}_${rand}`;
}

export function getUtcDateKey(): string {
  return new Date().toISOString().slice(0, 10);
}

export function timestampToMs(ts: unknown): number {
  return parseTimestampMs(ts, Date.now());
}

function applyXpAndLevel(
  profile: PlayerProfile,
  xpGain: number,
  reputationGain = 0,
  influenceGain = 0
) {
  const nextXp = profile.xp + Math.max(0, Math.round(xpGain));
  const prog = calculateLevelProgress(nextXp);
  const levelsGained = Math.max(0, prog.level - profile.level);
  const leadershipBonus = 1 + (profile.skills.leadership || 0) * 0.1;
  return {
    xp: nextXp,
    level: prog.level,
    skillPoints: profile.skillPoints + levelsGained * 2,
    reputation: profile.reputation + Math.round(reputationGain * leadershipBonus),
    influence: profile.influence + Math.round(influenceGain * leadershipBonus),
  };
}

export async function ensureBootstrapWorldData(): Promise<void> {
  try {
    const nowMs = Date.now();
    for (const evt of SEED_WORLD_EVENTS) {
      const ref = doc(db, 'world_events', evt.id);
      const snap = await getDoc(ref);
      if (!snap.exists()) {
        const { durationHours, ...eventPayload } = evt;
        await setDoc(ref, {
          ...eventPayload,
          startsAt: Timestamp.fromMillis(nowMs),
          endsAt: Timestamp.fromMillis(nowMs + durationHours * 3_600_000),
          createdAt: serverTimestamp(),
        });
      }
    }

    for (const seed of SEED_MARKET_LISTINGS) {
      const ref = doc(db, 'market_listings', seed.id);
      const snap = await getDoc(ref);
      if (!snap.exists()) {
        await setDoc(ref, {
          id: seed.id,
          sellerUid: 'SYSTEM',
          sellerName: 'NEXORA Reserve',
          itemId: seed.itemId,
          quantity: seed.quantity,
          remainingQty: seed.quantity,
          unitPrice: seed.unitPrice,
          status: 'active',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
      }
    }
  } catch (error) {
    console.warn('Bootstrap world data check skipped or partially seeded:', error);
  }
}

export async function isUsernameAvailable(username: string): Promise<boolean> {
  const clean = username.trim();
  if (!isValidUsername(clean)) return false;
  const result = await nexoraApi<{ available: boolean }>('username_available', { username: clean });
  return result.available;
}

export async function createPlayerCharacter(
  _uid: string,
  _email: string,
  username: string,
  avatarId: string,
  language: Language
): Promise<void> {
  const trimmed = username.trim();
  if (!isValidUsername(trimmed)) throw new Error('INVALID_USERNAME');
  try {
    await nexoraApi('create_character', {
      username: trimmed,
      avatarId,
      language,
    });
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      const code = String((error as { code?: unknown }).code ?? '');
      if (['INVALID_USERNAME', 'USERNAME_TAKEN', 'PROFILE_EXISTS'].includes(code)) {
        throw new Error(code);
      }
    }
    throw error;
  }
}

export async function claimDailyStipend(_uid: string): Promise<number> {
  try {
    const result = await nexoraApi<{ amount: number }>('claim_daily_stipend');
    return result.amount;
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      throw new Error(String((error as { code?: unknown }).code ?? 'DAILY_CLAIM_FAILED'));
    }
    throw error;
  }
}

export async function upgradeSkill(_uid: string, skillKey: SkillKey): Promise<void> {
  try {
    await nexoraApi('upgrade_skill', { skillKey });
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      throw new Error(String((error as { code?: unknown }).code ?? 'SKILL_UPGRADE_FAILED'));
    }
    throw error;
  }
}

export async function transferCredits(
  _fromUid: string,
  recipientUsername: string,
  amountRaw: number,
  note: string
): Promise<void> {
  const amount = Number.isFinite(amountRaw) ? Math.floor(amountRaw) : 0;
  try {
    await nexoraApi('transfer_credits', {
      recipientUsername: recipientUsername.trim(),
      amount,
      note: note.trim().slice(0, 180),
    });
  } catch (error) {
    if (error instanceof Error && 'code' in error) {
      throw new Error(String((error as { code?: unknown }).code ?? 'TRANSFER_FAILED'));
    }
    throw error;
  }
}

export async function createMarketListing(
  _uid: string,
  _username: string,
  itemId: string,
  qtyRaw: number,
  unitPriceRaw: number
): Promise<void> {
  const quantity = Number.isFinite(qtyRaw) ? Math.floor(qtyRaw) : 0;
  const unitPrice = Number.isFinite(unitPriceRaw) ? Math.round(unitPriceRaw) : 0;
  if (!ITEM_MAP[itemId]) throw new Error('INVALID_ITEM');
  if (quantity < 1 || quantity > LISTING_MAX_QTY || unitPrice < 1 || unitPrice > LISTING_MAX_PRICE) {
    throw new Error('INVALID_LISTING_PARAMS');
  }
  try {
    await nexoraApi('create_market_listing', { itemId, quantity, unitPrice });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'CREATE_LISTING_FAILED'));
    throw error;
  }
}

export async function buyMarketListing(
  _buyerUid: string,
  listingId: string,
  buyQtyRaw: number,
  _taxRate: number
): Promise<void> {
  const quantity = Number.isFinite(buyQtyRaw) ? Math.floor(buyQtyRaw) : 0;
  if (quantity < 1) throw new Error('INVALID_QUANTITY');
  try {
    await nexoraApi('buy_market_listing', { listingId, quantity });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MARKET_PURCHASE_FAILED'));
    throw error;
  }
}

export async function cancelMarketListing(_uid: string, listingId: string): Promise<void> {
  try {
    await nexoraApi('cancel_market_listing', { listingId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'CANCEL_LISTING_FAILED'));
    throw error;
  }
}

export async function manufactureRecipe(_uid: string, recipeId: string, batchQuantity = 1): Promise<void> {
  if (!MANUFACTURING_RECIPES.some((recipe) => recipe.id === recipeId)) throw new Error('INVALID_RECIPE');
  if (!Number.isInteger(batchQuantity) || batchQuantity < 1 || batchQuantity > 999) throw new Error('INVALID_QUANTITY');
  try {
    await nexoraApi('manufacture_recipe', { recipeId, batches: batchQuantity });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MANUFACTURING_FAILED'));
    throw error;
  }
}

export async function fulfillTradeContract(_uid: string, contractId: string): Promise<number> {
  if (!TRADE_CONTRACTS.some((contract) => contract.id === contractId)) throw new Error('INVALID_CONTRACT');
  try {
    const result = await nexoraApi<{ payout: number }>('fulfill_trade_contract', { contractId });
    return result.payout;
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'CONTRACT_FULFILLMENT_FAILED'));
    throw error;
  }
}

export async function foundCompany(
  _uid: string,
  _ownerName: string,
  name: string,
  sector: CompanySector
): Promise<void> {
  const cleanName = name.trim();
  if (cleanName.length < 2 || cleanName.length > 48) throw new Error('INVALID_NAME');
  if (!COMPANY_SECTORS.some((item) => item.sector === sector)) throw new Error('INVALID_SECTOR');
  await nexoraApi('found_company', { name: cleanName, sector });
}

async function callSupabaseCompanyAction<T>(action: string, companyId: string): Promise<T> {
  try {
    return await nexoraApi<T>(action, { companyId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'COMPANY_OPERATION_FAILED'));
    throw error;
  }
}

export async function upgradeCompany(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('company_upgrade', companyId);
}

export async function upgradeCompanyVault(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('vault_upgrade', companyId);
}

export async function completeCompanyUpgrade(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('company_complete', companyId);
}

export async function completeCompanyVaultUpgrade(_uid: string, companyId: string): Promise<void> {
  await callSupabaseCompanyAction('vault_complete', companyId);
}

export async function collectCompanyRevenue(_uid: string, companyId: string): Promise<number> {
  const result = await callSupabaseCompanyAction<{ payout: number }>('company_collect', companyId);
  return result.payout;
}

export async function buyProperty(
  _uid: string,
  name: string,
  type: PropertyType
): Promise<void> {
  const cleanName = name.trim();
  if (cleanName.length < 2 || cleanName.length > 48) throw new Error('INVALID_NAME');
  if (!PROPERTY_SPECS.some((property) => property.type === type)) throw new Error('INVALID_PROPERTY_TYPE');
  await nexoraApi('buy_property', { name: cleanName, propertyType: type });
}

export async function togglePropertyLease(_uid: string, propertyId: string, nextState: boolean): Promise<void> {
  await nexoraApi('toggle_property_lease', { propertyId, nextState });
}

export async function upgradeProperty(_uid: string, propertyId: string): Promise<void> {
  await nexoraApi('upgrade_property', { propertyId });
}

export async function collectPropertyRent(_uid: string, propertyId: string): Promise<number> {
  const result = await nexoraApi<{ payout: number }>('collect_property_rent', { propertyId });
  return result.payout;
}

export async function claimMissionReward(_uid: string, missionId: string): Promise<void> {
  if (!MISSIONS.some((mission) => mission.id === missionId)) throw new Error('INVALID_MISSION');
  try {
    await nexoraApi('claim_mission_reward', { missionId });
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw new Error(String((error as { code?: unknown }).code ?? 'MISSION_CLAIM_FAILED'));
    throw error;
  }
}
export async function createOrganization(
  _uid: string,
  _username: string,
  name: string,
  tag: string,
  description: string
): Promise<string> {
  const cleanName = name.trim();
  const cleanTag = tag.trim().toUpperCase();
  if (cleanName.length < 3 || cleanName.length > 40) throw new Error('INVALID_NAME');
  if (cleanTag.length < 2 || cleanTag.length > 6) throw new Error('INVALID_TAG');
  const result = await nexoraApi<{ orgId: string }>('create_organization', {
    name: cleanName,
    tag: cleanTag,
    description: description.trim().slice(0, 240),
  });
  if (!result.orgId) throw new Error('ORGANIZATION_CREATE_FAILED');
  return result.orgId;
}

export async function requestJoinOrganization(
  uid: string,
  username: string,
  orgId: string
): Promise<void> {
  const reqId = `${orgId}_${uid}_${Date.now()}`;
  try {
    const [profileSnap, existingReqsSnap] = await Promise.all([
      getDoc(doc(db, 'profiles', uid)),
      getDocs(query(collection(db, 'organization_requests'), where('uid', '==', uid))),
    ]);
    if (profileSnap.exists()) {
      const p = profileSnap.data() as PlayerProfile;
      if (p.orgId) throw new Error('ALREADY_IN_ORG');
    }
    const alreadyPending = existingReqsSnap.docs.some((d) => {
      const data = d.data() as { orgId?: string; status?: string };
      return data.orgId === orgId && data.status === 'pending';
    });
    if (alreadyPending) {
      throw new Error('REQUEST_ALREADY_PENDING');
    }

    await setDoc(doc(db, 'organization_requests', reqId), {
      id: reqId,
      orgId,
      uid,
      username,
      status: 'pending',
      createdAt: serverTimestamp(),
    });
  } catch (error) {
    if (error instanceof Error && ['ALREADY_IN_ORG', 'REQUEST_ALREADY_PENDING'].includes(error.message)) {
      throw error;
    }
    handleFirestoreError(error, OperationType.CREATE, `organization_requests/${reqId}`);
  }
}

export async function handleOrgJoinRequest(
  orgId: string,
  reqId: string,
  applicantUid: string,
  applicantUsername: string,
  decision: 'approved' | 'rejected'
): Promise<void> {
  try {
    await runTransaction(db, async (tx) => {
      const reqRef = doc(db, 'organization_requests', reqId);
      const orgRef = doc(db, 'organizations', orgId);
      const memberRef = doc(db, 'organization_members', `${orgId}_${applicantUid}`);
      const applicantProfileRef = doc(db, 'profiles', applicantUid);

      const [reqSnap, orgSnap, memberSnap, applicantProfileSnap] = await Promise.all([
        tx.get(reqRef),
        tx.get(orgRef),
        tx.get(memberRef),
        tx.get(applicantProfileRef),
      ]);
      if (!reqSnap.exists() || !orgSnap.exists()) throw new Error('NOT_FOUND');

      const reqData = reqSnap.data() as { status: string };
      if (reqData.status !== 'pending') {
        throw new Error('REQUEST_ALREADY_HANDLED');
      }

      if (decision === 'approved') {
        const org = orgSnap.data() as Organization;
        if (memberSnap.exists()) {
          throw new Error('ALREADY_ORG_MEMBER');
        }
        if (applicantProfileSnap.exists()) {
          const applicantProfile = applicantProfileSnap.data() as PlayerProfile;
          if (applicantProfile.orgId && applicantProfile.orgId !== orgId) {
            throw new Error('APPLICANT_IN_OTHER_ORG');
          }
        }
        const memberCapacity = typeof org.memberCapacity === 'number' ? org.memberCapacity : Math.min(70, 20 + (Math.max(1, org.level) - 1) * 5);
        if (org.memberCount >= memberCapacity) {
          throw new Error('ORG_FULL');
        }

        tx.update(reqRef, { status: decision });
        tx.set(memberRef, {
          orgId,
          uid: applicantUid,
          username: applicantUsername,
          role: 'member',
          permissions: ROLE_DEFAULT_PERMISSIONS.member,
          joinedAt: serverTimestamp(),
        });
        tx.update(orgRef, {
          memberCount: org.memberCount + 1,
          updatedAt: serverTimestamp(),
        });
      } else {
        tx.update(reqRef, { status: decision });
      }
    });
  } catch (error) {
    if (
      error instanceof Error &&
      [
        'NOT_FOUND',
        'REQUEST_ALREADY_HANDLED',
        'ALREADY_ORG_MEMBER',
        'APPLICANT_IN_OTHER_ORG',
        'ORG_FULL',
      ].includes(error.message)
    ) {
      throw error;
    }
    handleFirestoreError(error, OperationType.UPDATE, `organization_requests/${reqId}`);
  }
}

export async function syncSelfOrgMembership(uid: string, orgId: string | null): Promise<void> {
  try {
    await updateDoc(doc(db, 'profiles', uid), {
      orgId,
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.UPDATE, `profiles/${uid}`);
  }
}

export async function updateOrgMemberRole(
  orgId: string,
  targetUid: string,
  newRole: Exclude<OrgRole, 'leader'>
): Promise<void> {
  try {
    await updateDoc(doc(db, 'organization_members', `${orgId}_${targetUid}`), {
      role: newRole,
      permissions: ROLE_DEFAULT_PERMISSIONS[newRole],
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.UPDATE, `organization_members/${orgId}_${targetUid}`);
  }
}

export async function leaveOrganization(uid: string, orgId: string): Promise<void> {
  try {
    await runTransaction(db, async (tx) => {
      const orgRef = doc(db, 'organizations', orgId);
      const memberRef = doc(db, 'organization_members', `${orgId}_${uid}`);
      const profileRef = doc(db, 'profiles', uid);
      const [orgSnap, memberSnap] = await Promise.all([tx.get(orgRef), tx.get(memberRef)]);
      if (!orgSnap.exists() || !memberSnap.exists()) throw new Error('NOT_FOUND');
      const member = memberSnap.data() as OrganizationMember;
      if (member.role === 'leader') throw new Error('LEADER_CANNOT_LEAVE');

      const org = orgSnap.data() as Organization;
      tx.delete(memberRef);
      tx.update(orgRef, {
        memberCount: Math.max(1, org.memberCount - 1),
        updatedAt: serverTimestamp(),
      });
      tx.update(profileRef, {
        orgId: null,
        updatedAt: serverTimestamp(),
      });
    });
  } catch (error) {
    if (error instanceof Error && error.message === 'LEADER_CANNOT_LEAVE') throw error;
    handleFirestoreError(error, OperationType.DELETE, `organization_members/${orgId}_${uid}`);
  }
}

export async function kickOrgMember(
  actorUid: string,
  orgId: string,
  targetUid: string
): Promise<void> {
  if (!actorUid || actorUid === targetUid) throw new Error('CANNOT_KICK_SELF');

  try {
    await runTransaction(db, async (tx) => {
      const orgRef = doc(db, 'organizations', orgId);
      const actorRef = doc(db, 'organization_members', `${orgId}_${actorUid}`);
      const targetRef = doc(db, 'organization_members', `${orgId}_${targetUid}`);
      const [orgSnap, actorSnap, targetSnap] = await Promise.all([
        tx.get(orgRef),
        tx.get(actorRef),
        tx.get(targetRef),
      ]);

      if (!orgSnap.exists() || !actorSnap.exists() || !targetSnap.exists()) {
        throw new Error('NOT_FOUND');
      }

      const actor = actorSnap.data() as OrganizationMember;
      const target = targetSnap.data() as OrganizationMember;
      if (!hasOrgPermission(actor, 'manage_members')) throw new Error('UNAUTHORIZED');
      if (!canManageOrgMember(actor.role, target.role)) throw new Error('RANK_TOO_HIGH');

      const org = orgSnap.data() as Organization;
      tx.delete(targetRef);
      tx.update(orgRef, {
        memberCount: Math.max(1, org.memberCount - 1),
        updatedAt: serverTimestamp(),
      });
    });
  } catch (error) {
    if (
      error instanceof Error &&
      ['CANNOT_KICK_SELF', 'NOT_FOUND', 'UNAUTHORIZED', 'RANK_TOO_HIGH'].includes(error.message)
    ) {
      throw error;
    }
    handleFirestoreError(error, OperationType.DELETE, `organization_members/${orgId}_${targetUid}`);
  }
}

export async function upgradeOrganization(
  _uid: string,
  _username: string,
  orgId: string
): Promise<{ targetLevel: number; endsAt: number; cost: number }> {
  const result = await nexoraApi<{ target_level: number; ends_at: string; cost: number }>('organization_upgrade', { orgId });
  return {
    targetLevel: Number(result.target_level),
    endsAt: new Date(result.ends_at).getTime(),
    cost: Number(result.cost),
  };
}

export async function completeOrganizationUpgrade(orgId: string): Promise<void> {
  await nexoraApi('organization_complete', { orgId });
}

export async function researchOrganization(
  orgId: string,
  researchId: 'commerce' | 'engineering' | 'expansion' | 'finance' | 'diplomacy'
): Promise<{ level: number; cost: number }> {
  const result = await nexoraApi<{ level: number; cost: number }>('organization_research', { orgId, researchId });
  return { level: Number(result.level), cost: Number(result.cost) };
}

export async function depositToOrgTreasury(
  uid: string,
  username: string,
  orgId: string,
  amountRaw: number
): Promise<void> {
  const amount = Math.floor(amountRaw);
  if (!Number.isFinite(amountRaw) || amount <= 0 || amount > 10_000_000) throw new Error('INVALID_AMOUNT');
  const txId = genId('tx');
  const orgTxId = genId('otx');

  try {
    await runTransaction(db, async (tx) => {
      const walletRef = doc(db, 'wallets', uid);
      const orgRef = doc(db, 'organizations', orgId);
      const memberRef = doc(db, 'organization_members', `${orgId}_${uid}`);
      const [walletSnap, orgSnap, memberSnap] = await Promise.all([tx.get(walletRef), tx.get(orgRef), tx.get(memberRef)]);
      if (!walletSnap.exists() || !orgSnap.exists()) throw new Error('NOT_FOUND');
      if (!memberSnap.exists()) throw new Error('UNAUTHORIZED');

      const wallet = walletSnap.data() as Wallet;
      const org = orgSnap.data() as Organization;
      if (wallet.balance < amount) throw new Error('INSUFFICIENT_FUNDS');

      tx.set(doc(db, 'transactions', txId), {
        id: txId,
        fromUid: uid,
        toUid: 'ORG',
        amount,
        fee: 0,
        netAmount: amount,
        type: 'org_deposit',
        referenceId: orgId,
        description: `Org treasury deposit [${org.tag}]`,
        status: 'completed',
        createdAt: serverTimestamp(),
      });

      tx.update(walletRef, {
        balance: wallet.balance - amount,
        totalSpent: wallet.totalSpent + amount,
        lastTxId: txId,
        updatedAt: serverTimestamp(),
      });

      tx.update(orgRef, {
        treasuryBalance: org.treasuryBalance + amount,
        reputation: org.reputation + Math.max(1, Math.floor((amount / 100) * (1 + Math.min(10, org.research?.diplomacy ?? 0) * 0.01))),
        updatedAt: serverTimestamp(),
      });

      tx.set(doc(db, 'organization_transactions', orgTxId), {
        id: orgTxId,
        orgId,
        uid,
        username,
        type: 'deposit',
        amount,
        note: `Deposit by ${username}`,
        createdAt: serverTimestamp(),
      });
    });
  } catch (error) {
    if (error instanceof Error && ['INVALID_AMOUNT', 'INSUFFICIENT_FUNDS', 'UNAUTHORIZED'].includes(error.message)) {
      throw error;
    }
    handleFirestoreError(error, OperationType.WRITE, `organizations/${orgId}`);
  }
}

export async function withdrawFromOrgTreasury(
  uid: string,
  username: string,
  orgId: string,
  amountRaw: number
): Promise<void> {
  const amount = Math.floor(amountRaw);
  if (!Number.isFinite(amountRaw) || amount <= 0 || amount > 10_000_000) throw new Error('INVALID_AMOUNT');
  const txId = genId('tx');
  const orgTxId = genId('otx');

  try {
    await runTransaction(db, async (tx) => {
      const walletRef = doc(db, 'wallets', uid);
      const orgRef = doc(db, 'organizations', orgId);
      const memberRef = doc(db, 'organization_members', `${orgId}_${uid}`);
      const [walletSnap, orgSnap, memberSnap] = await Promise.all([tx.get(walletRef), tx.get(orgRef), tx.get(memberRef)]);
      if (!walletSnap.exists() || !orgSnap.exists()) throw new Error('NOT_FOUND');
      if (!memberSnap.exists() || !hasOrgPermission(memberSnap.data() as OrganizationMember, 'manage_treasury')) {
        throw new Error('UNAUTHORIZED');
      }

      const wallet = walletSnap.data() as Wallet;
      const org = orgSnap.data() as Organization;
      if (org.treasuryBalance < amount) throw new Error('INSUFFICIENT_TREASURY');

      tx.set(doc(db, 'transactions', txId), {
        id: txId,
        fromUid: 'ORG',
        toUid: uid,
        amount,
        fee: 0,
        netAmount: amount,
        type: 'org_withdraw',
        referenceId: orgId,
        description: `Org treasury withdrawal [${org.tag}]`,
        status: 'completed',
        createdAt: serverTimestamp(),
      });

      tx.update(walletRef, {
        balance: wallet.balance + amount,
        totalEarned: wallet.totalEarned + amount,
        lastTxId: txId,
        updatedAt: serverTimestamp(),
      });

      tx.update(orgRef, {
        treasuryBalance: org.treasuryBalance - amount,
        updatedAt: serverTimestamp(),
      });

      tx.set(doc(db, 'organization_transactions', orgTxId), {
        id: orgTxId,
        orgId,
        uid,
        username,
        type: 'withdraw',
        amount,
        note: `Withdrawal by ${username}`,
        createdAt: serverTimestamp(),
      });
    });
  } catch (error) {
    if (error instanceof Error && ['INVALID_AMOUNT', 'INSUFFICIENT_TREASURY', 'UNAUTHORIZED'].includes(error.message)) {
      throw error;
    }
    handleFirestoreError(error, OperationType.WRITE, `organizations/${orgId}`);
  }
}

export async function updatePlayerSettings(
  _uid: string,
  language: Language,
  notificationsEnabled: boolean
): Promise<void> {
  await nexoraApi('update_settings', { language, notificationsEnabled });
}

export async function updatePlayerAvatar(_uid: string, avatarId: string): Promise<void> {
  await nexoraApi('update_avatar', { avatarId });
}

export async function markNotificationRead(notifId: string): Promise<void> {
  await nexoraApi('mark_notification_read', { notificationId: notifId });
}

export async function markAllNotificationsRead(_notifIds: string[]): Promise<void> {
  await nexoraApi('mark_all_notifications_read');
}

export async function fetchLeaderboards(): Promise<{
  players: PlayerProfile[];
  companies: Company[];
  organizations: Organization[];
}> {
  const [pSnap, cSnap, oSnap] = await Promise.all([
    getDocs(query(collection(db, 'profiles'), where('influence', '>=', 0), orderBy('influence', 'desc'), limit(20))),
    getDocs(query(collection(db, 'companies'), where('totalRevenue', '>=', 0), orderBy('totalRevenue', 'desc'), limit(20))),
    getDocs(query(collection(db, 'organizations'), where('reputation', '>=', 0), orderBy('reputation', 'desc'), limit(20))),
  ]);

  return {
    players: pSnap.docs.map((d) => d.data() as PlayerProfile),
    companies: cSnap.docs.map((d) => d.data() as Company),
    organizations: oSnap.docs.map((d) => d.data() as Organization),
  };
}

export async function checkAndUnlockAchievements(
  uid: string,
  profile: PlayerProfile,
  unlockedIds: Set<string>,
  achievements: {
    id: string;
    metric: 'trades' | 'companies' | 'properties' | 'produced' | 'level' | 'reputation';
    threshold: number;
  }[]
): Promise<string[]> {
  const eligible = achievements.filter((ach) => {
    if (unlockedIds.has(ach.id)) return false;
    return getAchievementProgress(ach.metric, profile) >= ach.threshold;
  });

  if (eligible.length === 0) return [];

  const unlockedNow: string[] = [];
  await Promise.allSettled(
    eligible.map(async (ach) => {
      const docId = `${uid}_${ach.id}`;
      await setDoc(doc(db, 'player_achievements', docId), {
        uid,
        achievementId: ach.id,
        unlockedAt: serverTimestamp(),
      });
      unlockedNow.push(ach.id);
    })
  );
  return unlockedNow;
}

export async function fetchOrgPendingRequests(orgId: string) {
  const q = query(
    collection(db, 'organization_requests'),
    where('orgId', '==', orgId),
    where('status', '==', 'pending')
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => d.data());
}
