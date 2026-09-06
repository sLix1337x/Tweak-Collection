# network.mdx — noverse cross-check

Scope: `docs/src/content/docs/tweaks/network.mdx` (4 tweaks + intro + 2 closing sections).
noverse sources deep-read from the raw repo files (`network/desc.md`, `power/desc.md`,
`system/desc.md` at github.com/nohuto/win-config) and cited by their rendered site URLs.
A repo-wide grep of nohuto's network, power and system sections finds **zero** mentions of
Nagle, `TcpAckFrequency`, `TCPNoDelay`, TCP autotuning or TCP Chimney — his network docs are
built almost entirely around standardized INF keywords and per-driver advanced properties.

## Claim-by-claim verification

### Intro: most circulating network tweaks are XP-era; only touch driver-advertised properties

- **Our claim:** network tweak lore is largely stale XP-era material; the rule is to touch only
  properties the adapter's own driver advertises and never write values blindly into every NIC key.
- **noverse position:** **AGREES.** His entire network section works exactly this way: every page
  is built from the driver's own `Ndi\Params` INF blocks, and he repeatedly warns that
  "each adapter uses its own default values" and that `default`/`min`/`max` differ per driver, so a
  value that applies on one adapter "may get rejected" on another. His offloads page inspects live
  per-adapter state with the WinDbg `!ndiskd.netadapter -offloads` extension rather than assuming.
- **Evidence:** https://noverse.dev/docs/win-config/network/network-buffers/ ,
  https://noverse.dev/docs/win-config/network/enable-network-offloads/ ,
  https://noverse.dev/docs/win-config/power/disable-nic-power-savings/

### net.nagle: delayed ACK / Nagle, `TcpAckFrequency=1`, `TCPNoDelay=1`, the `=0` debunk, UDP caveat

- **Our claim:** Nagle buffers small TCP segments; delayed ACK holds ACKs up to 200 ms;
  `TcpAckFrequency = 1` + `TCPNoDelay = 1` per-interface under
  `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{GUID}`; `TcpAckFrequency = 0`
  is invalid and treated as the default 2; no effect in UDP titles (CS2, Valorant, Overwatch);
  cost is a few more small packets.
- **noverse position:** **NOT-COVERED.** Grep for `nagle|tcpack|tcpnodelay` across his
  network/desc.md (114 KB), power/desc.md (173 KB) and system/desc.md (633 KB) returns nothing.
  His only TCP-stack-adjacent pages are the congestion provider and MMCSS's
  `NetworkThrottlingIndex` (system section), neither of which touches per-interface ACK/Nagle
  behavior. There is no noverse evidence for or against anything in this section; our claims rest
  on Microsoft's own KB (registry-entry-control-tcp-acknowledgment-behavior) and RFC 896/1122,
  which the prior independent validation already confirmed.
- **Evidence:** absence verified against
  https://raw.githubusercontent.com/nohuto/win-config/main/network/desc.md (and power/system).

### net.adapter-powersave-off: clearing NIC power-down avoids a 1–3 s renegotiation stall

- **Our claim:** clear "Allow the computer to turn off this device to save power" on every
  physical NIC via `Disable-NetAdapterPowerManagement -Name '*'`; a power-cycled NIC renegotiates
  its link, a 1–3 s stall; the script bounces the adapter and skips the bounce under RDP.
- **noverse position:** **AGREES-WITH-NUANCE.** He has a dedicated "Disable NIC Power Savings"
  page and disables the same *class* of features, but by writing the NIC class key
  (`{4D36E972-...}\00XX`) directly, and with a much wider value set than the checkbox:
  `*SelectiveSuspend` (NDIS selective suspend, default 1; with `*SSIdleTimeout` default 5 s and
  `*SSIdleTimeoutScreenOff` default 3 s), `*DeviceSleepOnDisconnect`, wake values
  (`*WakeOnMagicPacket`, `*WakeOnPattern`, `WakeOnLink`, `S5WakeOnLan`, `WakeFromS5`), and
  Intel/vendor-specific power features (`EnableGreenEthernet`, `PowerSavingMode`, `ULPMode`,
  `ReduceSpeedOnPowerDown`, `WolShutdownLinkSpeed`, `EnableModernStandby`,
  `EnableDisconnectedStandby`, `*EnableDynamicPowerGating`, `DMACoalescing`). Separately, his
  "Enable Network Offloads" page disables the **PM protocol offloads** (`*PMARPOffload`,
  `*PMNSOffload`, `*PMWiFiRekeyOffload` — keep-alive-while-asleep ARP/NS/GTK handling) while
  keeping all task offloads on. He never mentions the Device Manager checkbox or the
  `Disable-NetAdapterPowerManagement` cmdlet, so he neither confirms nor refutes our cmdlet
  mapping caveat from the prior validation.
