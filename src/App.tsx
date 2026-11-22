/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useCallback, useEffect, useState } from 'react';
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

const MAIN_TABS: MainTab[] = ['home', 'business', 'market', 'organization', 'social', 'profile'];

function tabFromLocation(): MainTab {
  const value = new URLSearchParams(window.location.search).get('tab');
  return MAIN_TABS.includes(value as MainTab) ? value as MainTab : 'home';
}

function NovaAppContent() {
  const game = useGameData();
  const [activeTab, setActiveTab] = useState<MainTab>(tabFromLocation);
  const navigateTab = useCallback((tab: MainTab) => {
    setActiveTab(tab);
    const url = new URL(window.location.href);
    if (tab === 'home') url.searchParams.delete('tab');
    else url.searchParams.set('tab', tab);
    window.history.pushState({ novaTab: tab }, '', url.toString());
  }, []);

  useEffect(() => {
    const handlePopState = () => setActiveTab(tabFromLocation());
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);
  const [profileInitialSubTab, setProfileInitialSubTab] = useState<ProfileSubTab>('overview');
  const [socialUnreadCount, setSocialUnreadCount] = useState(0);
  const [banClock, setBanClock] = useState(Date.now());
  useEffect(() => {
    if (!game.accountBan?.expiresAt) return;
    const timer = window.setInterval(() => setBanClock(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [game.accountBan?.expiresAt]);

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

  if (game.authUser && game.accountBan) {
    const remaining = game.accountBan.expiresAt ? Math.max(0, Math.ceil((game.accountBan.expiresAt - banClock) / 1000)) : null;
    const durationHours = game.accountBan.expiresAt && game.accountBan.createdAt ? Math.max(1, Math.round((game.accountBan.expiresAt - game.accountBan.createdAt) / 3600000)) : null;
    const durationLabel = durationHours === null ? 'دائم' : durationHours < 24 ? durationHours + ' ساعة' : durationHours % 24 === 0 ? (durationHours / 24) + ' يوم' : durationHours + ' ساعة';
    const durationPhrase = durationHours === null ? 'بشكل دائم' : 'لمدة ' + durationLabel;
    const days = remaining === null ? 0 : Math.floor(remaining / 86400);
    const hours = remaining === null ? 0 : Math.floor((remaining % 86400) / 3600);
    const minutes = remaining === null ? 0 : Math.floor((remaining % 3600) / 60);
    const seconds = remaining === null ? 0 : remaining % 60;
    const remainingLabel = remaining === null ? 'حظر دائم' : remaining <= 0 ? 'انتهت مدة الحظر' : [days ? days + ' يوم' : '', hours ? hours + ' ساعة' : '', minutes ? minutes + ' دقيقة' : '', seconds + ' ثانية'].filter(Boolean).join(' و');
    return (
      <div className="min-h-screen bg-[#0B0D12] text-[#F4F5F7] flex items-center justify-center p-6">
        <div className="w-full max-w-md rounded-2xl border border-red-500/30 bg-[#141821] p-7 space-y-5 text-center">
          <div className="mx-auto h-14 w-14 rounded-full bg-red-500/10 flex items-center justify-center text-red-300 text-2xl">!</div>
          <h1 className="text-xl font-bold">تم تبنيد حسابك</h1>
          <p className="text-sm leading-7 text-[#AAB1BE]">تم تبنيد حسابك {durationPhrase} بسبب:</p>
          <p className="rounded-xl bg-[#0B0D12] p-4 text-sm leading-7 text-red-200 whitespace-pre-wrap">{game.accountBan.reason}</p>
          <p className="text-sm text-[#F4C66A]">{remaining === null ? 'هذا الحظر دائم ولا ينتهي تلقائيًا.' : remainingLabel === 'انتهت مدة الحظر' ? 'انتهت مدة الحظر، يمكنك إعادة التحقق للدخول.' : 'المتبقي لفك الحظر: ' + remainingLabel}</p>
          <button type="button" onClick={game.retryProfileLoad} className="w-full min-h-[46px] rounded-xl bg-[#B91C32] text-white text-sm font-semibold">إعادة التحقق من حالة الحساب</button>
          <button type="button" onClick={() => void game.logout()} className="w-full min-h-[42px] rounded-xl bg-[#252B36] text-[#F4F5F7] text-sm">تسجيل الخروج</button>
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
      onTabChange={navigateTab}
      socialUnreadCount={socialUnreadCount}
      unclaimedAchievementCount={[...game.unlockedAchievements].filter((id) => !game.claimedAchievements.has(id)).length}
      dailyStipendReady={!game.claimedDailyToday}
      profile={game.profile}
      wallet={game.wallet}
      notifications={game.notifications}
      language={game.language}
    >
      <GameMusic />

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
          onNavigate={navigateTab}
          onOpenMissions={() => { setProfileInitialSubTab('missions'); navigateTab('profile'); }}
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
          onGoToMarket={() => navigateTab('market')}
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
      <VersionUpdateNotice />
      <NovaAppContent />
    </ToastProvider>
  );
}
