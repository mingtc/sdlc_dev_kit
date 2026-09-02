<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR precedents and wiring. -->
# Supersession doctrine — how a ruling is amended, and how a spec records being half-overtaken

**KIT-CLASS: KIT.** Rules promoted from practice to law. They answer the same question —
*what happens to the old record when new evidence arrives* — at differing **altitudes**, from a
**recorded decision** to a **specification that is only partly overtaken**. *(The § A headings are
the list. A number written here — or a naming of the members, which is the same census in prose —
would go false the first time this sheet grew.)*
§ A is the transferable pattern; § B is where **your** project records its own instance.

**Neighbour sheet:** [`negative-claims.md`](negative-claims.md) governs **making** a claim
(enumerate the attempts, or say "unmeasured"); this one governs **amending** one.

**Why these are written at all.** A precedent nobody wrote down removes no arbitrary choice: the
next session cannot find it, so it re-decides. Both rules exist to stop the same failure —
**a rationale-free strike causes re-litigation.** Delete the reason and the argument that
produced it returns, unrecognised, in six weeks; leave a spec silently half-false and it is
worse than an absent one, because it will be believed.

---

## A. The pattern (this is the transferable part)

### A.1 — **Preserve the reason, supersede only the conclusion**

> When new evidence overturns a recorded decision, the record keeps the **original reason** and
> replaces only the **conclusion**, saying what changed and why. A guard that enforced the old
> conclusion is **transformed, never deleted** — the assertion moves to the new truth rather
> than vanishing.

Both halves are load-bearing, and each fails differently when dropped:

- **Keep the reason.** The reason is what a future reader needs to know whether *their* new
  evidence is the same evidence. An amendment that reads only "X is now allowed" invites the
  next session to re-open the whole question — or, worse, to re-derive the *old* conclusion
  from the reason nobody recorded. Write it as *the reason stands; the conclusion changed for
  this narrow class, because …*.
- **Transform the guard, never delete it.** A test that enforced the old conclusion is the only
  executable memory of it. Deleting it removes both the stale assertion **and** the coverage;
  moving the assertion to the new truth removes only the stale part. If the new truth is
  genuinely unguardable, say so in the amendment — do not let a deletion pass as a move.

This is the difference between an **amendment** and an **erasure**, and it is why a reader of
an amended rule can still see *what the rule is* **and** *why the previous rule existed*.

### A.2 — **`superseded_in_part` — a spec records which parts a later ruling overtook**

A specification is written once and then partially overtaken by later rulings. Nothing marks
which parts, so a reader cannot tell whether a story's acceptance criteria are still law or were
quietly superseded two tranches ago. The convention:

> When a later ruling overturns **part** of a spec or story, the spec's frontmatter is annotated
> **in the same change** as the ruling, in a `superseded_in_part` list whose entries read
> `[<issue-id> → <section>]`.

```
superseded_in_part: [<PREFIX>-042 → F2 § S3]      # <issue-id> → <section>
```

It joins the existing `supersedes: []` / `references: []` frontmatter fields.

- **"In the same change" is the load-bearing half.** An annotation promised for later is an
  annotation that does not happen. The ruling and its annotation land together, or the ruling is
  not finished.
- **It is orthogonal to `status`.** A spec superseded *in part* is **not** `status: superseded`
  — that value is for a spec replaced whole. A `draft`, `approved` or `completed` spec can carry
  `superseded_in_part` entries and keep its status unchanged.
- **It is a pointer, not a rewrite.** The entry names *where* to look; the reason and the new
  conclusion live in the ruling itself, per § A.1. The spec's own prose is left alone.
- **Document it in three places** so a session cannot miss it: the spec-authoring role doc (where
  a ruling is authored — `.claude/roles/pm.md` in a stock installation), the spec template's
  frontmatter (where a new spec inherits it — `.claude/templates/PRD.template.md`), and this rule
  statement. The **format string is quoted identically** in all three.

**How to adopt:** take § A.1 verbatim — it is project-agnostic. For § A.2, take the convention
and point it at your own spec template and your own spec-authoring role doc; the field name and
the `[<issue-id> → <section>]` shape are the parts worth keeping identical.

**And bind it to the moment of the change, not to a sweep.** A supersession owed "later" is the
same defect as a retirement stamp owed later; the trigger list and the who-holds-the-pen rule are
[`staleness.md`](staleness.md) § A.1 (trigger T3).

---

## B. Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing in this section is inherited. Replace the
> guidance below with your own entries as you accumulate them; an empty § B on day one is
> correct, a § B still empty after your first amendment is a defect.

**What goes here, and nothing else:**

1. **Your precedents for § A.1** — one line each: the ruling, what new evidence arrived, which
   conclusion narrowed, and **where the guard moved to** (or the explicit statement that the new
   truth is unguardable). A precedent with no guard-disposition line is half a record.
2. **Your § A.2 wiring** — the three concrete file paths that carry the `superseded_in_part`
   convention in your installation (the spec-authoring role doc, the spec template's frontmatter,
   and this sheet), so a session can check all three agree.
3. **Your retro-annotation policy.** State it once. The recommended default, and the reason:
   **the convention applies going forward and no existing spec is retro-annotated**, because
   retro-annotation means re-reading every past ruling and is its own work item with its own
   verification burden. Announcing a sweep you will not run is worse than declaring the boundary.

### A worked example from the donor project (anonymized) — keep the reason, not the ids

*One instance, preserved because the pattern above is only credible with a case behind it.*

The donor had a recorded decision covering a data-creation call with two halves. New measurement
overturned **one** half. The amendment kept the original reason on the record verbatim, replaced
only that half's conclusion, and **transformed** the guard test that had enforced the old
conclusion — the assertion moved to the new truth instead of being deleted. Two later rulings
followed the same shape before anyone wrote the rule down: three issues, one ethic, zero written
rules, which is exactly the condition doctrine exists to end.

A second instance of the same shape, from the same project's house rules rather than an issue: a
standing *"no new tooling dependencies"* rule was amended for one narrow class (a
development-only test plugin that never reaches a consumer). The amendment **kept the original
reason in full** — the toolchain stays small — and marked exactly which conclusion the new ruling
superseded. That is the whole of the pattern: the reason survives, one conclusion narrows, and the
narrowing names its class.
