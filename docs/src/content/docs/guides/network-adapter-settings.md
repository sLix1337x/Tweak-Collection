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

Device Manager → your NIC → **Configure** → **Advanced** is where most network
tweaking happens, and where most of it goes wrong. This page covers the whole tab.

Read your own adapter first. Every driver exposes a different subset, and a
property that is not listed does not exist on your hardware:

```powershell
Get-NetAdapterAdvancedProperty -Name 'Ethernet' -AllProperties |
  Format-List DisplayName, RegistryKeyword, DisplayValue, ValidDisplayValues
```

`-AllProperties` includes the properties with no display name, which the Advanced
tab hides. `ValidDisplayValues` is the list your driver will accept — writing
anything else into the registry key by hand gets you an ignored value.

## The whole tab

Names differ per vendor; the registry keyword in brackets is the standardised one
and is what to match on.

| Property | Set to | Why |
| --- | --- | --- |
| Interrupt Moderation [`*InterruptModeration`] | Off, if you have CPU headroom | The one item on this tab Microsoft's own low-latency guidance says to disable, with an explicit CPU tradeoff. See [`net.interrupt-moderation-off`](../../tweaks/network/#net.interrupt-moderation-off). |
| Interrupt Moderation Rate [`ITR`] | Off / Low | Intel's rate control for the same mechanism. Higher rate means more latency per packet. |
| Receive Side Scaling [`*RSS`] | **Enabled** (default) | Spreads receive processing across cores. Disabling it puts all of it on one CPU. |
| IPv4 / TCP / UDP Checksum Offload [`*IPChecksumOffloadIPv4`, `*TCPChecksumOffload*`, `*UDPChecksumOffload*`] | **Rx & Tx Enabled** (default) | Checksums computed in NIC silicon instead of by your CPU. Microsoft's low-latency list says to *enable* these. |
| Large Send Offload V2, IPv4 and IPv6 [`*LsoV2IPv4`, `*LsoV2IPv6`] | **Enabled** (default) | Segmentation done by the NIC. Same source, same instruction: enable. |
| Energy Efficient Ethernet [`*EEE`, Intel: `AdvancedEEE`] | Disabled | Idles the PHY between frames. See [`net.eee-off`](../../tweaks/network/#net.eee-off). |
| Flow Control [`*FlowControl`] | Judgement call — see below | Default is Rx & Tx Enabled on client Windows. |
| Green Ethernet / Gigabit Lite / Power Saving Mode (Realtek) | Disabled | Vendor power features in the same family as EEE. Undocumented specifics; disable if you are chasing link-wake behaviour. |
| Jumbo Packet / Jumbo Frame [`*JumboPacket`] | 1514 (disabled) | Only useful if every device in the path is configured for it. Otherwise it causes fragmentation, not throughput. |
| Speed & Duplex [`*SpeedDuplex`] | Auto Negotiation | Forcing a speed is how duplex mismatches happen. |
| Receive Buffers [`*ReceiveBuffers`] | Default, unless you are dropping packets | See below. |
| Transmit Buffers [`*TransmitBuffers`] | Default | Same. |
| Packet Priority & VLAN [`*PriorityVLANTag`] | Enabled (default) | An 802.1Q tagging switch with no documented performance dimension. Disabling it breaks QoS tagging and VLANs and buys nothing. |
| Wake on Magic Packet [`*WakeOnMagicPacket`], Wake on Pattern Match [`*WakeOnPattern`] | Whatever you need for Wake-on-LAN | Wake features only. No effect on a running link. |
| ARP Offload [`*PMARPOffload`], NS Offload [`*PMNSOffload`] | Default | Let the NIC answer ARP/neighbour requests while the machine sleeps. Nothing to do with throughput. |
| Locally Administered Address [`NetworkAddress`] | Empty | MAC override. Leave it alone unless you have a reason. |

Two properties are not on this tab but belong to the same discussion:

- **Allow the computer to turn off this device to save power** — Power Management
  tab, not Advanced. Clear it: [`net.adapter-powersave-off`](../../tweaks/network/#net.adapter-powersave-off).
- **Receive Segment Coalescing** [`*RscIPv4`, `*RscIPv6`] — enabled by default, also
  a global stack setting (`netsh int tcp show global`). It coalesces received
  segments so the stack parses one header instead of many, which lowers CPU on the
  receive path. Disabling it is widely recommended for latency and **is not
  documented as lowering latency anywhere**. Leave it on unless your own capture
  says otherwise.

## The offloads are not the enemy

The single most common thing done to this tab is disabling everything in it. That
gets checksum and segmentation work off the NIC's dedicated silicon and onto your
CPU, and Microsoft's network low-latency guidance says the opposite: enable the
static offloads, including UDP and TCP checksums and Large Send Offload.

If your adapter currently looks like this, it has been through a tweak script:

```text
IPv4 Checksum Offload         Disabled
TCP Checksum Offload (IPv4)   Disabled
UDP Checksum Offload (IPv4)   Disabled
Large Send Offload V2 (IPv4)  Disabled
Packet Priority & VLAN        Disabled
```

Put them back. The defaults are Enabled for every one of them, and the fastest way
back to a known state is `Reset-NetAdapterAdvancedProperty -Name 'Ethernet' -DisplayName '*'`,
which restores every property on the adapter to the driver's default.

## Receive Side Scaling

RSS hashes incoming flows across receive queues so more than one CPU can process
them. Microsoft's description of running without it is that the receive processing
for an interrupt runs on the CPU where that interrupt occurred — one core for all
of it. In practice that is usually CPU 0, though the docs do not promise it.

Leave it enabled. Two honest caveats:

- A single game's UDP flow hashes to one queue, so RSS does not spread *that*
  traffic. What it protects is everything else on the machine that is receiving at
  the same time.
- Not every adapter exposes it. An Intel I225-V on driver 2.1.5.7 lists no `*RSS`
  keyword at all and returns no object from `Get-NetAdapterRss`, while the TCP
  stack still reports RSS as enabled globally. There is nothing to set there, and
  writing `*RSS` into the registry by hand would do nothing.

`*NumRssQueues` sets the queue count and is worth leaving alone; the `0` that
circulates in scripts is not a valid queue count.

## Flow control

Flow control (802.3x) lets the link partner send a PAUSE frame that stops your NIC
transmitting for a period. The default on client Windows is Rx & Tx enabled.

This site's [`net.eee-off`](../../tweaks/network/#net.eee-off) turns it off, and the
honest framing is that this is a judgement call rather than a documented fix:
neither Microsoft nor Intel recommends disabling it on a desktop, and Intel
recommends enabling it for RDMA. The argument for turning it off is that a PAUSE
frame is a hard stop on transmission that you did not ask for, on a home link that
never saturates. The argument against is that it is there to prevent loss on a link
that does.

Windows itself disables flow control while a kernel debugger is attached over the
network, which tells you the failure mode it is worried about.

## Buffers

`*ReceiveBuffers` is the number of receive descriptors the driver allocates. Too
few and packets drop under burst; too many and you have spent RAM and added queue
depth. Microsoft documents raising it for receive-heavy workloads. Intel's
adapters use 2 KB per descriptor with a range of 128–4096 in steps of 64.

It is not a latency setting. Deeper queues add buffering, not less of it. Raise it
only against evidence — discards in `Get-NetAdapterStatistics`:

```powershell
Get-NetAdapterStatistics -Name 'Ethernet' |
  Select-Object ReceivedDiscardedPackets, OutboundDiscardedPackets
```

If those are zero after a long session, the buffers are fine.

## Energy Efficient Ethernet, with a number

EEE (802.3az) puts the PHY into Low Power Idle between bursts. Intel documents that
the wake transition "may introduce a small amount of network latency" without
giving a figure. The figure is in the standard's own wake-time budget: on the order
of 16.5 µs for 1000BASE-T, 30 µs for 100BASE-TX.

Tens of microseconds. That is real, it is measurable on the right equipment, and it
is three orders of magnitude below anything you will feel in a game. Disable it if
you want the link deterministic; do not expect the disabling to show up in a
frame-time capture.

## Sources

- [Network subsystem performance tuning](https://learn.microsoft.com/en-us/windows-server/networking/technologies/network-subsystem/net-sub-performance-tuning-nics) — the low-latency checklist, including "enable static offloads" and "disable interrupt moderation".
- [Standardized INF keywords for network devices](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/standardized-inf-keywords-for-network-devices) — every `*`-prefixed keyword above, with defaults and valid values.
- [Introduction to Receive Side Scaling](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/introduction-to-receive-side-scaling)
- [Interrupt moderation](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/interrupt-moderation)
- [Overview of Receive Segment Coalescing](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/overview-of-receive-segment-coalescing)
- [Get-NetAdapterAdvancedProperty](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapteradvancedproperty)
