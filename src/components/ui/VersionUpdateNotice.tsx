import { useEffect, useState } from 'react';
import { BUILD_VERSION } from '../../generated/buildVersion';

const CHECK_INTERVAL_MS = 30_000;

/** Compares the running bundle with the no-cache version manifest from the deployed site. */
export function VersionUpdateNotice() {
  const [availableVersion, setAvailableVersion] = useState<string | null>(null);

  useEffect(() => {
    if (import.meta.env.DEV) return;

    let active = true;
    const checkVersion = async () => {
      try {
        const response = await fetch(
          `${import.meta.env.BASE_URL}version.json?check=${Date.now()}`,
          { cache: 'no-store', headers: { 'Cache-Control': 'no-cache' } },
        );
        if (!response.ok) return;
        const payload = (await response.json()) as { version?: unknown };
        if (typeof payload.version !== 'string' || !payload.version.trim() || !active) return;

        const latestVersion = payload.version.trim();
        setAvailableVersion(latestVersion === BUILD_VERSION ? null : latestVersion);
      } catch {
        // A temporary network error must not interrupt gameplay.
      }
    };

    const checkWhenVisible = () => {
      if (document.visibilityState === 'visible') void checkVersion();
    };

    void checkVersion();
    const timer = window.setInterval(() => void checkVersion(), CHECK_INTERVAL_MS);
    window.addEventListener('online', checkWhenVisible);
    window.addEventListener('focus', checkWhenVisible);
    document.addEventListener('visibilitychange', checkWhenVisible);
    return () => {
      active = false;
      window.clearInterval(timer);
      window.removeEventListener('online', checkWhenVisible);
      window.removeEventListener('focus', checkWhenVisible);
      document.removeEventListener('visibilitychange', checkWhenVisible);
    };
  }, []);

  if (!availableVersion) return null;

  function applyUpdate() {
    window.location.replace(
      `${import.meta.env.BASE_URL}?v=${encodeURIComponent(availableVersion as string)}&refresh=${Date.now()}`,
    );
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
