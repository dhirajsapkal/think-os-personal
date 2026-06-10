// Single source of truth for the version stamp shown on the site.
// Read at build time from the repo-root VERSION file — never hardcode
// the version in a component.
import { readFileSync } from 'node:fs';

export const VERSION = readFileSync(
  new URL('../../../VERSION', import.meta.url),
  'utf-8'
).trim();
