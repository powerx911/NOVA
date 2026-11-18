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
import { useGameData } from './hooks/useGameData';
import type { MainTab } from './types/game';

function NexoraAppContent() {
  const game = useGameData();
  const [activeTab, setActiveTab] = useState<MainTab>('home');

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
      profile={game.profile}
      wallet={game.wallet}
      notifications={game.notifications}
      language={game.language}
    >
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
          worldEvents={game.worldEvents}
          marketListings={game.marketListings}
          language={game.language}
          onNavigate={setActiveTab}
        />
      )}

      {activeTab === 'business' && (
        <BusinessHubView
          profile={game.profile}
          wallet={game.wallet}
          companies={game.companies}
          companyLogs={game.companyLogs}
          properties={game.properties}
          inventory={game.inventory}
          worldEvents={game.worldEvents}
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
          marketOrders={game.marketOrders}
          transactions={game.transactions}
          worldEvents={game.worldEvents}
          claimedContractsToday={game.claimedContractsToday}
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

      {activeTab === 'profile' && (
        <ProfileHubView
          profile={game.profile}
          userPrivate={game.userPrivate}
          claimedMissions={game.claimedMissions}
          unlockedAchievements={game.unlockedAchievements}
          diagnosticsContext={{
            profile: game.profile,
            wallet: game.wallet,
            myOrgMember: game.myOrgMember,
            companiesCount: game.companies.length,
            propertiesCount: game.properties.length,
            inventoryCount: game.inventory.length,
            claimedMissionsCount: game.claimedMissions.length,
            unlockedAchievementsCount: game.unlockedAchievements.size,
            locale: game.language,
          }}
          language={game.language}
          onLanguageChange={game.setLanguageLocal}
          onLogout={game.logout}
        />
      )}
    </AppShell>
  );
}

export default function App() {
  return (
    <ToastProvider>
      <GameAudioFeedback />
      <GameMusic />
      <NexoraAppContent />
    </ToastProvider>
  );
}
