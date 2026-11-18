import { writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const packageJson = JSON.parse(await (await import('node:fs/promises')).readFile(resolve(root, 'package.json'), 'utf8'));
const version = process.env.VERCEL_GIT_COMMIT_SHA || process.env.GITHUB_SHA || packageJson.version;
await writeFile(resolve(root, 'public/version.json'), JSON.stringify({ version }, null, 2) + '\n', 'utf8');
console.log('NEXORA build version:', version);
