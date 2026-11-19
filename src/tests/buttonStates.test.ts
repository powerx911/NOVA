import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

const stylesheet = fs.readFileSync(path.resolve(process.cwd(), 'src/index.css'), 'utf8');

describe('NOVA global action button states', () => {
  it('keeps enabled legacy primary actions visibly actionable', () => {
    expect(stylesheet).toContain('[class*="bg-[#B91C32]"]');
    expect(stylesheet).toContain('color:#fff !important;');
    expect(stylesheet).toContain('box-shadow:0 0 0 1px rgba(99,165,255,.24),0 0 14px rgba(57,123,255,.24);');
  });

  it('also gives native NOVA blue and cyan primary actions the enabled glow', () => {
    expect(stylesheet).toContain('[class*="bg-[#397BFF]"]');
    expect(stylesheet).toContain('[class*="bg-cyan-700"]');
    expect(stylesheet).toContain('color:#fff !important;');
  });

  it('dims disabled and aria-disabled controls and removes their glow', () => {
    expect(stylesheet).toContain(':where(button,[role="button"],input[type="button"],input[type="submit"]):disabled');
    expect(stylesheet).toContain('[aria-disabled="true"]');
    expect(stylesheet).toContain('opacity:.58;');
    expect(stylesheet).toContain('filter:saturate(.62);');
    expect(stylesheet).toContain('box-shadow:none !important;');
  });

  it('preserves visible keyboard focus and reduced-motion support', () => {
    expect(stylesheet).toContain('button:focus-visible');
    expect(stylesheet).toContain('outline:2px solid rgba(99,165,255,.9)');
    expect(stylesheet).toContain('@media(prefers-reduced-motion:reduce)');
  });

  it('limits enabled primary styling to controls that are actually enabled', () => {
    const legacyRule = stylesheet.match(
      /:where\(button,\[role="button"\],input\[type="button"\],input\[type="submit"\]\):not\(:disabled\):not\(\[aria-disabled="true"\]\)\[class\*="bg-\[#B91C32\]"\]\s*\{[^}]*\}/
    );
    expect(legacyRule?.[0]).toContain(':not(:disabled)');
    expect(legacyRule?.[0]).toContain(':not([aria-disabled="true"])');
  });
});
