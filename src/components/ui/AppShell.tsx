import {
  Bell,
  Briefcase,
  Building2,
  Check,
  Coins,
  Home,
  MessageCircle,
  Store,
  User,
  X,
} from 'lucide-react';
import { AmbientSoundtrack } from './AmbientSoundtrack';
import { useState, type ReactNode } from 'react';
import { BRAND_ASSETS } from '../../data/catalog';
import { useTranslations } from '../../i18n/translations';
import {
  markAllNotificationsRead,
  markNotificationRead,
} from '../../services/gameService';
import type { GameNotification, Language, MainTab, PlayerProfile, Wallet } from '../../types/game';

interface AppShellProps {
  activeTab: MainTab;
  onTabChange: (tab: MainTab) => void;
  profile: PlayerProfile;
  wallet: Wallet | null;
  notifications: GameNotification[];
  socialUnreadCount: number;
  language: Language;
  children: ReactNode;
}

export function AppShell({
  activeTab,
  onTabChange,
  profile,
  wallet,
  notifications,
  socialUnreadCount,
  language,
  children,
}: AppShellProps) {
  const t = useTranslations(language);
  const [notifOpen, setNotifOpen] = useState(false);
  const [locallyReadIds, setLocallyReadIds] = useState<Set<string>>(new Set());
  const isRead = (notification: GameNotification) => notification.read || locallyReadIds.has(notification.id);
  const unreadCount = notifications.filter((n) => !isRead(n)).length;

  const navItems: { id: MainTab; label: string; icon: typeof Home }[] = [
    { id: 'home', label: t.navHome, icon: Home },
    { id: 'business', label: t.navBusiness, icon: Briefcase },
    { id: 'market', label: t.navMarket, icon: Store },
    { id: 'organization', label: t.navOrganization, icon: Building2 },
    { id: 'social', label: language === 'ar' ? 'التواصل' : 'Social', icon: MessageCircle },
    { id: 'profile', label: t.navProfile, icon: User },
  ];

  return (
    <div className="min-h-screen bg-[#0B0D12] text-[#F4F5F7] flex flex-col">
      {/* Compact Sticky Top Bar (< 8% mobile viewport height) */}
      <header className="sticky top-0 z-30 h-14 pt-safe bg-[#0B0D12]/90 backdrop-blur-md border-b border-white/8">
        <div className="max-w-6xl mx-auto h-full px-4 lg:px-6 flex items-center justify-between gap-4">
          {/* Zone 1: Brand wordmark + emblem */}
          <button
            type="button"
            onClick={() => onTabChange('home')}
            className="flex items-center gap-2.5 whitespace-nowrap shrink-0 focus-visible:outline-none"
          >
            <img
              src={BRAND_ASSETS.emblem}
              alt="NOVA"
              referrerPolicy="no-referrer"
              className="w-7 h-7 rounded-lg object-cover border border-white/10"
            />
            <span className="text-base font-bold tracking-tight text-[#F4F5F7]">NOVA</span>
          </button>

          {/* Desktop inline navigation */}
          <nav className="hidden lg:flex items-center gap-4">
            {navItems.map((item) => {
              const isActive = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => onTabChange(item.id)}
                  className={`py-1.5 text-sm font-medium whitespace-nowrap shrink-0 transition-colors border-b-2 ${
                    isActive
                      ? 'text-[#F4F5F7] border-[#B91C32]'
                      : 'text-[#9299A6] border-transparent hover:text-[#F4F5F7]'
                  }`}
                >
                  {item.label}{item.id === 'social' && socialUnreadCount > 0 && <span className="ms-1 inline-flex min-w-4 h-4 px-1 rounded-full bg-red-600 text-[9px] font-bold text-white items-center justify-center">{socialUnreadCount}</span>}
                </button>
              );
            })}
          </nav>

          {/* Zone 3: Level, Currency & Notifications */}
          <div className="flex items-center gap-3 shrink-0">
            <div className="flex items-center gap-2 text-xs text-[#9299A6]">
              <span className="font-mono-num text-[#F4F5F7] font-semibold">
                Lv.{profile.level}
              </span>
              <span aria-hidden="true">·</span>
              <span className="flex items-center gap-1 font-mono-num text-[#F4F5F7] font-semibold">
                <Coins className="w-3.5 h-3.5 text-[#E04455]" />
                {'$'}{(wallet?.balance ?? 0).toLocaleString()}
              </span>
            </div>

            <AmbientSoundtrack language={language} />
            <button
              type="button"
              onClick={() => setNotifOpen(true)}
              aria-label={t.notificationsTitle}
              className="relative min-h-[40px] min-w-[40px] flex items-center justify-center rounded-xl bg-[#141821] border border-white/8 text-[#F4F5F7] hover:bg-[#1B2230] transition-colors"
            >
              <Bell className="w-4 h-4" />
              {unreadCount > 0 && (
                <span className="absolute -top-1 -end-1 min-w-[16px] h-4 px-1 rounded-full bg-[#B91C32] text-[10px] font-mono-num font-bold text-white flex items-center justify-center">
                  {unreadCount}
                </span>
              )}
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="min-w-0 flex-1 w-full max-w-6xl mx-auto px-4 lg:px-6 pt-5 pb-24 lg:pb-10">
        {children}
      </main>

      {/* Fixed Portrait Bottom Navigation (Mobile / Tablet) */}
      <nav
        aria-label="Primary Navigation"
        className="lg:hidden fixed bottom-0 left-0 right-0 z-40 bg-[#0B0D12]/95 backdrop-blur-md border-t border-white/10 pb-safe"
      >
        <div className="grid w-full max-w-lg mx-auto grid-cols-[repeat(6,minmax(0,1fr))] h-16">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => onTabChange(item.id)}
                className={`relative min-w-0 flex flex-col items-center justify-center gap-1 min-h-[44px] transition-colors ${
                  isActive ? 'text-[#E04455]' : 'text-[#9299A6] hover:text-[#F4F5F7]'
                }`}
              >
                <Icon className="w-5 h-5" strokeWidth={isActive ? 2.3 : 1.8} />
                {item.id === 'social' && socialUnreadCount > 0 && <span className="absolute top-1 end-2 min-w-4 h-4 px-1 rounded-full bg-red-600 text-[9px] font-bold text-white flex items-center justify-center">{socialUnreadCount}</span>}
                <span className="block w-full min-w-0 overflow-hidden text-ellipsis whitespace-nowrap px-0.5 text-center text-[10px] sm:text-[11px] font-medium">{item.label}</span>
              </button>
            );
          })}
        </div>
      </nav>

      {/* Notifications Drawer */}
      {notifOpen && (
        <div
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4"
          role="dialog"
          aria-modal="true"
        >
          <div className="w-full sm:max-w-md bg-[#141821] border border-white/10 rounded-t-3xl sm:rounded-2xl max-h-[80vh] flex flex-col">
            <div className="flex items-center justify-between px-5 py-4 border-b border-white/8">
              <h2 className="text-base font-semibold text-[#F4F5F7]">{t.notificationsTitle}</h2>
              <div className="flex items-center gap-2">
                {unreadCount > 0 && (
                  <button
                    type="button"
                    onClick={() => {
                      const ids = notifications.filter((n) => !isRead(n)).map((n) => n.id);
                      setLocallyReadIds((current) => new Set([...current, ...ids]));
                      void markAllNotificationsRead(ids).catch(() => {
                        setLocallyReadIds((current) => new Set([...current].filter((id) => !ids.includes(id))));
                      });
                    }}
                    className="text-xs text-[#E04455] hover:underline px-2 py-1 whitespace-nowrap"
                  >
                    {t.markAllRead}
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setNotifOpen(false)}
                  className="min-h-[40px] min-w-[40px] flex items-center justify-center rounded-lg text-[#9299A6] hover:text-[#F4F5F7]"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>
            <div className="overflow-y-auto p-4 space-y-2.5">
              {notifications.length === 0 ? (
                <p className="text-sm text-[#9299A6] text-center py-8">{t.noNotifications}</p>
              ) : (
                notifications.map((n) => (
                  <div
                    key={n.id}
                    className={`p-3.5 rounded-xl border transition-colors ${
                      isRead(n)
                        ? 'bg-[#0B0D12]/60 border-white/6'
                        : 'bg-[#1B2230] border-[#B91C32]/40'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <p className="text-sm font-medium text-[#F4F5F7]">{n.title}</p>
                        <p className="text-xs text-[#9299A6] mt-1">{n.body}</p>
                      </div>
                      {!isRead(n) && (
                        <button
                          type="button"
                          onClick={() => {
                            setLocallyReadIds((current) => new Set([...current, n.id]));
                            void markNotificationRead(n.id).catch(() => {
                              setLocallyReadIds((current) => { const next = new Set(current); next.delete(n.id); return next; });
                            });
                          }}
                          aria-label="Mark read"
                          className="min-h-[36px] min-w-[36px] flex items-center justify-center rounded-lg text-[#9299A6] hover:text-[#F4F5F7] hover:bg-white/5"
                        >
                          <Check className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
