/**
 * Post-build: point the generated feeds at public/rss.xsl.
 *
 * starlight-blog does not expose @astrojs/rss's `stylesheet` option, so the
 * processing instruction is added here instead. It only affects what a browser
 * does with the feed; readers ignore it.
 *
 *   node scripts/style-rss.mjs dist [base]
 */
import fs from 'node:fs';
import path from 'node:path';

const dist = process.argv[2] ?? 'dist';
const base = process.argv[3] ?? '/Tweak-Collection';
const pi = `<?xml-stylesheet type="text/xsl" href="${base}/rss.xsl"?>`;

let styled = 0;
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p);
    else if (/rss.*\.xml$/.test(entry.name)) {
      const xml = fs.readFileSync(p, 'utf8');
      if (xml.includes('xml-stylesheet')) continue;
      fs.writeFileSync(p, xml.replace(/(<\?xml[^>]*\?>)/, `$1${pi}`));
      styled++;
    }
  }
})(dist);

console.log(`Styled ${styled} RSS feed(s) with ${base}/rss.xsl.`);
