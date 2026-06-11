// Single source of truth for the version stamp shown on the site — never
// hardcode the version in a component.
//
// Resolution order:
//   1. website/VERSION — committed snapshot, refreshed from the repo root by
//      scripts/sync-version.mjs (npm prebuild). This is what standalone
//      deploys of the website folder (Netlify drag-and-drop) build from.
//   2. repo-root VERSION — authoritative in monorepo checkouts.
// Both are tried from cwd (build time, bundled code) and from this file's
// location (dev server, unbundled).
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const candidates = [
  resolve(process.cwd(), 'VERSION'), // website/VERSION when cwd is the site root
  resolve(process.cwd(), '../VERSION'), // repo-root VERSION when cwd is website/
  fileURLToPath(new URL('../../VERSION', import.meta.url)), // website/VERSION from src/lib (dev)
  fileURLToPath(new URL('../../../VERSION', import.meta.url)), // repo root from src/lib (dev)
];

const found = candidates.find((p) => existsSync(p));
if (!found) {
  throw new Error(
    `[version] no VERSION file found. Tried:\n  ${candidates.join('\n  ')}\n` +
      'Run "node scripts/sync-version.mjs" or commit website/VERSION.'
  );
}

export const VERSION = readFileSync(found, 'utf-8').trim();