- **Evidence:** https://noverse.dev/docs/win-config/power/disable-nic-power-savings/ ,
  https://noverse.dev/docs/win-config/network/enable-network-offloads/ ,
  https://noverse.dev/docs/win-config/network/disable-wol/
- **Improvement material:** our tweak covers one switch; noverse documents the standardized
  NDIS selective-suspend keywords and the vendor power features (Green Ethernet / Power Saving
  Mode / ReduceSpeedOnPowerDown) that are the more common cause of mid-session link drops.

### net.eee-off: EEE 802.3az (~16.5 µs wake) and flow control 802.3x as a judgement call

- **Our claim:** EEE idles the PHY between frames; 1000BASE-T wake budget ≈16.5 µs — real but
  unfeeleable in a game. Flow control lets the switch PAUSE-frame the NIC; disabling it is a
  judgement call, no Microsoft/Intel guidance recommends it on a desktop. Script writes
  `*EEE`/`AdvancedEEE`/`*FlowControl` = 0 only on adapters advertising the keyword; old scripts
  wrote `1` (which *enables*) while claiming to disable.
- **noverse position:** **AGREES-WITH-NUANCE.**
  - EEE: he lists `*EEE` among the NIC power-savings values (802.3az by name) and documents
    Intel's `AdvancedEEE` keyword in an INF block — same keywords we use. He offers no wake-time
    figures, so our 16.5 µs (IEEE 802.3az material) is uncontested extra depth on our side. One
    nuance: his Intel INF examples show `*EEE` and `AdvancedEEE` with default `0` (disabled),
    i.e. EEE defaults are driver-specific — which reinforces our "query the advertisement first"
    design. (https://noverse.dev/docs/win-config/power/disable-nic-power-savings/)
  - Flow control: his page is titled **Disable Flow Control** and his tool turns it off — same
    direction as our script, though we editorialize it as a judgement call and he presents it as
    a default-off tweak. His Intel-sourced caveats add real depth: flow control only works if the
    link partner also supports pause frames, and on Windows Server, enabling QoS/priority-based
    flow control disables link-level flow control. His Intel INF example shows `*FlowControl`
    default `3` (Rx & Tx enabled) — consistent with our "client default is on" framing. Quirk:
    his applied value is `*FlowControl = 4` with range noted as 0–4; per his own Intel quote,
    "Auto Negotiation" makes the adapter advertise the value stored in its NVM (usually
    Disabled) — i.e. he relies on the NVM default rather than writing 0 outright. Our `0` is the
    unambiguous disable. (https://noverse.dev/docs/win-config/network/disable-flow-control/)
- **Evidence:** https://noverse.dev/docs/win-config/power/disable-nic-power-savings/ ,
  https://noverse.dev/docs/win-config/network/disable-flow-control/

### net.interrupt-moderation-off: batching, CPU-vs-latency trade, when to disable, measure first

- **Our claim:** moderation batches packets into one interrupt; disabling it lowers latency at
  the cost of CPU and interrupt rate — a genuine trade; disable with CPU headroom and
  small-packet latency goals, leave on for low core counts or saturated multi-gig links; measure
  before/after.
- **noverse position:** **AGREES.** His page quotes the same Microsoft performance-tuning
  guidance verbatim — consider moderation for CPU-bound workloads and weigh host CPU savings
  against latency — and documents `*InterruptModeration` default `1` (enabled). He adds concrete
  per-driver depth we lack: Intel's Interrupt Throttle Rate (`ITR`) ladder
  (Off = 0, Minimal ≈ 200, Low ≈ 400, Medium ≈ 950, High ≈ 2000, Extreme ≈ 3600,
  Adaptive = 65535, with a second driver generation using 32/64/125/250/500) and **Adaptive as
  the shipping default**, plus Mellanox per-direction coalescing values (`RecvIntModCount/Time`,
  `SendIntModCount/Time`). The Adaptive-default fact strengthens our "measure first" advice:
  on modern Intel NICs the driver already scales the interrupt rate with load, so forcing
  moderation fully off mainly wins for sparse small-packet traffic.
- **Evidence:** https://noverse.dev/docs/win-config/network/interrupt-moderation/
- **Related noverse-only depth:** NDIS Poll Mode (NDIS 6.85+, `*NdisPoll` keyword, default 1) —
  an OS-controlled polling execution model that replaces the classic interrupt→DPC receive path
  and gives the OS fine interrupt control and back-pressure. This is the modern context our
  moderation section doesn't mention. https://noverse.dev/docs/win-config/network/ndis-poll-mode/

### "The rest of the Advanced tab": RSS, offloads, jumbo, buffers, Priority & VLAN — blanket-disable is wrong

- **Our claim:** the tab holds more than our four tweaks, and the usual "disable everything"
  advice is wrong for most of it.
- **noverse position:** **AGREES**, page by page:
  - **Offloads:** his "Enable Network Offloads" *keeps every task offload on* — checksum, LSOv1/v2,
    USO, RSC, URO (new in 24H2/NDIS 6.89), IPsec, TCP connection offload — and documents what each
    one actually does at the NET_BUFFER_LIST level; only PM protocol offloads get turned off.
    https://noverse.dev/docs/win-config/network/enable-network-offloads/
  - **RSS:** "RSS is enabled by default"; he notes that on a default system the tweak only *removes*
    values rather than enabling anything, and that RSS requires task offloading
    (`DisableTaskOffload = 0`). https://noverse.dev/docs/win-config/network/enable-rss/
  - **Jumbo packets:** "you won't use this feature" — enable only when every device on the path
    supports the same frame size; Intel caveats he quotes: don't drop RX/TX buffers below 256 with
    jumbo frames (link loss), poor results at 10/100 Mb, switch MTU needs +4 bytes for CRC (and +4
    more with VLAN/QoS tagging). https://noverse.dev/docs/win-config/network/enable-jumbo-packets/
  - **Buffers:** he explicitly refuses to blindly apply the maximum, because INF min/max/step are
    per-adapter (his examples: TX 80–2048 default 512 on one driver, 256–4096 default 2048 on
    another) and an out-of-range write is rejected.
    https://noverse.dev/docs/win-config/network/network-buffers/
- **Evidence:** URLs above.

### Closing debunks: `*RSS = 0`, buffers `0`, MTU 1458, `chimney=disabled` are wrong, not just unneeded

- **Our claim:** these four circulating values are actively harmful or inert; reasons live on
  reference/debunked/network.
- **noverse position:** **AGREES / partially NOT-COVERED.**
  - `*RSS = 0`: directly contradicts his "Enable RSS" stance — RSS spreads receive processing
    across queues/CPUs and is default-on; he even suggests tuning *up* (`*NumRssQueues`,
    `*RssBaseProcNumber` away from core 0/1, `*RssProfile` table: 4 = NUMAScalingStatic default,
    6 = balanced profile on heterogeneous CPUs; RSSv2 needs NDIS 6.80+).
    https://noverse.dev/docs/win-config/network/enable-rss/
  - Buffers `0`: consistent with his buffers page (per-driver valid ranges, none near 0).
  - MTU 1458 and `chimney=disabled`: no noverse coverage (no autotuning/chimney/MTU content in
    his network section); our Microsoft-source deprecation claims stand uncontested.

## Improvements to adopt

(In our own words; facts sourced from the cited noverse pages.)

1. **Interrupt moderation section — name the Adaptive default and the ITR ladder.** On current
   Intel drivers the Interrupt Throttle Rate ships as "Adaptive" (registry `ITR = 65535`), with
   fixed levels from Off (0) up through Minimal/Low/Medium/High/Extreme; adaptive already lowers
   the interrupt interval under light, sparse traffic, so hard-disabling moderation is mainly a
   win for small-packet latency chasing on CPUs with headroom — exactly the audience our page
   names. Source: https://noverse.dev/docs/win-config/network/interrupt-moderation/
2. **Mention NDIS Poll Mode as the modern receive path.** Since NDIS 6.85, Windows offers Poll
   Mode (`*NdisPoll` keyword, default enabled on supporting drivers): NDIS itself schedules
   datapath work with per-iteration work limits instead of the driver chaining DPCs, giving the
   OS back-pressure and fine interrupt control. One sentence keeps our moderation section from
   describing only the legacy interrupt→DPC model.
   Source: https://noverse.dev/docs/win-config/network/ndis-poll-mode/
3. **Flow control — add the two operational caveats.** Pause frames only do anything when the
   link partner (switch) supports them, and on Windows Server, priority-based (QoS) flow control
   replaces the link-level kind. Both fit our "judgement call" framing.
   Source: https://noverse.dev/docs/win-config/network/disable-flow-control/
4. **Power-management section — point at the wider power-feature surface.** Beyond the PnP
   checkbox, drivers expose NDIS selective suspend (`*SelectiveSuspend` with
   `*SSIdleTimeout` ≈ 5 s), `*DeviceSleepOnDisconnect`, and vendor features like Green Ethernet /
   Power Saving Mode / ReduceSpeedOnPowerDown; the vendor ones are the usual suspects for
   mid-session link drops, and PM protocol offloads (ARP/NS keep-alive during sleep) are a
   separate, sleep-only feature set.
   Sources: https://noverse.dev/docs/win-config/power/disable-nic-power-savings/ ,
   https://noverse.dev/docs/win-config/network/enable-network-offloads/
5. **"Rest of the Advanced tab" — sharpen the buffers and jumbo notes.** Buffer ranges are
   per-driver INF min/max/step (observed defaults span 256–2048), and out-of-range writes are
   rejected rather than clamped — one more reason blanket values fail. If jumbo frames ever get a
   mention: all devices on the path must agree on frame size, and Intel warns against RX/TX
   buffers below 256 with jumbo enabled.
   Sources: https://noverse.dev/docs/win-config/network/network-buffers/ ,
   https://noverse.dev/docs/win-config/network/enable-jumbo-packets/
6. **EEE nuance — defaults are driver-specific.** nohuto's captured Intel INFs show `*EEE` and
   `AdvancedEEE` defaulting to disabled on some drivers, versus the WDK standardized default of
   enabled — worth one clause justifying why the script checks advertisement instead of assuming a
   default state. Source: https://noverse.dev/docs/win-config/power/disable-nic-power-savings/

## Gaps noverse covers that we don't

- **Congestion provider** — Windows' default TCP congestion control is CUBIC; CTCP (loss+delay),
  DCTCP (ECN datacenter) and BBR2 exist; per-template selection (Automatic/Internet/Datacenter/
  Compat/Custom) via `Get-NetTCPSetting`. https://noverse.dev/docs/win-config/network/congestion-provider/
- **NDIS Poll Mode** — see Improvements #2. https://noverse.dev/docs/win-config/network/ndis-poll-mode/
- **RSS tuning depth** — `*NumRssQueues`, `*RssBaseProcNumber` (move RSS off cores 0/1),
  `*RssProfile` (incl. the balanced profile for heterogeneous CPUs), RSSv2 (NDIS 6.80+).
  https://noverse.dev/docs/win-config/network/enable-rss/
- **Encrypted DNS (DoH)** — per-interface DoH templates/flags under
  `Dnscache\InterfaceSpecificParameters`, with provider templates.
  https://noverse.dev/docs/win-config/network/encrypted-dns/
- **Disable-IPv6 done safely** — `DisabledComponents = 0xFFFFFFFF` breaks needed interfaces and
  adds ~5 s boot delay; correct full-disable is `0xFF`, and `0x20` (prefer IPv4) is the
  recommended middle ground. Good debunked-page material.
  https://noverse.dev/docs/win-config/network/disable-ipv6/
- **Wake-on-LAN value set** — `powercfg /devicequery wake_armed`, `*WakeOnMagicPacket`,
  `*WakeOnPattern`, `WakeOnLink`, S5 wake caveats.
  https://noverse.dev/docs/win-config/network/disable-wol/
- **FEC (forward error correction)** — NIC-level `FecMode` on 25G+ Intel adapters; trading link
  stability for latency. Niche, but it is an Advanced-tab property we don't name.
  https://noverse.dev/docs/win-config/network/disable-fec/
- **Policy-based QoS (DSCP marking)** — per-app DSCP via `HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS`,
  with a packet capture proving the marking lands on the wire; useful only with QoS-aware network
  gear. https://noverse.dev/docs/win-config/network/qos-policy/
- **Speed & Duplex** — auto-negotiation semantics and per-driver enum values (`*SpeedDuplex`).
  https://noverse.dev/docs/win-config/network/speed-duplex/

## Conflicts needing a decision

- **Flow control: `0` (ours) vs `4`/Auto-Negotiation (noverse).** Same goal (off), different
  mechanism: his write of `4` relies on the adapter advertising the NVM-stored default (Intel:
  "usually Disabled"), which silently does nothing on NICs whose NVM default is enabled; our `0`
  is an unconditional disable. No external source prefers `4` for a desktop; Microsoft's
  standardized keyword table documents 0–3. Recommend keeping `0` and treating his `4` as a
  quirk, not an error to copy. https://noverse.dev/docs/win-config/network/disable-flow-control/
- **Editorial stance on flow control.** noverse ships "Disable Flow Control" as a default tweak;
  we present disabling as a judgement call with no vendor recommendation behind it. Our stance is
  the better-sourced one (Microsoft's WDK default on clients is Rx&Tx enabled; Intel's docs are
  neutral), so no change is forced — but the disagreement in *confidence* is worth being aware of.
- **No true factual contradictions found.** noverse simply does not cover our Nagle/delayed-ACK
  tweak, the 16.5 µs EEE wake figure, the PnP-checkbox cmdlet question, or the chimney/MTU
  debunks, so nothing on the page is disproven by his material.
