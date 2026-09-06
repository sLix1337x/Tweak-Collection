// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightScrollToTop from 'starlight-scroll-to-top';
import starlightLlmsTxt from 'starlight-llms-txt';
import starlightGiscus from 'starlight-giscus';
import starlightTagsPlugin from 'starlight-tags';
import { sidebar } from './src/sidebar.js';
import { satteri } from '@astrojs/markdown-satteri';
import { tableWrapper } from './plugins/table-wrapper.mjs';

// GitHub Pages serves this project site from /<repo>/, so `base` has to match.
export default defineConfig({
  site: 'https://slix1337x.github.io',
  base: '/Tweak-Collection',
  // The icons live at the repo root rather than under docs/, so point Astro there
  // instead of moving them.
  publicDir: '../public',

  // These two pages moved when scripts and tools got their own section.
  // Destinations need the base prefix; Astro applies it to the generated route but
  // emits the target URL verbatim.
  redirects: {
    '/start/script': '/Tweak-Collection/tools/tweaks-script/',
    '/start/rollback': '/Tweak-Collection/reference/undoing-a-tweak/',
    // The checklist was split in two when it had grown into a grab-bag.
    '/reference/manual-checklist': '/Tweak-Collection/reference/fresh-install-order/',
    '/reference/old-notes': '/Tweak-Collection/reference/debunked/',
    // Two long pages became sections when the nav was split by subject.
    '/guides/measuring-before-you-tweak': '/Tweak-Collection/guides/benchmark/dpc-latency/',
    '/guides/bios': '/Tweak-Collection/guides/bios/worth-changing/',
  },

  // MDX inherits this block, so the wrapper applies to both page types.
  markdown: {
    processor: satteri({ hastPlugins: [tableWrapper] }),
  },

  integrations: [
    starlight({
      title: 'Tweak Collection',
      description:
        'Windows tweaks for stability, performance and privacy, with the reasoning, the evidence, and a way back.',

      favicon: '/favicon.ico',

      logo: {
        src: './src/assets/logo.png',
        replacesTitle: false,
      },

      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/sLix1337x/Tweak-Collection' },
      ],

      editLink: {
        baseUrl: 'https://github.com/sLix1337x/Tweak-Collection/edit/main/docs/',
      },

      lastUpdated: true,
      pagination: true,

      customCss: [
        '@fontsource-variable/inter',
        '@fontsource-variable/jetbrains-mono',
        './src/styles/theme.css',
        './src/styles/components.css',
      ],

      components: {
        // Adds theme-colour meta on top of Starlight's own head.
        Head: './src/components/Head.astro',
        // Replaces the default splash hero.
        Hero: './src/components/Hero.astro',
        // Adds a breadcrumb above the title, read from the sidebar tree.
        PageTitle: './src/components/PageTitle.astro',
        // Starlight's search, plus the empty state it does not ship: suggested
        // pages and common terms, shown until the first character is typed.
        Search: './src/components/Search.astro',
        // The site is dark only; the light/dark picker renders nothing.
        ThemeSelect: './src/components/ThemeSelect.astro',
        // Adds a colophon crediting Starlight under the page footer.
        Footer: './src/components/Footer.astro',
      },

      // Starlight bundles Expressive Code; these two themes match the site palette.
      expressiveCode: {
        themes: ['github-dark-default'],
        styleOverrides: {
          borderRadius: '0.6rem',
          borderColor: 'var(--tc-border)',
          codeFontFamily: 'var(--sl-font-mono)',
          frames: {
            shadowColor: 'transparent',
          },
        },
      },

      plugins: [
        starlightScrollToTop({ showTooltip: false }),

        // Cross-cutting tags, so "everything touching anti-cheat" is one click
        // rather than a search.
        starlightTagsPlugin({
          sidebar: {
            position: 'bottom',
            limit: 0,
            sortBy: 'count',
            collapsed: true,
          },
        }),

        // Comments backed by GitHub Discussions. Disabled: the giscus GitHub App
        // is not installed on the repository, so every page rendered a visible
        // "giscus is not installed on this repository" error instead of a
        // comment box. Install it at https://github.com/apps/giscus and drop the
        // `false &&` to turn the thread back on. Until then the corrections
        // block in Footer.astro carries the same two links.
        false && starlightGiscus({
          repo: 'sLix1337x/Tweak-Collection',
          repoId: 'R_kgDONnNphQ',
          category: 'Announcements',
          categoryId: 'DIC_kwDONnNphc4DEwBZ',
          mapping: 'pathname',
          reactions: true,
          lazy: true,
          theme: { light: 'light', dark: 'dark_dimmed' },
        }),
        // Publishes llms.txt / llms-full.txt so the collection can be read whole,
        // by a person or by whatever they are asking about their machine.
        starlightLlmsTxt({
          projectName: 'Tweak Collection',
          description:
            'A collection of Windows tweaks for stability, performance and privacy. Every entry states the mechanism it changes, what it costs, and how to undo it. A companion section lists popular tweaks that were tested and rejected.',
          optionalLinks: [
            {
              label: 'Debunked & rejected tweaks',
              url: 'https://slix1337x.github.io/Tweak-Collection/reference/debunked/',
              description: 'Popular Windows tweaks that do nothing, no longer work, or cause harm.',
            },
          ],
        }),
      ].filter(Boolean),

      sidebar,
    }),
  ],
});
