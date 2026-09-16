<!-- KIT-CLASS: KIT — PRD template. Two placeholders are STAMPED by the
     initializer: the ISSUE-PREFIX token and the TRUNK token, and this directory is one the
     initializer reaches. **The tokens are described rather than spelled here on purpose** — a
     header that names them literally is rewritten by the very substitution it is explaining, and
     every initialized tree then carried a sentence with no referent.
     Everything else in angle brackets is for the author to fill in — never leave one in a live
     issue. If your initializer has not wired a key, substitute it by hand before first use. -->

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — requirements/ — NOT to the directory it
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape IN THE TEMPLATE.
     IT IS GUIDANCE, AND GUIDANCE IS DELETED ONCE THE FILE IS FILLED: this block addresses
     whoever maintains the template, not whoever reads the card. Delete it from the minted card
     along with every other comment — a card is read on every session that touches it, so a line
     that survives here is paid again by every reader, forever. -->
---
id: PRD-NNN
title: <feature area name>
status: draft           # draft | approved | completed | superseded
                        #   completed = every story delivered (each reached
                        #   progress/qa_complete/); set when the last one lands.
                        #   NOT progress/done/ — that shelf is reached only by a later
                        #   archive.sh sweep, so waiting for it would leave a fully
                        #   delivered PRD reading `approved` for as long as nobody archives.
owner: PM
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
supersedes: []          # PRD IDs this replaces, if any
references: []          # other PRDs this depends on or relates to
superseded_in_part: []  # parts of THIS PRD a later ruling overturned — entries read
                        #   [<issue-id> → <section>], e.g. [<PREFIX>-356 → F2 § S3]
                        #   annotate IN THE SAME CHANGE as the ruling; orthogonal to status
                        #   (superseded in part is NOT status: superseded)
                        #   the rule: process/doctrine/supersession.md
---

# PRD-NNN — <feature area name>

> Status: <draft | approved | completed | superseded>. Last updated YYYY-MM-DD.

## Context

One paragraph: the user, the situation, why now. Ground it in `PROJECT.md` where it applies — cite the section.

## Goals

Measurable. Early in a project most goals are binary ("users can X", "Y is visible in the demo"). Strategic items get a metric.

- <goal 1>
- <goal 2>

## Non-Goals

Explicit list of things this PRD does **not** cover. This is what protects Dev from scope creep and tells QA what NOT to flag.

- <non-goal 1>
- <non-goal 2>

## Features

A PRD groups one or more features. Each feature has a number (`F1`, `F2`, …) and one or more stories. Issues in `progress/` reference these IDs as `PRD-NNN § F1 § S1`.

### F1 — <feature name>

One paragraph: what this feature does, at the level a stakeholder understands. No implementation detail.

#### Stories

Index of stories in F1.

| ID | Story | Priority | AC summary |
| --- | --- | --- | --- |
| F1-S1 | As a <role>, I want to <action>, so that <outcome>. | P0 | <one line> |
| F1-S2 | As a <role>, I want to … | P1 | <one line> |

##### F1-S1 — <story title>

**Acceptance Criteria** — written so QA can verify each one independently. Given/When/Then, or a numbered checklist.

- [ ] AC1: <statement>
- [ ] AC2: <statement>

**Every illustrative example inside an AC cites its source or is labelled approximate** — an
AC example is read as the contract, not as decoration. Name where the fact came from, or say
plainly that it is *illustrative and unverified*.

**Notes / open questions:** <anything Dev or QA needs to know that isn't in the AC>

##### F1-S2 — <story title>

(repeat the same shape)

### F2 — <next feature>

(repeat the feature block; PRDs commonly hold 1–5 features)

## Success Metrics

Early on, most items are binary (works / doesn't). Strategic items get a metric.

- <metric 1>
- <metric 2>

## Open Questions

Tagged with who needs to answer, and marked blocking vs informational.

- [ ] (PM) <question>
- [ ] (Dev) <question>
- [ ] (stakeholder) <question>

## Decision Log

**A CITATION LIST, not an authoring site.** Every fork that constrains this PRD is ruled **once**, in
the decision register ([`DECISIONS.md`](DECISIONS.md)), under a stable `D-NN` id. This section lists
the ones that govern this PRD, so a reader rebuilding the feature sees every governing fork without
hunting — and each row resolves into the register rather than restating it.

**Cite by id; never inline the ruling's text.** A copy here is a second authoring site, and it is the
copy that drifts. The register's **Why** field is where the reason is written — *capture the reason,
not only the conclusion* is that field's instruction, stated in
[`process/templates/DECISIONS.skeleton.md`](../process/templates/DECISIONS.skeleton.md) § *Which
decisions live HERE*, because a later ruling may supersede the conclusion and the reason is what
stops the same argument being re-litigated
([`process/doctrine/supersession.md`](../process/doctrine/supersession.md)).

**What goes here versus what amends the PRD above** is the fork/fact split, and the diagnostic is one
question: *could a competent stranger, reading only this PRD, arrive at a different answer and be
reasonable?* **Yes** → it is a fork; rule it in the register and cite it here. **No** → it is a fact;
amend the relevant section above and cite nothing.

**Format law: the marker is `[decision: D-NN]`** — anchored, so prose *about* a ruling is never read
as a citation of one. A board check joins each marker to the register's `### D-NN` headings: a
citation to an id that does not exist, or to a retired one, is a finding.

- `[decision: D-NN]` — <the ruling's short title, as the register's heading spells it>

## References

- [PROJECT.md](../PROJECT.md) § <section>   <!-- ../ not ../../ : a PRD lives in requirements/, ONE level down. The ISSUE/BUG/REFACTOR card templates beside this one use ../../ because their cards land in progress/<status>/, which is two. SUBTASK.template.md is the exception and uses ../../../ — its cards land in progress/subtasks/<PREFIX>-NNN/<status>/. Read each template's own destination line rather than this sentence. -->
- <linked PRDs, design docs, prior art>
