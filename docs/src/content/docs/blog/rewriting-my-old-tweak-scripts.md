---
title: What I found when I re-read my own tweak scripts
date: 2026-09-02
authors: slix
excerpt: Three batch files I had trusted for two years, read properly for the first time. About a third of what they did was nothing, and some of it was actively working against me.
---

This collection started as three batch files and a text file of notes. I wrote them
around 2023, ran them on every reinstall since, and never went back to read them.

When I finally did, here is what was actually in there.

## Things that did nothing at all

`netsh int tcp set global chimney=disabled` targets TCP Chimney Offload, removed
from Windows after 7. `wmic`, which one whole script depended on to enumerate
adapters, was dropped from Windows 11 in 24H2. Both had their output redirected to
`nul`, so they reported success every single time.

`TcpAckFrequency = 0` was in there too. Zero is not a valid value for that key — the
valid ones are `1` and `2`. The stack ignored it and I got default behaviour while
believing I had disabled delayed ACK.

## Things that did the opposite of what I thought

This is the one that stung. Under a comment block announcing that it was
deactivating them, the network script wrote:

```text
*EEE          = 1
*FlowControl  = 1
*InterruptModeration = 1
```

`1` enables. So the script I ran to *lower* latency had been very slightly raising
it, on every install, for two years.

The same script also disabled Receive Side Scaling, which pins all network interrupt
processing to CPU 0. On a machine with sixteen cores.

## Things that broke something else

The NVIDIA script disabled HDCP. That does nothing for performance — what it does is
break the copy protection handshake on the display output. I had spent a while
wondering why Netflix looked so bad in my browser.

It also wrote twenty-two undocumented `RM*` registry values into the display
driver's class key, after asking me to type my GPU class GUID in by hand, with no
validation and all output suppressed. Several of them disabled clock gating, which
keeps parts of the GPU powered that would otherwise idle — more heat, less boost
headroom.

## What I actually kept

Twenty tweaks, out of roughly sixty registry values. The ones that survived can each
answer four questions: what mechanism they change, whether that is still true on
current Windows, what they cost, and how to undo them. That is now
[written down](/Tweak-Collection/start/method/) rather than assumed.

Everything I threw out is [on its own page](/Tweak-Collection/reference/debunked/),
with the reason. That list is longer than the list of things I kept, which tells you
something about how much of this stuff is worth copying.

## The lesson, such as it is

None of this was malicious or even unusual — it is what happens when you copy
snippets from forum posts, watch a number move, and never re-check. The scripts felt
like they worked because I had no baseline to compare against.

So: measure first, change one thing, measure again. It is slow and it is the only
way I have found to end up with a list I can defend.
