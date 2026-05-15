import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET(context) {
  const entries = (await getCollection('changelog')).sort(
    (a, b) => b.data.date.getTime() - a.data.date.getTime()
  );

  return rss({
    title: 'Think OS — Changelog',
    description:
      'What shipped, in reverse chronological order. Personal context for every agent session.',
    site: context.site ?? 'https://thinkos.dev',
    items: entries.map((entry) => ({
      title: `v${entry.data.version} — ${entry.data.title}`,
      pubDate: entry.data.date,
      description: entry.data.summary,
      link: `/changelog/#v${entry.data.version.replace(/\./g, '-')}`,
    })),
    customData: '<language>en-us</language>',
  });
}
