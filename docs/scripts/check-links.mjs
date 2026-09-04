/**
 * Post-build internal link check.
 *
 * starlight-links-validator was tried first and removed: it returns early on any
 * relative link, and every cross-page link in these docs is relative, so it
 * validated nothing while reporting success.
 *
 * This walks the built HTML instead and checks links as they actually ship —
 * including the relative ones, which Astro emits verbatim rather than rewriting,
 * and including hash fragments.
 *
 *   node scripts/check-links.mjs dist [base]
 */
import fs from 'node:fs';
import path from 'node:path';

const dist = process.argv[2] ?? 'dist';
const base = process.argv[3] ?? '/Tweak-Collection';

const SKIP_EXT = /\.(css|js|png|webp|jpg|jpeg|svg|xml|ico|json|txt|woff2?)$/;
const EXTERNAL = /^(https?:|mailto:|tel:|data:|\/\/)/;

const files = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p);
    else if (entry.name.endsWith('.html')) files.push(p);
  }
})(dist);

const routeOf = (file) => '/' + path.relative(dist, file).split(path.sep).join('/');

const pages = new Set(files.map(routeOf));
const anchors = new Map();
for (const file of files) {
  const html = fs.readFileSync(file, 'utf8');
  anchors.set(routeOf(file), new Set([...html.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1])));
}

/** Resolve an href to a dist-relative route, or null if it is not ours to check. */
function resolveRoute(href, fromRoute) {
  let target;
  if (href.startsWith(base + '/') || href === base) {
    // Root-absolute, as emitted for sidebar links and Starlight components.
    target = href.slice(base.length) || '/';
  } else if (href.startsWith('/')) {
    // Absolute but outside the base — not a page this build produced.
    return null;
  } else {
    // Relative, as emitted for links written in markdown. resolve() drops the
    // trailing slash, which is exactly what distinguishes a directory URL here.
    target = path.posix.resolve(path.posix.dirname(fromRoute), href);
    if (href.endsWith('/') && !target.endsWith('/')) target += '/';
  }
  return target.endsWith('/') ? target + 'index.html' : target;
}

/** Candidate routes for an href: a trailing slash is optional, both are served. */
function candidates(route) {
  return route.endsWith('.html') ? [route] : [route, route + '/index.html'];
}

let broken = 0;
let checked = 0;

for (const file of files) {
  const fromRoute = routeOf(file);
  const html = fs.readFileSync(file, 'utf8');
  // Body only: the sidebar and header repeat the same links on every page.
  const body = html.includes('<main') ? html.slice(html.indexOf('<main')) : html;

  for (const match of body.matchAll(/href="([^"]+)"/g)) {
    const href = match[1];
    if (EXTERNAL.test(href) || SKIP_EXT.test(href)) continue;

    const [rawPath, hash] = href.split('#');

    // A bare "#foo" points at the current page.
    const route = rawPath === '' ? fromRoute : resolveRoute(rawPath, fromRoute);
    if (route === null) continue;

    checked++;

    const hit = candidates(route).find((c) => pages.has(c));
    if (!hit) {
      console.error(`  broken page    ${fromRoute}  ->  ${href}`);
      broken++;
    } else if (hash && !anchors.get(hit).has(hash)) {
      console.error(`  broken anchor  ${fromRoute}  ->  ${href}`);
      broken++;
    }
  }
}

if (broken > 0) {
  console.error(`\n${broken} broken internal link(s) out of ${checked} checked.`);
  process.exit(1);
}
console.log(`Checked ${checked} internal links across ${files.length} pages — all valid.`);
