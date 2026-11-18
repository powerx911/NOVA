import { useEffect, useState } from 'react';

const STORAGE_KEY = 'nexora-installed-version';
// Last published static version before automatic per-build versioning was introduced.
const PRE_UPDATE_NOTICE_VERSION = '2026.11.16.1';
const CHECK_INTERVAL_MS = 45_000;

/** Detects a newly deployed build without requiring a page refresh. */
export function VersionUpdateNotice() {
  const [availableVersion, setAvailableVersion] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    let knownVersion: string | null = null;

    try {
      knownVersion = window.localStorage.getItem(STORAGE_KEY);
    } catch {
      // The update prompt still works for this session if storage is unavailable.
    }

    const checkVersion = async () => {
      try {
        const response = await fetch(`${import.meta.env.BASE_URL}version.json`, { cache: 'no-store' });
        if (!response.ok) return;
        const payload = (await response.json()) as { version?: unknown };
        if (typeof payload.version !== 'string' || !payload.version.trim() || !active) return;

        const latest = payload.version.trim();
        if (knownVersion === null) {
          // Existing players have no marker because this notice did not exist in
          // the previous build. Compare against that build instead of silently
          // treating the first check as an already-installed update.
          if (latest !== PRE_UPDATE_NOTICE_VERSION) {
            setAvailableVersion(latest);
            return;
          }
          knownVersion = latest;
          try {
            window.localStorage.setItem(STORAGE_KEY, latest);
          } catch {
            // Ignore storage restrictions.
          }
          return;
        }

        if (latest !== knownVersion) setAvailableVersion(latest);
      } catch {
        // A temporary network error must not interrupt gameplay.
      }
    };

    void checkVersion();
    const timer = window.setInterval(() => void checkVersion(), CHECK_INTERVAL_MS);
    window.addEventListener('online', checkVersion);
    return () => {
      active = false;
      window.clearInterval(timer);
      window.removeEventListener('online', checkVersion);
    };
  }, []);

  if (!availableVersion) return null;

  function applyUpdate() {
    try {
      window.localStorage.setItem(STORAGE_KEY, availableVersion as string);
    } catch {
      // Reload regardless; version detection can recover on the next session.
    }
    window.location.replace(`${import.meta.env.BASE_URL}?v=${encodeURIComponent(availableVersion as string)}`);
  }

  return (
    <div className="fixed inset-0 z-[1000] flex items-center justify-center bg-black/85 p-4 backdrop-blur-md" role="presentation">
      <section
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="nova-update-title"
        aria-describedby="nova-update-description"
        className="w-full max-w-md rounded-3xl border border-emerald-400/30 bg-[#141821] p-6 shadow-2xl"
      >
        <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-400/10 text-3xl">↻</div>
        <h2 id="nova-update-title" className="text-center text-xl font-black text-[#F4F5F7]">يتوفر تحديث جديد للعبة NOVA</h2>
        <p id="nova-update-description" className="mt-3 text-center text-sm leading-7 text-[#B9C0CC]">يجب تحديث اللعبة للمتابعة. لن تتمكن من اللعب قبل تثبيت آخر إصدار.</p>
        <button
          type="button"
          autoFocus
          onClick={applyUpdate}
          className="mt-6 min-h-[50px] w-full rounded-xl bg-emerald-400 px-5 text-sm font-black text-[#07120D] transition-colors hover:bg-emerald-300"
        >
          تحديث اللعبة الآن
        </button>
      </section>
    </div>
  );
}
