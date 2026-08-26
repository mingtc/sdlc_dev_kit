---
name: <vendored-name>-start-here
description: Use when a task involves <the thing this project handles — name the arrival symptoms, e.g. a URL of this kind, a file of this kind, an object of this kind> and it is not yet clear which tool, which document section or which console command answers it. Route from here first.
---

<!-- KIT-CLASS: KIT — SKELETON. A shape to copy, not a router. install-skills.sh skips EXAMPLE-*.
     Copy this directory to `<vendored-name>-start-here/`, fill every <slot>, delete this comment
     and the two "how to fill this" notes at the bottom. The pattern and the guard that keeps it
     honest are in ../README.md. -->

# Start here

This file **routes**. It carries no answers of its own: every answer already ships with the
vendored artifact, and each row below is the address of one.

> **Version skew.** This pack was copied from a `<vendored-name>` checkout at **<version>** and
> points at that release's sections and commands. If a pointer does not resolve, your vendored
> artifact is older — refresh it with `scripts/update_vendored.sh`, then copy the pack again.

## Which router

| The shape of the task | Open |
|---|---|
| <a task shape stated the way a consumer would say it> | `<vendored-name>-<router-slug>` |
| <a second task shape> | `<vendored-name>-<router-slug-2>` |
| Something was refused, denied, or came back empty | `<vendored-name>-when-it-refuses` |

## The two calls that answer "can it do this at all"

```
<the call that reports every supported surface, machine-readable>
<the call that lists every document section name you may cite>
```

The same ground in prose: `<console-verb> guide --section <capability-section-slug>`.

## Before any first call in a fresh repository

- `<console-verb> guide --section <install-and-pinning-section-slug>`
- `<console-verb> guide --section <configuration-or-credentials-section-slug>`
- `<console-verb> guide --section <choosing-the-right-level-section-slug>`

## The rule this pack lives by

Every file here **points**; none of them restates what it points at. Keep it that way when you
edit one — a second copy of a shipped document drifts away from the artifact silently, and then
the routing sends people somewhere that no longer exists. **If a section you want does not
exist, that is a gap to report upstream, not prose to write here.**

To read one address without leaving the terminal:

```
<console-verb> guide --section <slug>
```

<!-- How to fill this, note 1 of 2 — the `description` is the whole routing decision an agent
     makes before it opens the file. Write it as arrival SYMPTOMS ("a call was refused, denied,
     or returned nothing"), never as internals ("the disposition layer"). -->

<!-- How to fill this, note 2 of 2 — every `<...-slug>` above must be a real, guard-checked
     address (../README.md § The citation guard). Land the guard in the same change as the pack,
     or the first stale slug will be discovered by a consumer's agent instead of by your build. -->
