// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightScrollToTop from 'starlight-scroll-to-top';
import starlightLlmsTxt from 'starlight-llms-txt';
import starlightBlog from 'starlight-blog';
import starlightGiscus from 'starlight-giscus';
import starlightTagsPlugin from 'starlight-tags';

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

  integrations: [
    starlight({
      title: 'Tweak Collection',
      description:
        'Windows tweaks for stability, performance and privacy — with the reasoning, the evidence, and a way back.',

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
        // Adds a colophon crediting Starlight under the page footer.
        Footer: './src/components/Footer.astro',
      },

      // Starlight bundles Expressive Code; these two themes match the site palette.
      expressiveCode: {
        themes: ['github-dark-default', 'github-light'],
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

        // A dated log for things that do not belong on a reference page: what got
        // added, what turned out to be wrong, what I measured.
        starlightBlog({
          title: 'Log',
          postCount: 10,
          recentPostCount: 5,
          authors: {
            slix: {
              name: 'sLix1337',
              url: 'https://github.com/sLix1337x',
            },
          },
        }),

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

        // Comments backed by GitHub Discussions, so corrections land somewhere I
        // will actually see them. Needs the giscus app installed on the repo.
        starlightGiscus({
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
      ],

      // Grouped by subsystem rather than by folder: a reader arrives with "my
      // network stutters", not with "I would like to browse the guides". So the
      // tweak page, the manual settings and the driver notes for one subsystem
      // sit together, whichever directory they happen to live in.
      //
      // The slugs are deliberate — the files have not moved, so no published URL
      // changes. Every subject is a collapsible group, closed by default: the
      // whole collection is then one screen of subjects rather than fifty links,
      // and Starlight still opens whichever group contains the current page.
      sidebar: [
        {
          label: 'Start here',
          collapsed: true,
          items: [
            { label: 'Introduction', slug: 'index' },
            { label: 'How a tweak earns its place', slug: 'start/method' },
            { label: 'All tweaks', slug: 'tweaks' },
            { label: 'Fresh install order', slug: 'reference/fresh-install-order' },
          ],
        },
        {
          label: 'Benchmark',
          collapsed: true,
          items: [
            { label: 'DPC latency', slug: 'guides/benchmark/dpc-latency' },
            { label: 'Frame times', slug: 'guides/benchmark/frame-times' },
            { label: 'The toolbox', slug: 'guides/benchmark/toolbox' },
            { label: 'Stability', slug: 'guides/benchmark/stability' },
            { label: 'Checking a tweak against the binary', slug: 'guides/reading-the-binary' },
          ],
        },
        {
          label: 'BIOS',
          collapsed: true,
          items: [
            { label: 'Worth changing', slug: 'guides/bios/worth-changing' },
            { label: 'AM4 fabric & link power', slug: 'guides/bios/am4' },
            { label: 'Before Windows goes on', slug: 'guides/bios/before-windows' },
            { label: 'Advice that no longer holds', slug: 'guides/bios/outdated-advice' },
          ],
        },
        {
          label: 'Network',
          collapsed: true,
          items: [
            { label: 'Tweaks', slug: 'tweaks/network' },
            { label: 'Adapter settings', slug: 'guides/network-adapter-settings' },
          ],
        },
        {
          label: 'System',
          collapsed: true,
          items: [
            { label: 'Power & boot', slug: 'tweaks/power' },
            { label: 'Latency', slug: 'tweaks/latency' },
            { label: 'Services', slug: 'tweaks/services' },
            { label: 'Settings outside the registry', slug: 'reference/settings-outside-the-registry' },
            { label: 'Win32PrioritySeparation, decoded', slug: 'reference/win32priorityseparation' },
          ],
        },
        {
          label: 'Input',
          collapsed: true,
          items: [
            { label: 'Mouse & keyboard', slug: 'guides/input' },
            { label: 'USB-LatencySuite', slug: 'tools/usb-latency-suite' },
          ],
        },
        {
          label: 'Audio',
          collapsed: true,
          items: [{ label: 'Playback & latency', slug: 'guides/audio' }],
        },
        {
          label: 'Privacy',
          collapsed: true,
          items: [
            { label: 'Telemetry', slug: 'tweaks/privacy' },
            { label: 'Identifiers & apps', slug: 'tweaks/privacy-identifiers' },
          ],
        },
        {
          label: 'Security',
          collapsed: true,
          items: [{ label: 'VBS, Secure Boot & anti-cheat', slug: 'guides/security' }],
        },
        {
          label: 'NVIDIA',
          collapsed: true,
          items: [
            { label: 'Tweaks', slug: 'tweaks/nvidia' },
            { label: 'Installing a driver cleanly', slug: 'guides/nvidia-driver-install' },
          ],
        },
        {
          label: 'Misc',
          collapsed: true,
          items: [{ label: 'Undoing a tweak', slug: 'reference/undoing-a-tweak' }],
        },
        // The rejected tweaks are the half of the collection people arrive already
        // believing, so they keep their own group. Split by subsystem so a reader
        // lands on the four entries that concern them, not on forty.
        {
          label: 'Debunked & rejected',
          badge: { text: '40+', variant: 'caution' },
          collapsed: true,
          items: [{ autogenerate: { directory: 'reference/debunked' } }],
        },
        // Scripts and tools are part of the collection, not the thing it is built
        // around, so they sit at the end. Autogenerated so new ones just appear.
        {
          label: 'Scripts & tools',
          collapsed: true,
          items: [{ autogenerate: { directory: 'tools' } }],
        },
      ],
    }),
  ],
});
