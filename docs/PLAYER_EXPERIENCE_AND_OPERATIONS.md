# NOVA — Player Experience, Alliance Operations & Live Operations

**Status:** Product requirements and operating model; not yet implemented  
**Date:** 2026-11-18

Every major feature must pass two reviews: (1) the owner/operator view—can NOVA be operated safely, fairly, and sustainably worldwide? (2) the player view—does it make play clearer, easier, more exciting, more social, or more rewarding to master?

A feature needs a real player problem, a clear benefit, quality criteria, and an operational owner. Do not add features just to match a competitor.

## 1. Player journey: reasons to start, stay, and return

### First minutes
- Explain the world and first meaningful objective in concise localized language.
- Teach one action at a time in context; allow skipping or replaying guidance.
- Get to a meaningful decision quickly; avoid long compulsory text tours.
- Provide a protected starter position, useful starting resources, and a clear first strategic choice.
- Show the next recommended action and why it matters.
- Introduce alliance discovery gently: language, activity, recruitment state, goals, and request-to-join.
- Explain account protection, mute/block/report, and support access.

### First session
The first session must demonstrate a real loop: choose a goal → allocate resources → start a useful action → see progress/result → understand the next unlock. The final loop depends on the game model.
- Explain costs, timers, capacity, and consequences before confirmation.
- Give honest feedback for success, failure, queued actions, and interrupted network.
- Avoid irreversible early mistakes; provide undo/cancel where safe.
- End on a visible milestone and a meaningful next goal.

### Multi-horizon progression

| Horizon | Motivation | Systems to evaluate |
|---|---|---|
| Moment-to-moment | A useful choice now | Resource allocation, tactical orders, trade |
| One session | Finish a task | Upgrade, scouting, training, alliance contribution |
| Daily/weekly | Steady progress | Optional rotating objectives, cooperation challenges |
| Season | Compete and specialize | Rankings, territory objectives, world events |
| Multi-season | Identity and legacy | Titles, historical records, mastery collections, alliance legacy |
| Community | Belonging | Alliance goals, diplomacy, shared projects, world milestones |

Avoid a checklist treadmill. Offer choice and different play styles. Do not punish healthy breaks or make daily attendance mandatory. Rewards should reinforce mastery, identity, and strategic options—not create manipulative pressure.

### Return briefing
On return, show a prioritized summary: completed actions and outcomes; messages and friend requests; alliance invitations and decisions; world events; upcoming deadlines; and actions requiring attention. Include category-based notification controls, quiet hours, and opt-outs. Do not use deceptive urgency.

## 2. Player quality-of-life

Prioritize friction removal:
- Search across players, alliances, messages, and market listings, with permission/privacy filters.
- Filters, sorting, favorites, recent items, and saved views for long lists.
- Cost previews, capacity indicators, time estimates, and consequence previews.
- Action queues with progress, notifications, safe cancellation, and reconnect recovery.
- Command history and transaction receipts showing where resources went.
- Searchable message history, unread markers, conversation mute, block, and report.
- Alliance directory with member roles, contribution, privacy-aware activity, and contact shortcuts.
- Invitation/request inbox with expiry, status, accept, and decline.
- Contextual help and searchable knowledge base.
- Text size, contrast, language, sound/music, reduced-motion, and low-data settings.
- Reliable reconnect, duplicate-action prevention, and clear retry messaging.
- Confirm high-impact actions with target and consequence previews; avoid needless confirmations for harmless actions.

## 3. Alliance management: an organization, not just a tag

### Discovery, invitations, applications
- Directory with language, recruitment state, activity, capacity, goals, and public achievements.
- Join requests with optional message, status, expiry, and cancellation.
- Invite players by search or shareable invite code/link.
- Settings for who can invite, open applications, approval rules, expiry, pending-request limits, and eligibility where justified.
- Rate limits, cooldowns, duplicate detection, and block-aware restrictions.
- Welcome flow explaining rules, objectives, communication channels, and first contribution.

