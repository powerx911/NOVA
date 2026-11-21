/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useState } from 'react';
import { AppShell } from './components/ui/AppShell';
import { GameAudioFeedback } from './components/ui/GameAudioFeedback';
import { GameMusic } from './components/ui/GameMusic';
import { VersionUpdateNotice } from './components/ui/VersionUpdateNotice';
import { ToastProvider } from './components/ui/ToastProvider';
import { AuthOnboardingView } from './features/auth/AuthOnboardingView';
import { BusinessHubView } from './features/business/BusinessHubView';
import { HomeDashboardView } from './features/home/HomeDashboardView';
import { MarketHubView } from './features/market/MarketHubView';
import { OrganizationHubView } from './features/organization/OrganizationHubView';
import { ProfileHubView } from './features/profile/ProfileHubView';
import { SocialHubView } from './features/social/SocialHubView';
import { useGameData } from './hooks/useGameData';
import type { MainTab, ProfileSubTab } from './types/game';

function NovaAppContent() {
  const game = useGameData();
  const [activeTab, setActiveTab] = useState<MainTab>('home');
  const [profileInitialSubTab, setProfileInitialSubTab] = useState<ProfileSubTab>('overview');
  const [socialUnreadCount, setSocialUnreadCount] = useState(0);

  if (!game.authReady || (game.authUser && game.profileLoading)) {
    return (
      <div className="min-h-screen bg-[#0B0D12] flex items-center justify-center p-6">
        <div className="w-full max-w-sm space-y-4">
          <div className="h-12 rounded-2xl bg-[#141821] animate-pulse" />
          <div className="h-36 rounded-2xl bg-[#141821] animate-pulse" />
          <div className="h-24 rounded-2xl bg-[#141821] animate-pulse" />
        </div>
      </div>
    );
  }

  if (game.authUser && !game.profile && game.profileLoadError) {
    return (
      <div className="min-h-screen bg-[#0B0D12] text-[#F4F5F7] flex items-center justify-center p-6">
        <div className="w-full max-w-md rounded-2xl border border-amber-500/25 bg-[#141821] p-6 space-y-4 text-center">
          <div className="mx-auto h-12 w-12 rounded-full bg-amber-500/10 flex items-center justify-center text-amber-300 text-xl">!</div>
          <h1 className="text-lg font-bold">تعذر تحميل بيانات حسابك</h1>
          <p className="text-sm leading-7 text-[#AAB1BE]">
            لم نتمكن من الاتصال ببيانات اللعبة. تقدمك لم يُحذف، ولن نطلب منك إنشاء شخصية جديدة قبل التأكد من تحميل حسابك.
          </p>
          <button
            type="button"
            onClick={game.retryProfileLoad}
            className="w-full min-h-[46px] rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-sm font-semibold"
          >
            إعادة المحاولة
          </button>
        </div>
      </div>
    );
  }

  if (!game.authUser) {
    return (
      <AuthOnboardingView
        mode="signin"
        language={game.language}
        onLanguageChange={game.setLanguageLocal}
        onLogin={game.loginWithGoogle}
        onLoginWithEmail={game.loginWithEmail}
        onRegisterWithEmail={game.registerWithEmail}
        onGuestLogin={game.loginAsGuest}
        onBack={game.logout}
      />
    );
  }

  if (!game.profile) {
    return (
      <AuthOnboardingView
        mode="onboarding"
        uid={game.authUser.uid}
        email={game.authUser.email || ''}
        language={game.language}
        onLanguageChange={game.setLanguageLocal}
        onLogin={game.loginWithGoogle}
        onLoginWithEmail={game.loginWithEmail}
        onRegisterWithEmail={game.registerWithEmail}
        onGuestLogin={game.loginAsGuest}
        onBack={game.logout}
        isGuest={game.authUser.isAnonymous}
      />
    );
  }

  return (
    <AppShell
      activeTab={activeTab}
      onTabChange={setActiveTab}
      socialUnreadCount={socialUnreadCount}
      unclaimedAchievementCount={[...game.unlockedAchievements].filter((id) => !game.claimedAchievements.has(id)).length}
      dailyStipendReady={!game.claimedDailyToday}
      profile={game.profile}
      wallet={game.wallet}
      notifications={game.notifications}
      language={game.language}
    >
      <GameMusic />
      <VersionUpdateNotice />

      {!game.isOnline && (
        <div className="mb-4 px-4 py-2.5 rounded-xl bg-amber-500/10 border border-amber-500/30 text-xs text-amber-200">
          {game.language === 'ar'
            ? 'لا يوجد اتصال بالإنترنت حالياً — ستتم مزامنة العمليات عند عودة الاتصال.'
            : 'Currently offline — actions will resume syncing once connection is restored.'}
        </div>
      )}

      {activeTab === 'home' && (
        <HomeDashboardView
          profile={game.profile}
          wallet={game.wallet}
          transactions={game.transactions}
          claimedMissions={game.claimedMissions}
          claimedDailyToday={game.claimedDailyToday}
          notifications={game.notifications}
          worldEvents={game.worldEvents}
          marketListings={game.marketListings}
          language={game.language}
          onNavigate={setActiveTab}
          onOpenMissions={() => { setProfileInitialSubTab('missions'); setActiveTab('profile'); }}
        />
      )}

      {activeTab === 'business' && (
        <BusinessHubView
          profile={game.profile}
          wallet={game.wallet}
          companies={game.companies}
          factories={game.factories}
          companyLogs={game.companyLogs}
          inventory={game.inventory}
          marketListings={game.marketListings}
          worldEvents={game.worldEvents}
          notifications={game.notifications}
          organizationIncomeBonusRate={Math.min(10, game.organizations.find((org) => org.id === game.profile?.orgId)?.research?.commerce ?? 0) * 0.005}
          language={game.language}
          onGoToMarket={() => setActiveTab('market')}
        />
      )}

      {activeTab === 'market' && (
        <MarketHubView
          profile={game.profile}
          wallet={game.wallet}
          inventory={game.inventory}
          marketListings={game.marketListings}
          worldEvents={game.worldEvents}
          notifications={game.notifications}
          language={game.language}
        />
      )}

      {activeTab === 'organization' && (
        <OrganizationHubView
          profile={game.profile}
          wallet={game.wallet}
          organizations={game.organizations}
          myOrgMember={game.myOrgMember}
          orgMembers={game.orgMembers}
          orgRequests={game.orgRequests}
          myPendingOrgIds={game.myPendingOrgIds}
          orgTransactions={game.orgTransactions}
          language={game.language}
        />
      )}

      <div className={activeTab === 'social' ? '' : 'hidden'} aria-hidden={activeTab !== 'social'}>
        <SocialHubView profile={game.profile} myOrgMember={game.myOrgMember} organizations={game.organizations} language={game.language} onUnreadCountChange={setSocialUnreadCount} />
      </div>

      {activeTab === 'profile' && (
        <ProfileHubView
          profile={game.profile}
          wallet={game.wallet}
          userPrivate={game.userPrivate}
          claimedMissions={game.claimedMissions}
          unlockedAchievements={game.unlockedAchievements}
          claimedAchievements={game.claimedAchievements}
          notifications={game.notifications}
          diagnosticsContext={{
            profile: game.profile,
            wallet: game.wallet,
            myOrgMember: game.myOrgMember,
            companiesCount: game.companies.length,
            inventoryCount: game.inventory.length,
            claimedMissionsCount: game.claimedMissions.length,
            unlockedAchievementsCount: game.unlockedAchievements.size,
            locale: game.language,
          }}
          language={game.language}
          onLanguageChange={game.setLanguageLocal}
          onLogout={game.logout}
          initialSubTab={profileInitialSubTab}
        />
      )}
    </AppShell>
  );
}

export default function App() {
  return (
    <ToastProvider>
      <GameAudioFeedback />
      <NovaAppContent />
    </ToastProvider>
  );
}
