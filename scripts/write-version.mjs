import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const packageJson = JSON.parse(await readFile(resolve(root, 'package.json'), 'utf8'));
const version = process.env.VERCEL_GIT_COMMIT_SHA || process.env.GITHUB_SHA || packageJson.version;

await writeFile(resolve(root, 'public/version.json'), JSON.stringify({ version }, null, 2) + '\n', 'utf8');
const generatedDirectory = resolve(root, 'src/generated');
await mkdir(generatedDirectory, { recursive: true });
await writeFile(
  resolve(generatedDirectory, 'buildVersion.ts'),
  `// Generated at build time by scripts/write-version.mjs.\nexport const BUILD_VERSION = ${JSON.stringify(version)} as const;\n`,
  'utf8',
);
console.log('NOVA build version:', version);