### Roles and permissions
Potential defaults: founder, leader, officer/deputy, diplomat, quartermaster/economy officer, military commander, recruit, member. Roles are labels; permissions are the actual security boundary.

Granular permissions may include:
- Invite, approve, reject, remove, and moderate alliance members.
- Edit alliance profile, emblem, recruitment, rules, and channels.
- Publish announcements.
- Propose/accept/end diplomacy.
- Propose/vote/declare war under game rules.
- Create military operations and assign objectives.
- View treasury/ledger; propose or approve transfers.
- Manage projects and contribution rewards.
- Grant/revoke roles and delegate authority.

Every command must be checked server-side against current membership and permission state. Hiding a button is not authorization.

### Settings and governance
- Name, emblem, description, language, recruitment, visibility, capacity, and join policy.
- Charter/rules, pinned announcements, and role descriptions.
- Leadership succession and recovery for inactive/departed leaders.
- Optional multi-officer approval for high-value treasury transfers and irreversible decisions.
- Transparent logs for membership, role changes, diplomacy, treasury, and military orders.
- Contribution records resistant to spam and easy farming.
- Inactivity/dissolution rules with advance notice and protection of shared assets.

### Fair member removal
- Only authorized roles may remove a member.
- Require a reason category and optional note for high-impact removals; notify the affected player without exposing private staff notes.
- Log actor, target, timestamp, reason, and relevant alliance state.
- Define rejoin cooldowns and an appeal path; prevent harassment, retaliation, and arbitrary confiscation.
- Founder removal, succession, and dissolution need stronger safeguards than ordinary member removal.
- Never silently erase legitimate player-owned assets or transaction history.

## 4. Global communication and community
- Distinguish global, alliance, officer, and private conversation visibility.
- Show language/channel context and allow muting noisy rooms.
- Attach reported message and limited surrounding context securely to reports.
- Rate-limit spam, links, repeated content, invitations, and suspicious account patterns.
- Protect new accounts from unsolicited contact where practical.
- Blocks must prevent alternate in-game routes for unwanted contact.
- Never reveal reporter identity to the reported player.
- Official announcements and maintenance notices require verified sender identity.
- Persist chat history, moderation evidence, and unread state with strict permissions; realtime delivery is transport only.

## 5. Player support and help center

### Self-service and tickets
- Searchable help for account access, rules, alliances, trade, battles, privacy, chat, and known issues.
- Contextual help from the screen where a player gets stuck.
- Support ticket with category, concise description, optional safe attachment, and generated ticket ID.
- Ticket states: received, waiting for player, under review, escalated, resolved, closed.
- In-game ticket history, status, and notifications.
- Allow players to add information and appeal/reopen within a documented window.
- Separate bug reports, account recovery, moderation appeals, and gameplay questions.
- Publish response expectations honestly; never promise 24/7 support unless staffed.

### Support workflow
- Search by stable internal player ID and ticket ID, not display name alone.
- Show only data needed for the case; internal notes remain private.
- Use response templates with relevant personalized guidance.
- Escalate account security, harassment, exploits, and privacy requests to specialists.
- Audit status changes and staff actions.
- Never ask for passwords, one-time codes, secret tokens, or full payment credentials.
- Account recovery follows verified authentication processes, never a chat-only claim.

## 6. Staff administration and moderator tools

A global game needs a secure internal console separate from the player client.

### Least-privilege staff roles
Potential roles: platform owner/superadmin, game operations admin, community moderator, senior moderator/appeals reviewer, support agent, economy/live-balance analyst, content/event editor, read-only auditor.

Use strong authentication, individual accounts, least privilege, short-lived elevation where supported, and separate development/staging/production environments. Never share staff accounts.

