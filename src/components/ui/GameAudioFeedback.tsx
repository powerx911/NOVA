import { useEffect } from 'react';
import { playButtonFeedback, unlockGameAudio } from '../../lib/gameAudio';

/**
 * Unlocks the shared Web Audio context on the first trusted user gesture and
 * gives every interactive control a short, synthesized response sound.
 * No audio files, network requests, or autoplay are used.
 */
export function GameAudioFeedback() {
  useEffect(() => {
    const unlock = () => {
      void unlockGameAudio();
    };

    const onClick = (event: MouseEvent) => {
      const target = event.target;
      if (!(target instanceof Element)) return;

      const control = target.closest(
        'button:not(:disabled), [role="button"], a[href], input[type="button"]:not(:disabled), input[type="submit"]:not(:disabled)'
      );
      if (!control) return;

      void unlockGameAudio().then((context) => {
        if (context) playButtonFeedback(context);
      });
    };

    document.addEventListener('pointerdown', unlock, { capture: true, passive: true });
    document.addEventListener('keydown', unlock, true);
    document.addEventListener('click', onClick, true);

    return () => {
      document.removeEventListener('pointerdown', unlock, true);
      document.removeEventListener('keydown', unlock, true);
      document.removeEventListener('click', onClick, true);
    };
  }, []);

  return null;
}
