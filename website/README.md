# Think OS — website

Marketing landing + docs site for [Think OS](https://github.com/dhirajsapkal/think-os).

Built with Astro + Tailwind. Stays inside the same repo as the code so docs sit close to the source files they describe.

## Local development

```bash
cd website
npm install
npm run dev
```

Then open <http://localhost:4321>.

## Build

```bash
npm run build       # outputs to ./dist
npm run preview     # serve the built site locally
```

## Deploy

Output is a fully static site in `dist/`. Works on:

- **Vercel** — point at the `website/` folder; framework preset "Astro". No config needed.
- **Cloudflare Pages** — build command `cd website && npm install && npm run build`, output `website/dist`.
- **Netlify** — same pattern.
- **GitHub Pages** — `astro build` then push `dist/` to a `gh-pages` branch (or use an action).

## Structure

```
website/
├── public/                  Static assets served as-is
│   └── favicon.svg
└── src/
    ├── components/
    │   ├── Footer.astro
    │   ├── Header.astro
    │   ├── InstallPrompt.astro    Hero install-card with Copy button
    │   └── ThemeToggle.astro
    ├── layouts/
    │   ├── BaseLayout.astro       Fonts, theme bootstrap, paper noise
    │   └── DocsLayout.astro       Sidebar + prose container for docs
    ├── pages/
    │   ├── index.astro            Landing page
    │   └── docs/
    │       ├── index.astro
    │       ├── install.astro
    │       ├── phase-2.astro
    │       ├── phase-3-automations.astro
    │       ├── multi-vault.astro
    │       └── uninstall.astro
    └── styles/
        └── global.css             Theme tokens, typography, prose
```

## Design notes

- Typography: **Newsreader** (display serif) + **Geist** (body sans) + **Geist Mono** (code). Loaded from Google Fonts.
- Palette: warm paper (`#F8F7F2`) / deep ink (`#1B1B1B`), with a muted terracotta accent (`#A85740`). Dark mode mirrors with warm darks.
- Section structure: numbered (§ I, § II, …) for an editorial feel. No icons, no stock illustration, no emoji.
- The hero install prompt is the centerpiece — index-card framing with hairline corner ornaments and a single Copy action.
