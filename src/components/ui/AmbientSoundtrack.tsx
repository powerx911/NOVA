import { Music2, VolumeX } from 'lucide-react';
import { closeGameAudioContext, getGameAudioContext } from '../../lib/gameAudio';
import { useEffect, useRef, useState } from 'react';

type SoundEngine = {
  context: AudioContext;
  master: GainNode;
  voices: OscillatorNode[];
  bass: OscillatorNode;
  filter: BiquadFilterNode;
};

const PROGRESSION = [
  [146.83, 174.61, 220, 261.63],
  [116.54, 146.83, 174.61, 220],
  [87.31, 110, 130.81, 174.61],
  [130.81, 164.81, 196, 261.63],
];

function createSoundtrack(): SoundEngine {
  const context = getGameAudioContext();
  if (!context) throw new Error('Web Audio is unavailable');
  const master = context.createGain();
  const filter = context.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.value = 980;
  filter.Q.value = 0.45;
  master.gain.value = 0.0001;
  filter.connect(master);
  master.connect(context.destination);

  const voices = [0, 1, 2, 3].map((index) => {
    const oscillator = context.createOscillator();
    const voiceGain = context.createGain();
    oscillator.type = index === 3 ? 'sine' : 'triangle';
    oscillator.frequency.value = PROGRESSION[0][index];
    voiceGain.gain.value = index === 3 ? 0.10 : 0.16;
    oscillator.connect(voiceGain);
    voiceGain.connect(filter);
    oscillator.start();
    return oscillator;
  });

  const bass = context.createOscillator();
  const bassGain = context.createGain();
  bass.type = 'sine';
  bass.frequency.value = 36.71;
  bassGain.gain.value = 0.13;
  bass.connect(bassGain);
  bassGain.connect(filter);
  bass.start();

  return { context, master, voices, bass, filter };
}

export function AmbientSoundtrack({ language }: { language: 'ar' | 'en' }) {
  const [enabled, setEnabled] = useState(false);
  const [unavailable, setUnavailable] = useState(false);
  const engine = useRef<SoundEngine | null>(null);
  const progressionIndex = useRef(0);
  const interval = useRef<number | null>(null);

  useEffect(() => () => {
    if (interval.current !== null) window.clearInterval(interval.current);
    const active = engine.current;
    engine.current = null;
    if (active) {
      active.voices.forEach((voice) => voice.stop());
      active.bass.stop();
      void closeGameAudioContext();
    }
  }, []);

  async function toggleSoundtrack() {
    if (enabled) {
      const active = engine.current;
      if (active) {
        active.master.gain.setTargetAtTime(0.0001, active.context.currentTime, 0.8);
        // Keep the shared context running so button feedback remains available.
      }
      if (interval.current !== null) window.clearInterval(interval.current);
      interval.current = null;
      setEnabled(false);
      return;
    }

    try {
      const active = engine.current ?? createSoundtrack();
      engine.current = active;
      await active.context.resume();
      active.master.gain.setTargetAtTime(0.075, active.context.currentTime, 1.8);
      if (interval.current === null) {
        interval.current = window.setInterval(() => {
          const current = engine.current;
          if (!current || current.context.state !== 'running') return;
          progressionIndex.current = (progressionIndex.current + 1) % PROGRESSION.length;
          const chord = PROGRESSION[progressionIndex.current];
          const now = current.context.currentTime;
          current.voices.forEach((voice, index) => {
            voice.frequency.setTargetAtTime(chord[index], now, 1.6);
          });
          current.bass.frequency.setTargetAtTime(chord[0] / 4, now, 2.2);
        }, 8000);
      }
      setUnavailable(false);
      setEnabled(true);
    } catch {
      setUnavailable(true);
      setEnabled(false);
    }
  }

  const label = language === 'ar'
    ? (enabled ? 'إيقاف موسيقى NEXORA' : 'تشغيل موسيقى NEXORA')
    : (enabled ? 'Pause NEXORA soundtrack' : 'Play NEXORA soundtrack');

  return (
    <button
      type="button"
      onClick={toggleSoundtrack}
      aria-label={label}
      aria-pressed={enabled}
      title={unavailable ? (language === 'ar' ? 'الصوت غير متاح في هذا المتصفح' : 'Audio is unavailable in this browser') : label}
      className={`min-h-[40px] min-w-[40px] flex items-center justify-center rounded-xl border transition-colors ${
        enabled
          ? 'bg-[#B91C32]/15 border-[#B91C32]/40 text-[#F4F5F7]'
          : 'bg-[#141821] border-white/8 text-[#9299A6] hover:text-[#F4F5F7]'
      }`}
    >
      {enabled ? <Music2 className="w-4 h-4" /> : <VolumeX className="w-4 h-4" />}
    </button>
  );
}
