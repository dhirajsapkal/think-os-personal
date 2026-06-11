// Refresh the committed VERSION snapshot (website/VERSION) from the repo-root
// VERSION file when building inside the monorepo. Standalone deploys of the
// website folder (e.g. Netlify drag-and-drop) have no repo root above them —
// they keep the committed snapshot, so the build never depends on files
// outside this directory.
import { copyFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const repoRootVersion = fileURLToPath(new URL('../../VERSION', import.meta.url));
const snapshot = fileURLToPath(new URL('../VERSION', import.meta.url));

if (existsSync(repoRootVersion)) {
  copyFileSync(repoRootVersion, snapshot);
  console.log(`[sync-version] refreshed website/VERSION from repo root`);
} else {
  console.log(`[sync-version] no repo-root VERSION (standalone build); using committed snapshot`);
}
