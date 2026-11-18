import { Volume2, VolumeX } from 'lucide-react';
import { useEffect, useState } from 'react';

const VOLUME_KEY = 'nexora-music-volume';
const VOLUME_EVENT = 'nexora-music-volume-change';
const DEFAULT_VOLUME = 0.22;

function readVolume(): number {
  try {
    const stored = window.localStorage.getItem(VOLUME_KEY);
    if (stored === null) return DEFAULT_VOLUME;
    const value = Number(stored);
    return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : DEFAULT_VOLUME;
  } catch {
    return DEFAULT_VOLUME;
  }
}

export function AmbientSoundtrack({ language }: { language: 'ar' | 'en' }) {
  const [volume, setVolume] = useState(readVolume);
  const enabled = volume > 0;

  useEffect(() => {
    const syncVolume = (event: Event) => {
      const detail = (event as CustomEvent<number>).detail;
      setVolume(Number.isFinite(detail) ? Math.max(0, Math.min(1, detail)) : readVolume());
    };
    window.addEventListener(VOLUME_EVENT, syncVolume);
    return () => window.removeEventListener(VOLUME_EVENT, syncVolume);
  }, []);

  function toggleSoundtrack() {
    const nextVolume = enabled ? 0 : DEFAULT_VOLUME;
    setVolume(nextVolume);
    try {
      window.localStorage.setItem(VOLUME_KEY, String(nextVolume));
    } catch {
      // The in-memory setting still works for this session.
    }
    window.dispatchEvent(new CustomEvent(VOLUME_EVENT, { detail: nextVolume }));
  }

  const label = language === 'ar'
    ? (enabled ? 'إيقاف موسيقى NOVA' : 'تشغيل موسيقى NOVA')
    : (enabled ? 'Mute NOVA music' : 'Play NOVA music');

  return (
    <button
      type="button"
      onClick={toggleSoundtrack}
      aria-label={label}
      aria-pressed={enabled}
      title={label}
      className={`min-h-[40px] min-w-[40px] flex items-center justify-center rounded-xl border transition-colors ${
        enabled
          ? 'bg-[#B91C32]/15 border-[#B91C32]/40 text-[#F4F5F7]'
          : 'bg-[#141821] border-white/8 text-[#9299A6] hover:text-[#F4F5F7]'
      }`}
    >
      {enabled ? <Volume2 className="w-4 h-4" /> : <VolumeX className="w-4 h-4" />}
    </button>
  );
}
