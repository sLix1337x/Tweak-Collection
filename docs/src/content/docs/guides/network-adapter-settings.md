---
title: Network adapter settings
description: Every property on the adapter's Advanced tab, what Windows sets it to by default, and which ones are worth changing.
sidebar:
  order: 3
tags:
  - network
  - latency
  - drivers
---

Device Manager → the NIC → **Configure** → **Advanced**, in full.

Read the adapter first. Every driver exposes a different subset, and a property that
is not listed does not exist on that hardware:

```powershell
Get-NetAdapterAdvancedProperty -Name 'Ethernet' -AllProperties |
  Format-List DisplayName, RegistryKeyword, DisplayValue, ValidDisplayValues
```

`-AllProperties` includes the properties with no display name, which the Advanced
tab hides. `ValidDisplayValues` is the list the driver accepts. Anything else
written into the registry key by hand is ignored.

## The whole tab

Names differ per vendor; the registry keyword in brackets is the standardised one
and is what to match on.

| Property | Set to | Why |
| --- | --- | --- |
| Interrupt Moderation [`*InterruptModeration`] | Off, where CPU headroom allows | The one item on this tab Microsoft's own low-latency guidance says to disable, with an explicit CPU tradeoff. See [`net.interrupt-moderation-off`](../../tweaks/network/#net.interrupt-moderation-off). |
| Interrupt Moderation Rate [`ITR`] | Off / Low | Intel's rate control for the same mechanism. Higher rate means more latency per packet. |
| Receive Side Scaling [`*RSS`] | **Enabled** (default) | Spreads receive processing across cores. Disabling it puts all of it on one CPU. |
| IPv4 / TCP / UDP Checksum Offload [`*IPChecksumOffloadIPv4`, `*TCPChecksumOffload*`, `*UDPChecksumOffload*`] | **Rx & Tx Enabled** (default) | Checksums computed in NIC silicon instead of on the CPU. Microsoft's low-latency list says to *enable* these. |
| Large Send Offload V2, IPv4 and IPv6 [`*LsoV2IPv4`, `*LsoV2IPv6`] | **Enabled** (default) | Segmentation done by the NIC. Same source, same instruction: enable. |
| Energy Efficient Ethernet [`*EEE`, Intel: `AdvancedEEE`] | Disabled | Idles the PHY between frames. See [`net.eee-off`](../../tweaks/network/#net.eee-off). |
| Flow Control [`*FlowControl`] | Judgement call, see below | Default is Rx & Tx Enabled on client Windows. |
| Green Ethernet / Gigabit Lite / Power Saving Mode (Realtek) | Disabled | Vendor power features in the same family as EEE. Undocumented specifics; disable when investigating link-wake behaviour. |
| Jumbo Packet / Jumbo Frame [`*JumboPacket`] | 1514 (disabled) | Only useful if every device in the path is configured for it. Otherwise it causes fragmentation, not throughput. |
| Speed & Duplex [`*SpeedDuplex`] | Auto Negotiation | Forcing a speed is how duplex mismatches happen. |
| Receive Buffers [`*ReceiveBuffers`] | Default, unless packets are being dropped | See below. |
| Transmit Buffers [`*TransmitBuffers`] | Default | Same. |
| Packet Priority & VLAN [`*PriorityVLANTag`] | Enabled (default) | An 802.1Q tagging switch with no documented performance dimension. Disabling it breaks QoS tagging and VLANs and buys nothing. |
| Wake on Magic Packet [`*WakeOnMagicPacket`], Wake on Pattern Match [`*WakeOnPattern`] | As required for Wake-on-LAN | Wake features only. No effect on a running link. |
| ARP Offload [`*PMARPOffload`], NS Offload [`*PMNSOffload`] | Default | Let the NIC answer ARP/neighbour requests while the machine sleeps. Nothing to do with throughput. |
| Locally Administered Address [`NetworkAddress`] | Empty | MAC override. Leave it alone without a specific reason. |

Two properties are not on this tab but belong to the same discussion:

- **Allow the computer to turn off this device to save power** sits on the Power
  Management tab, not Advanced. Clear it: [`net.adapter-powersave-off`](../../tweaks/network/#net.adapter-powersave-off).
- **Receive Segment Coalescing** [`*RscIPv4`, `*RscIPv6`] is enabled by default and
  also a global stack setting (`netsh int tcp show global`). It coalesces received
  segments so the stack parses one header instead of many, lowering CPU on the receive
  path. Disabling it is widely recommended for latency and **is not documented as
  lowering latency anywhere**. Leave it on unless a local capture says otherwise.

## Do not disable the offloads

Disabling everything on this tab moves checksum and segmentation work off the NIC's
dedicated silicon and onto the CPU. Microsoft's network low-latency guidance says the
opposite: enable the static offloads, including UDP and TCP checksums and Large Send
Offload.

There is also a dependency. **RSS needs checksum offload, and checksum offload needs
the global `TaskOffload` setting.** Disabling that —
`Set-NetOffloadGlobalSetting -TaskOffload Disable`, or the `DisableTaskOffload`
registry value in tweak bundles — silently takes the RSS indirection table with it, so
the adapter falls back to single-core interrupt handling while its Advanced tab still
reports RSS as Enabled. Check the global state before trusting the per-adapter one:

```powershell
Get-NetOffloadGlobalSetting | Select-Object TaskOffload, ReceiveSideScaling
```

Keep `TaskOffload` enabled globally and decide per property at the adapter.

An adapter in this state has been through a tweak script:

```text
IPv4 Checksum Offload         Disabled
TCP Checksum Offload (IPv4)   Disabled
UDP Checksum Offload (IPv4)   Disabled
Large Send Offload V2 (IPv4)  Disabled
Packet Priority & VLAN        Disabled
```

The default is Enabled for all of them.
`Reset-NetAdapterAdvancedProperty -Name 'Ethernet' -DisplayName '*'` restores every
property on the adapter to the driver's default.

## Receive Side Scaling

RSS hashes incoming flows across receive queues so more than one CPU can process them.
Without it, receive processing for an interrupt runs on the CPU where that interrupt
occurred — in practice usually CPU 0, though not documented as a guarantee.

Leave it enabled. Two caveats:

- A single game's UDP flow hashes to one queue, so RSS does not spread *that* traffic.
  It protects everything else receiving at the same time.
- Not every adapter exposes it. An Intel I225-V on driver 2.1.5.7 lists no `*RSS`
  keyword and returns no object from `Get-NetAdapterRss`, while the TCP stack still
  reports RSS as enabled globally. Writing `*RSS` into the registry by hand does
  nothing there.

`*NumRssQueues` sets the queue count; the `0` circulating in scripts is not a valid
queue count.

Drivers implementing the full standard expose three further keywords, the only part of
RSS worth deliberate tuning:

| Keyword | What it does |
| --- | --- |
| `*RssBaseProcNumber` | The first CPU RSS is allowed to use. Raising it moves receive processing off the low cores, which is where Windows concentrates its own housekeeping interrupts. |
| `*RssMaxProcNumber`, `*MaxRssProcessors` | The upper bound and the count, for confining RSS to a subset of cores. |
| `*RssProfile` | The assignment policy: closest processor, closest static, conservative, or a balanced profile for heterogeneous CPUs. |

`Set-NetAdapterRss` writes them; `Get-NetAdapterRss` shows the resulting processor set.
This is the supported form of NIC interrupt affinity, using the driver's documented
mechanism rather than
[pinning IRQs by hand](../../reference/settings-outside-the-registry/#interrupt-affinity);
on a machine with healthy RSS the manual route adds nothing. Adapters on NDIS 6.80 and
newer may also implement RSSv2, which re-steers per queue at runtime rather than only
at initialisation.

## Flow control

Flow control (802.3x) lets the link partner send a PAUSE frame that stops the NIC
transmitting for a period. The client Windows default is Rx & Tx enabled.

[`net.eee-off`](../../tweaks/network/#net.eee-off) disables it, as a judgement call
rather than a documented fix: neither Microsoft nor Intel recommends disabling it on a
desktop, and Intel recommends enabling it for RDMA. For: a PAUSE frame is an
unrequested hard stop on transmission, on a home link that never saturates. Against: it
prevents loss on a link that does.

Windows disables flow control while a kernel debugger is attached over the network.

## Buffers

`*ReceiveBuffers` is the number of receive descriptors the driver allocates. Too few
and packets drop under burst; too many costs RAM plus queue depth. Microsoft documents
raising it for receive-heavy workloads. Intel adapters use 2 KB per descriptor with a
range of 128–4096 in steps of 64.

Not a latency setting — deeper queues add buffering. Raise only against evidence of
discards in `Get-NetAdapterStatistics`:

```powershell
Get-NetAdapterStatistics -Name 'Ethernet' |
  Select-Object ReceivedDiscardedPackets, OutboundDiscardedPackets
```

Zero after a long session means the buffers are adequate.

## Energy Efficient Ethernet, with a number

EEE (802.3az) puts the PHY into Low Power Idle between bursts. Intel documents that the
wake transition "may introduce a small amount of network latency" without a figure. The
standard's wake-time budget is around 16.5 µs for 1000BASE-T and 30 µs for 100BASE-TX.

Measurable on the right equipment, three orders of magnitude below anything perceptible
in a game. Disable it for a deterministic link, not for a frame-time change.

## Sources

- [Network subsystem performance tuning](https://learn.microsoft.com/en-us/windows-server/networking/technologies/network-subsystem/net-sub-performance-tuning-nics) — the low-latency checklist, including "enable static offloads" and "disable interrupt moderation".
- [Standardized INF keywords for network devices](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/standardized-inf-keywords-for-network-devices) — every `*`-prefixed keyword above, with defaults and valid values.
- [Introduction to Receive Side Scaling](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/introduction-to-receive-side-scaling)
- [Interrupt moderation](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/interrupt-moderation)
- [Overview of Receive Segment Coalescing](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/overview-of-receive-segment-coalescing)
- [Get-NetAdapterAdvancedProperty](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapteradvancedproperty)
