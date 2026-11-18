import { useEffect } from 'react';

const TRACKS = [
  'https://purrplecat-audio.pages.dev/audio/city-nights/01-crescent-moon.mp3',
  'https://purrplecat-audio.pages.dev/audio/city-nights/04-wish-you-were-here.mp3',
  'https://purrplecat-audio.pages.dev/audio/city-nights/07-dark-corners.mp3',
];
const VOLUME_KEY = 'nexora-music-volume';
const VOLUME_EVENT = 'nexora-music-volume-change';

function readVolume(): number {
  try {
    const stored = window.localStorage.getItem(VOLUME_KEY);
    if (stored === null) return 0.22;
    const value = Number(stored);
    return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0.22;
  } catch {
    return 0.22;
  }
}

/** Plays licensed instrumental game music after the player's first gesture. */
export function GameMusic() {
  useEffect(() => {
    const audio = new Audio(TRACKS[0]);
    audio.preload = 'none';
    audio.volume = readVolume();
    let trackIndex = 0;
    let started = false;

    const start = () => {
      if (audio.volume <= 0 || started) return;
      started = true;
      void audio.play().catch(() => { started = false; });
    };

    const playNextTrack = () => {
      trackIndex = (trackIndex + 1) % TRACKS.length;
      audio.src = TRACKS[trackIndex];
      audio.load();
      void audio.play().catch(() => { started = false; });
    };

    const onVolumeChange = (event: Event) => {
      const detail = (event as CustomEvent<number>).detail;
      const nextVolume = Number.isFinite(detail) ? Math.max(0, Math.min(1, detail)) : readVolume();
      audio.volume = nextVolume;
      if (nextVolume <= 0) audio.pause();
      else if (started) void audio.play().catch(() => undefined);
      else start();
    };

    document.addEventListener('pointerdown', start, true);
    document.addEventListener('keydown', start, true);
    window.addEventListener(VOLUME_EVENT, onVolumeChange);
    audio.addEventListener('ended', playNextTrack);

    return () => {
      document.removeEventListener('pointerdown', start, true);
      document.removeEventListener('keydown', start, true);
      window.removeEventListener(VOLUME_EVENT, onVolumeChange);
      audio.removeEventListener('ended', playNextTrack);
      audio.pause();
      audio.src = '';
    };
  }, []);

  return null;
}
