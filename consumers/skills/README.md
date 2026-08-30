<!-- KIT-CLASS: KIT — the router-pack PATTERN. No pack content travels; author your own. See process/EXTRACTION.md. -->
# The consumer-side router skill pack — the pattern

**What this directory is.** A place for a small pack of **router** skills that a project
ships *to its consumers*, alongside the vendored artifact. A router fires on a **task
shape** and answers with an **address** — the name of a section in the vendored
documents, or the console command to run. It carries **no content of its own**.

**What this directory is not.** It is not a copy of the donor project's pack. The donor's
routers cited that project's own document sections, and porting them would have shipped
dozens of dead addresses. What travels is the **pattern below** plus one skeleton
(`EXAMPLE-start-here/`) showing the shape. `install-skills.sh` skips this README and any
`EXAMPLE-*` directory, so a project that has not authored a pack installs nothing.

**Skip this entirely if your project does not ship to other repositories,** or if its
documents have no stable section addresses to point at (see the precondition below).
A pack is optional machinery; the rest of `consumers/` works without one.

---

## Why a pack of routers rather than a pack of instructions

An agent working in a consumer repo has the vendored documents on disk and no idea which
part of them answers the task in front of it. The gap is **navigation**, not explanation.
So each file is a signpost:

| A router file holds | A router file must not hold |
|---|---|
| The task shapes it fires on (its `description`) | An explanation of how the thing works |
| A table: *what you are trying to do* → *the address that answers it* | A copied recipe, example, or option list |
| The one or two calls that answer "can it do this at all" | A capability claim of its own |
| Where to go next when the routing was wrong | Anything that has to change when the artifact changes |

**The reason is drift, and it is one-directional.** A router that *explains* something the
vendored document already explains is a **second copy** of it — and the copy is the one
that goes stale: the artifact moves, the copy does not, and **nothing tells you**. A router
that only points either resolves or fails loudly. So the routers point and stop.

That is also why thin routers are **not an oversight to fix**. If you improve one, keep it
pointing. And if the section you wanted to point at does not exist, **that is a gap to
report upstream**, not prose to write into a skill file.

---

## The precondition: stable addresses

Routing needs somewhere to route *to*. Before authoring a pack, the project must ship
documents with **named, stable, individually-addressable sections** — a slug per section,
reachable by an accessor or a console verb, e.g.:

```
<console-verb> guide --section <section-slug>       # print one section
<accessor that lists every citable section name>    # enumerate them
```

If sections are only findable by scrolling, a router cannot cite one, and every "address"
becomes a paraphrase — which is the restatement failure above, arriving by the back door.
**Build the addresses first; the pack is downstream of them.**

---

## The citation guard — what makes the pack cheap to keep AND cheap to retire

Hold every address a router cites against the thing that owns it, **in the upstream
project's own test suite**:

1. **Section citations resolve.** Extract every section slug the pack cites and resolve
   each one by asking the real accessor for it. An unresolvable slug fails the **build**,
   not somebody's agent, three weeks later, in another repository.
2. **Console verbs exist.** Extract every command the pack tells an agent to run and check
   it against the command tree the artifact actually registers.
3. **No restatement.** Optionally, hold the pack against the documents themselves: a
   router paragraph that reproduces a document paragraph is the defect this whole pattern
   exists to prevent, and it is mechanically detectable.

**And this is what makes retiring the pack a one-liner.** Because the guard proves every
router holds *only* addresses, no router can be the sole home of anything. Deleting the
pack — `rm -r` plus dropping the install step from onboarding — loses **no** knowledge and
requires **no** archaeology. A pack you cannot cheaply delete has stopped being a pack of
routers.

---

## The A/B rule: a pack must EARN its keep on measures

A router pack is a **hypothesis** — *"an agent given signposts finds the right answer more
often, or faster, than one given the documents alone."* Hypotheses get measured.

- Fix a set of consumer scenarios **before** you look at results, and run each **with the
  pack installed and without it**. Compare on stated measures — did the agent reach the
  right surface, how many wrong turns, did it invent a capability that does not exist.
- **Thinness is part of what is being measured.** Growing a router into a restatement
  before the comparison runs quietly changes what is being compared, and then the result
  tells you nothing about routers.
- **A pack that does not win gets deleted, not defended.** That is the point of the
  retire-cheaply property above.
- Record the run where decisions are recorded in this kit (a run report under `dev/`, per
  `process/templates/run-report.template.md`), so the next session inherits the
  measurement instead of re-deciding on taste.

> Worked example from the donor project (anonymized): its pack was deliberately built to be
> A/B measured, with the design for the comparison written down as its own work item before
> the pack shipped — and the design said, in as many words, that thinness was the variable.
> The lesson kept here is the sequence: **decide the measure, then ship the pack**, because
> a pack whose value is asserted rather than measured never gets removed.

---

## Version skew is the known cost of copying

A copied pack points at the release it was copied from; the consumer's vendored artifact
may be older or newer. Two things make that survivable, and both are non-optional:

1. **Every router states its origin release** in one line near the top, and says how to
   refresh (`scripts/update_vendored.sh`).
2. **The pack is re-copied after every refresh** (`install-skills.sh`), so the pointers and
   the artifact move together. Onboarding says this, and so does the update-communication
   ritual in `process/doctrine/distribution.md` § A.5: a change to the pack **template** is
   worth a re-copy note in the release documents.

---

## Authoring checklist

- [ ] The project ships addressable document sections (the precondition).
- [ ] One router per **task shape** a consumer actually arrives with — not one per feature.
- [ ] A `start-here` router that routes to the others, for the "I do not know which"
      arrival. (`EXAMPLE-start-here/SKILL.md` is that shape.)
- [ ] Every router: frontmatter `name` + a `description` that names the **arrival
      symptoms**, not the internals.
- [ ] Every router: the origin-release line.
- [ ] Zero explanation. Re-read each file asking *"if the artifact changed tomorrow, would
      this line be wrong?"* — if yes, it is content, and it belongs upstream.
- [ ] The citation guard lands in the **same change** as the pack.
- [ ] The A/B measure is designed before the pack is announced as valuable.
