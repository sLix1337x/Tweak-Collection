/**
 * The sidebar, kept here rather than inline in `astro.config.mjs` because the
 * Index page renders the same tree (`components/SiteIndex.astro`). One list, so
 * a new page cannot appear in the navigation and be missing from the index.
 *
 * Grouped by subsystem rather than by folder: a reader arrives with "my network
 * stutters", not with "I would like to browse the guides". So the tweak page,
 * the manual settings and the driver notes for one subsystem sit together,
 * whichever directory they happen to live in.
 *
 * The slugs are deliberate — the files have not moved, so no published URL
 * changes. Every subject is a collapsible group, closed by default: the whole
 * collection is then one screen of subjects rather than fifty links, and
 * Starlight still opens whichever group contains the current page.
 */
export const sidebar = [
  {
    label: 'Start here',
    collapsed: true,
    items: [
      { label: 'Index', slug: 'tweaks' },
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
  // Socket first, because that is the question a reader can answer before
  // reading anything. Flat entries rather than a group per socket: a group
  // inside a group reads as a second category and buries the pages a click
  // deeper. The three platform-neutral pages follow, with the ambiguous one
  // labelled for scope so it does not read as a third platform.
  {
    label: 'BIOS',
    collapsed: true,
    items: [
      { label: 'AM4 BIOS', slug: 'guides/bios/am4' },
      { label: 'AM5 BIOS', slug: 'guides/bios/am5' },
      { label: 'Worth changing (any board)', slug: 'guides/bios/worth-changing' },
      { label: 'Before Windows goes on', slug: 'guides/bios/before-windows' },
      { label: 'Advice that no longer holds', slug: 'guides/bios/outdated-advice' },
    ],
  },
  {
    label: 'Network',
    collapsed: true,
    items: [
      { label: 'Network tweaks', slug: 'tweaks/network' },
      { label: 'Adapter settings', slug: 'guides/network-adapter-settings' },
    ],
  },
  {
    label: 'Power & latency',
    collapsed: true,
    items: [
      { label: 'Power & boot', slug: 'tweaks/power' },
      { label: 'Latency', slug: 'tweaks/latency' },
      { label: 'Win32PrioritySeparation, decoded', slug: 'reference/win32priorityseparation' },
    ],
  },
  {
    label: 'Services',
    collapsed: true,
    items: [
      { label: 'Service tweaks', slug: 'tweaks/services' },
      { label: 'Service reference', slug: 'reference/service-reference' },
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
      { label: 'NVIDIA tweaks', slug: 'tweaks/nvidia' },
      { label: 'Installing a driver cleanly', slug: 'guides/nvidia-driver-install' },
    ],
  },
  // The two pages that apply to every subject rather than to one of them.
  {
    label: 'Reference',
    collapsed: true,
    items: [
      { label: 'Settings outside the registry', slug: 'reference/settings-outside-the-registry' },
      { label: 'Undoing a tweak', slug: 'reference/undoing-a-tweak' },
    ],
  },
  // One game, treated as a worked case: the whole collection applied to a
  // CPU-bound title, plus the engine-specific facts that make general advice
  // wrong for it. Below the subsystems because none of it generalises — it is
  // an appendix, not a way into the collection.
  {
    label: 'Counter-Strike 2',
    collapsed: true,
    items: [
      { label: 'Overview', slug: 'cs2' },
      { label: 'Measuring CS2', slug: 'cs2/measuring' },
      { label: 'The frame cap', slug: 'cs2/frame-cap' },
      { label: 'Game settings', slug: 'cs2/game-settings' },
      { label: 'System & driver', slug: 'cs2/system' },
      { label: 'What does not work', slug: 'cs2/myths' },
    ],
  },
  // The rejected tweaks are the half of the collection people arrive already
  // believing, so they keep their own group, led by the filter every one of
  // them failed. Split by subsystem so a reader lands on the four entries that
  // concern them, not on forty.
  {
    label: 'Debunked & rejected',
    badge: { text: '40+', variant: 'caution' },
    collapsed: true,
    items: [
      { label: 'How a tweak earns its place', slug: 'start/method' },
      { autogenerate: { directory: 'reference/debunked' } },
    ],
  },
  // Scripts and tools are part of the collection, not the thing it is built
  // around, so they sit at the end. Autogenerated so new ones just appear.
  {
    label: 'Scripts & tools',
    collapsed: true,
    items: [{ autogenerate: { directory: 'tools' } }],
  },
];
