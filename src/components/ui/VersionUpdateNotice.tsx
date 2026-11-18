import { useEffect, useState } from 'react';

const STORAGE_KEY = 'nexora-installed-version';
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
        const response = await fetch('/version.json', { cache: 'no-store' });
        if (!response.ok) return;
        const payload = (await response.json()) as { version?: unknown };
        if (typeof payload.version !== 'string' || !payload.version.trim() || !active) return;

        const latest = payload.version.trim();
        if (knownVersion === null) {
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
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  if (!availableVersion) return null;

  function applyUpdate() {
    try {
      window.localStorage.setItem(STORAGE_KEY, availableVersion as string);
    } catch {
      // Reload regardless; version detection can recover on the next session.
    }
    window.location.reload();
  }

  return (
    <section
      role="status"
      aria-live="polite"
      className="mb-4 flex flex-col gap-3 rounded-2xl border border-emerald-400/30 bg-emerald-500/10 p-4 sm:flex-row sm:items-center sm:justify-between"
    >
      <div>
        <p className="text-sm font-bold text-emerald-200">تم إطلاق تحديث جديد</p>
        <p className="mt-1 text-xs text-emerald-100/80">يرجى التحديث للحصول على أحدث نسخة من NOVA.</p>
      </div>
      <button
        type="button"
        onClick={applyUpdate}
        className="min-h-[42px] shrink-0 rounded-xl bg-emerald-400 px-5 text-sm font-bold text-[#07120D] transition-colors hover:bg-emerald-300"
      >
        تحديث اللعبة
      </button>
    </section>
  );
}
