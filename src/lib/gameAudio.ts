let sharedAudioContext: AudioContext | null = null;

export function getGameAudioContext(): AudioContext | null {
  if (typeof window === 'undefined') return null;

  const audioWindow = window as Window & { webkitAudioContext?: typeof AudioContext };
  const AudioContextConstructor = window.AudioContext ?? audioWindow.webkitAudioContext;
  if (!AudioContextConstructor) return null;

  try {
    sharedAudioContext ??= new AudioContextConstructor({ latencyHint: 'interactive' });
    return sharedAudioContext;
  } catch {
    return null;
  }
}

/**
 * Must be called from a trusted user gesture (pointer, click, or keyboard).
 * Reusing one context avoids browser limits and makes the soundtrack and UI
 * feedback obey the same autoplay policy.
 */
export async function unlockGameAudio(): Promise<AudioContext | null> {
  const context = getGameAudioContext();
  if (!context) return null;

  try {
    if (context.state !== 'running') await context.resume();
    return context.state === 'running' ? context : null;
  } catch {
    return null;
  }
}

export function isButtonSoundEnabled(): boolean {
  try {
    return window.localStorage.getItem('nexora-button-sound') !== 'off';
  } catch {
    return true;
  }
}

export function playButtonFeedback(context: AudioContext): void {
  if (context.state !== 'running' || !isButtonSoundEnabled()) return;

  const now = context.currentTime;
  const output = context.createGain();
  const tone = context.createOscillator();
  const accent = context.createOscillator();
  const filter = context.createBiquadFilter();

  filter.type = 'lowpass';
  filter.frequency.setValueAtTime(1850, now);
  output.gain.setValueAtTime(0.0001, now);
  output.gain.exponentialRampToValueAtTime(0.032, now + 0.009);
  output.gain.exponentialRampToValueAtTime(0.0001, now + 0.082);

  tone.type = 'sine';
  tone.frequency.setValueAtTime(520, now);
  tone.frequency.exponentialRampToValueAtTime(690, now + 0.045);
  accent.type = 'triangle';
  accent.frequency.setValueAtTime(1040, now);
  accent.frequency.exponentialRampToValueAtTime(1380, now + 0.04);

  tone.connect(filter);
  accent.connect(filter);
  filter.connect(output);
  output.connect(context.destination);

  tone.start(now);
  accent.start(now);
  tone.stop(now + 0.085);
  accent.stop(now + 0.07);
  tone.onended = () => {
    tone.disconnect();
    accent.disconnect();
    filter.disconnect();
    output.disconnect();
  };
}

export async function closeGameAudioContext(): Promise<void> {
  const active = sharedAudioContext;
  sharedAudioContext = null;
  if (active && active.state !== 'closed') {
    try {
      await active.close();
    } catch {
      // Closing an already-interrupted browser context is safe to ignore.
    }
  }
}
