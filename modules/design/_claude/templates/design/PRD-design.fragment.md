<!-- KIT-CLASS: KIT — guide for a PRD that has screens: the `UI:` line, the `(UI)` tag, the `[design: ...]` marker, `Design: pending`, delta stories. Copy what you need into the PRD; the core PRD template does not carry them. See process/EXTRACTION.md. -->
# PRD lines for a PRD with screens

Under a feature while no screen exists (the Designer's input: the states the ACs need):

```
**Design:** pending — UX states needed: <state>, <state>
```

Replace it in the same commit that lands the first marker.

Under every story heading, one line (`none` when the story has no screen), then the ACs. A new PRD is minted with
`**UI:** none` in its first story; copy the line into each further story:

```
##### F1-S1 — <story title>

**UI:** <state>, <state>

- [ ] AC1: (UI) <statement>. [design: UX-001#<state>] [design: UX-002#<state>]
- [ ] AC2: (UI) <an AC that opens a surface is (UI) too>. [design: UX-002#<state>]
- [ ] AC3: <an AC with no screen carries no tag and no marker>
```

- `(UI)` tags every AC that is visible on a screen, including one that opens a surface. It goes **after** the id and its
  separator (`AC1: (UI) …`): the QA gate reads a checklist line only when the separator follows the id directly, and a
  line it cannot read is an AC that needs no verdict row.
- The marker goes **on the AC line**, one per state, one per width where a screen has a pair. Never in Notes: a copied AC
  must carry it. `[design: UX-001]` (no state) means any state and is never pinned. `UX-001..003` is not a citation.
- A marker in a code span or fenced block is prose.

An enhancement to a screen another PRD owns (the owning PRD is edited; nothing a card already carries is): append the
delta story, with its own new id, under a `## Deltas` section at the end of the owning PRD, and edit only the sentences it
makes untrue.

```
## Deltas

- PRD-NNN: <one line>. Sentences edited: <Non-Goals, a design line>.

##### F1-S5 — <story title> *(delta, PRD-NNN)*

**UI:** <state>

- [ ] AC1: (UI) <what the owning feature must keep true>. [design: UX-001#<state>]
```