### Moderator workspace
- Prioritized report queue with severity, age, state, assignment, and escalation.
- Context view limited to relevant reported content, nearby messages, timestamps, policy category, and upheld prior actions.
- Policy-based actions: warn, remove content, temporary chat restriction, temporary suspension, permanent ban, or no action.
- Record duration, reason, evidence reference, and appeal eligibility.
- Keep private moderator notes access-controlled and audited.
- Serious sanctions should receive independent appeal review where staffing allows.
- Emergency actions require reasons and retrospective review.

### Admin control plane
- Search players, alliances, reports, tickets, events, and incidents by stable ID.
- View system health and queues without exposing secrets.
- Manage official announcements, maintenance, known issues, and event configuration.
- Inspect economy ledgers and battle receipts for disputes; never silently edit balances.
- Issue compensation only through audited, reasoned, idempotent grant commands with limits and approval for high-value grants.
- Pause an exploit-affected market, event, or command safely while preserving evidence and communicating status.
- Provide read-only audit views for sensitive changes.

### High-risk staff actions
- Require reason and audit record for bans, account restrictions, role grants, balance adjustments, resets, and event changes.
- Require a second approver for destructive/high-value production actions where practical.
- Separate moderation from economy administration where possible.
- Moderators must not directly edit balances, alliance treasuries, or battle outcomes.
- Log actor, action, target, time, reason, before/after reference, and approval chain.
- Prefer rollback/compensation over deleting audit history.

## 7. Retention, live operations, and world health

- Maintain a cadence the team can reliably deliver: small fixes and balance corrections, regular community updates, recurring alliance/world events, and larger seasonal/permanent updates.
- Every event needs an objective, eligibility, duration, reward rules, anti-exploit checks, player communication, support plan, and post-event review.
- New-player protection and catch-up paths prevent permanent veteran domination.
- Multiple contribution paths should exist: economy, diplomacy, scouting, logistics, defense, leadership, and combat.
- Recovery after defeat prevents one battle ending a player's story.
- Seasonal recognition and historical records preserve identity without locking all power behind veterans.
- Manage alliance population/activity to discourage monopolies and dead-world fragmentation.
- Design conflict windows/asynchronous orders for fair participation across time zones.
- Prepare for bots, multi-account abuse, collusion, market manipulation, and exploit response.
- Provide feedback channels, public changelog, and roadmap.
- Collect only minimum operational information. Personal-data analytics/telemetry require separate approval; prefer aggregated privacy-preserving measures.
- Do not optimize only for session length or daily attendance; evaluate fairness, satisfaction, social health, new-player success, and support burden.

## 8. Feature acceptance questions

1. What player problem or desire does this solve?
2. What becomes easier, clearer, fairer, or more exciting?
3. Does it create a meaningful short-, medium-, or long-term goal?
4. Does it connect to the core social/economic/diplomatic/military loop?
5. What happens on disconnect, retry, or concurrent actions?
6. What permissions, audit, moderation, and abuse controls are required?
7. How does a new player experience it versus a veteran?
8. What are loading, empty, error, offline, denied, and recovery states?
9. Can it be explained clearly in Arabic and English on a small Android screen?
10. What evidence would show that it improved the experience?

If it fails these questions, redesign or defer it.

## 9. Research references
- Roblox Creator Hub, Onboarding: https://create.roblox.com/docs/production/game-design/onboarding
- Meta Horizon OS Developers, Live Service Checklist (2026): https://developers.meta.com/vr/blog/live-services-checklist-five-pillars-for-building-successful-games/
- Roblox Creator Hub, LiveOps Essentials: https://create.roblox.com/docs/production/game-design/liveops-essentials
- Ofcom, Interactive Services Model: https://www.ofcom.org.uk/siteassets/resources/documents/research-and-data/online-research/interactive-services-model/interactive-services-model?v=329476
- Fair Play Alliance / ADL, Disruption and Harms in Online Gaming Framework: https://www.adl.org/sites/default/files/fpa-framework-building-penalty-reporting-121520-1335.pdf
