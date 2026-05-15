import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET(context) {
  const entries = (await getCollection('changelog')).sort(
    (a, b) => b.data.date.getTime() - a.data.date.getTime()
  );

  const site = context.site ?? new URL('https://thinkos.dev');

  return rss({
    title: 'Think OS — Changelog',
    description:
      'What shipped, in reverse chronological order. Personal context for every agent session.',
    site,
    items: entries.map((entry) => {
      const slug = entry.data.version.replace(/\./g, '-');
      // Build the full URL ourselves so the fragment isn't normalized
      // with a trailing slash by the rss helper.
      const link = `${new URL('/changelog/', site).href.replace(/\/$/, '/')}#v${slug}`;
      return {
        title: `v${entry.data.version} — ${entry.data.title}`,
        pubDate: entry.data.date,
        description: entry.data.summary,
        link,
      };
    }),
    customData: '<language>en-us</language>',
  });
}
