---
title: Network
description: netsh commands that no longer exist, adapter keywords written blind, and the values that are outside their own valid range.
sidebar:
  order: 2
tags:
  - debunked
  - network
  - registry
---

## `netsh int tcp set global chimney=disabled` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

`chimney` is not a valid argument for `netsh int tcp set global` on Windows 10 or 11.
The command returns an error and changes nothing. TCP Chimney Offload was present in
Windows 8.1 and Server 2012 R2 and deprecated in Server 2016.

## `netsh int tcp set global tcpackfrequency=1` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

`tcpackfrequency` is not a valid `netsh int tcp set global` parameter. It is a
per-interface **registry** value. The command fails. See
[`net.nagle`](../../../tweaks/network/#net.nagle)
for the way that actually works.

## `TcpAckFrequency = 0` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

Microsoft documents this as the number of outstanding ACKs before the delayed-ACK timer
is ignored: range `0`–`255`, default `2`, and **"the value of 0 is not valid and is
treated as the default, 2"**. Writing `0` produces default behaviour that reads as a
change.

`1` acknowledges every segment rather than every second one:
[`net.nagle`](../../../tweaks/network/#net.nagle).

## Disabling RSS (`*RSS = 0`) — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Receive Side Scaling spreads network receive processing across multiple CPU cores.
Without it, receive processing for an interrupt runs on the CPU where that interrupt
occurred — in practice usually CPU 0, though not documented as a guarantee.

On a gigabit link with a modern CPU the effect may be invisible. On anything faster or
under load it is a single-core bottleneck for all network traffic. The Windows default
is on.

Usually travels with `*NumRssQueues = 0`, which is not a valid queue count either.

The rest of that tab:
[network adapter settings](../../../guides/network-adapter-settings/).

## `*ReceiveBuffers = 0` / `*TransmitBuffers = 0` — Invalid, potentially Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid, potentially Harmful</span></p>

Zero is outside the valid range for every driver that exposes these keywords. The
driver either clamps it to its minimum or rejects the value.

The larger problem is how these scripts write the value: they enumerate every subkey
under the network adapter class and write every keyword to all of them, advertised or
not. A driver finding an advanced property it does not recognise can fail to bind,
presenting as an adapter with a yellow exclamation mark in Device Manager after a
reboot.

`Set-NetAdapterAdvancedProperty` queries the driver first.

## `*EEE = 1` and `*FlowControl = 1` under a "disable" comment — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

`1` enables. Scripts carrying this block state that they deactivate both features and
then enable them. Correct version:
[`net.eee-off`](../../../tweaks/network/#net.eee-off).

## `*InterruptModeration = 1` under a "disable" comment — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Same error, same block.

## Setting MTU to 1458 — Situational at best

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Situational at best</span></p>

```text
netsh interface ipv4 set subinterface "Ethernet" mtu=1458 store=persistent
```

1500 is the standard Ethernet MTU and correct on essentially every home connection.
1458 and 1492 come from PPPoE DSL setups where encapsulation overhead reduces the
usable payload.

An MTU smaller than the path supports means more packets for the same data and more
per-packet overhead. It does not reduce latency.

The command also hardcodes the interface name `"Ethernet"`, so it silently does nothing
where the adapter is named otherwise.

To find the actual path MTU:

```powershell
# Increase the size until it fails; add 28 for headers.
ping -f -l 1472 8.8.8.8
```

## "Transmit buffers should be 2x receive buffers" — Placebo

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo</span></p>

A rule with no source and no mechanism. These are ring-buffer descriptor counts — how
many packets the NIC holds before the driver catches up. They set burst headroom, not
speed, and a larger receive ring adds queueing delay under load.

The keywords are also driver-specific and many adapters do not expose them. An Intel
I225-V advertises forty advanced properties, with neither `*ReceiveBuffers` nor
`*TransmitBuffers` among them; it exposes `ITR` instead.

```powershell
# What the adapter actually offers, with the values it accepts
Get-NetAdapterAdvancedProperty -Name 'Ethernet' |
  Select-Object RegistryKeyword, DisplayValue, ValidRegistryValues
```

Raise it where the keyword exists and a measurement justifies it.

## `netsh int tcp set global congestionprovider=ctcp` — Obsolete

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Obsolete</span></p>

Superseded by `Set-NetTCPSetting -CongestionProvider`. On Windows 11 the default for
internet-facing profiles is CUBIC.

## `DisabledComponents = 0xFFFFFFFF` to "disable IPv6" — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

The value is real and read, but the number quoted in guides is wrong. It is a bitmask
under `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters`, and `0xFFFFFFFF` sets
bits with no defined meaning alongside the ones that do. Documented consequences: the
loopback and tunnel interfaces components depend on are also disabled, and boot takes
roughly five seconds longer while name resolution waits on interfaces that no longer
exist.

Where IPv6 must be disabled — on a network that does not route it — the meaningful
values are:

```text
HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters
  DisabledComponents = 0x20   prefer IPv4 over IPv6 in the prefix policy table
  DisabledComponents = 0xFF   disable IPv6 on all non-tunnel interfaces
```

`0x20` addresses resolution order, which is the complaint behind most of these guides.
No measurement attributes a frame-rate change to the IPv6 stack being present on an
idle interface.

## Disabling Nagle globally via `TcpNoDelay` in `Tcpip\Parameters` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

`TCPNoDelay` is read per-interface, under
`Tcpip\Parameters\Interfaces\{GUID}`. Writing it to the parent `Parameters` key
does nothing.

---
