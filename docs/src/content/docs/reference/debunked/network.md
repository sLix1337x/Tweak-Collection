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

`chimney` is not a valid argument for `netsh int tcp set global` on Windows 10 or
11 — the command returns an error and changes nothing. TCP Chimney Offload itself
lasted longer than the usual telling: it was still present in Windows 8.1 and
Server 2012 R2 and was deprecated in Server 2016. Either way, every tweak script
carrying this line has been printing an error to `nul` for years.

## `netsh int tcp set global tcpackfrequency=1` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

`tcpackfrequency` is not a valid `netsh int tcp set global` parameter. It is a
per-interface **registry** value. The command fails. See
[`net.nagle`](../../../tweaks/network/#net.nagle)
for the way that actually works.

## `TcpAckFrequency = 0` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

Microsoft documents this value as the number of outstanding ACKs before the
delayed-ACK timer is ignored: range `0`–`255`, default `2`, and **"the value of 0
is not valid and is treated as the default, 2"**. So writing `0` gets you default
behaviour and the belief that you changed something.

`1` is the value that does what these scripts are reaching for — acknowledge every
segment rather than every second one. It is [`net.nagle`](../../../tweaks/network/#net.nagle).

## Disabling RSS (`*RSS = 0`) — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Receive Side Scaling spreads network receive processing across multiple CPU cores.
Microsoft's description of running without it is that the receive processing for an
interrupt runs on the CPU where that interrupt occurred — one core for all of it.
In practice that is usually CPU 0, though nothing documents it as a guarantee.

On a gigabit link with a modern CPU you may not notice. On anything faster, or
under load, you have created a single-core bottleneck for all network traffic. The
Windows default is on, and it should stay on.

It usually travels with `*NumRssQueues = 0`, which is not a valid queue count
either.

RSS is one property on a tab full of them, and the rest of that tab is covered in
[network adapter settings](../../../guides/network-adapter-settings/).

## `*ReceiveBuffers = 0` / `*TransmitBuffers = 0` — Invalid, potentially Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid, potentially Harmful</span></p>

Zero is outside the valid range for every driver that exposes these keywords. The
driver either clamps it to its minimum or rejects the value.

The deeper problem is how these scripts write the value. They enumerate every
subkey under the network adapter class and write every keyword to all of them,
whether the driver advertised the keyword or not. A driver that finds an advanced property it
does not recognise can fail to bind, which presents as an adapter with a yellow
exclamation mark in Device Manager after a reboot.

`Set-NetAdapterAdvancedProperty` queries the driver first. That is why the new
script uses it.

## `*EEE = 1` and `*FlowControl = 1` under a "disable" comment — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

`1` enables. Scripts carrying this block announce that they are deactivating both
features and then enable them, which is the wrong direction for latency. The
correct version is
[`net.eee-off`](../../../tweaks/network/#net.eee-off).

## `*InterruptModeration = 1` under a "disable" comment — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Same error, same block.

## Setting MTU to 1458 — Situational at best

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Situational at best</span></p>

```text
netsh interface ipv4 set subinterface "Ethernet" mtu=1458 store=persistent
```

1500 is the standard Ethernet MTU and is correct on essentially every home
connection. 1458 and 1492 come from PPPoE DSL setups where the encapsulation
overhead genuinely reduces the usable payload.

Setting a smaller MTU than your path supports means more packets for the same data
and more per-packet overhead. It does not reduce latency.

The command also hardcodes the interface name `"Ethernet"`, so it silently did
nothing on any machine where the adapter was named anything else — which is most of
them.

If you actually want to find your path MTU:

```powershell
# Increase the size until it fails; add 28 for headers.
ping -f -l 1472 8.8.8.8
```

## "Transmit buffers should be 2x receive buffers" — Placebo

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo</span></p>

A rule with no source and no mechanism behind it. These are ring-buffer descriptor
counts — how many packets the NIC can hold before the driver has to catch up. They
set burst headroom, not speed, and a larger receive ring adds queueing delay under
load rather than removing it.

The advice also assumes the keywords exist. They are driver-specific and plenty of
adapters do not expose them at all. An Intel I225-V, for instance, advertises forty
advanced properties, and neither `*ReceiveBuffers` nor `*TransmitBuffers` is among
them. It exposes `ITR` instead.

```powershell
# What your adapter actually offers, with the values it will accept
Get-NetAdapterAdvancedProperty -Name 'Ethernet' |
  Select-Object RegistryKeyword, DisplayValue, ValidRegistryValues
```

If the keyword is there and you have a measured reason, raise it. "Higher is faster"
is not one.

## `netsh int tcp set global congestionprovider=ctcp` — Obsolete

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Obsolete</span></p>

Superseded by `Set-NetTCPSetting -CongestionProvider`. On Windows 11 the default
for internet-facing profiles is CUBIC, which is a reasonable default. Changing it
without a measured reason is guesswork.

## Disabling Nagle globally via `TcpNoDelay` in `Tcpip\Parameters` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

`TCPNoDelay` is read per-interface, under
`Tcpip\Parameters\Interfaces\{GUID}`. Writing it to the parent `Parameters` key
does nothing.

---
