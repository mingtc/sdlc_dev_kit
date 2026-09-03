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
     so keep its shape. -->
---
id: PRD-NNN
title: <feature area name>
status: draft           # draft | approved | completed | superseded
                        #   completed = every story delivered (all landed in progress/done/);
                        #   set when the last one lands
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

Newest at the top. Capture forks where one option was chosen over alternatives — and **capture
the reason, not only the conclusion**: a later ruling may supersede the conclusion, and the
reason is what stops the same argument being re-litigated
(`process/doctrine/supersession.md`).

- YYYY-MM-DD: <decision> — <one-sentence reasoning>.

## References

- [PROJECT.md](../PROJECT.md) § <section>   <!-- ../ not ../../ : a PRD lives in requirements/, ONE level down. The card templates beside this one use ../../ correctly because their cards land in progress/<status>/, which is two. -->
- <linked PRDs, design docs, prior art>
