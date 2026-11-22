<!-- KIT-CLASS: KIT — the design module's release notes, in the shape of the kit's own; kit-upgrade.sh reads them while the module is enabled. See process/EXTRACTION.md. -->
# The design module — release notes

Each release is a `## [X.Y.Z]` section, newest first. An entry under `### Action required` becomes an item on
the upgrade checklist of a project that has the module enabled and last took an older version; entries under
any other heading are not read. Nothing here is read while the module is disabled.

## [0.6.3]

### Changed

- **A comment sent to Claude is the go-ahead for the change it asks.** The Designer pulls, edits, publishes, reads back, replies and resolves without asking in the terminal, and asks first only when the change would send an approved row back to review, goes beyond the comment or touches a board it does not name, contradicts a recorded decision or a pinned state, deletes a board or replaces an edit not yet pulled, or could mean two designs. A pull no sent comment started still ends at the go-ahead with no human present.
- **A comment sent to Claude is answered only while a session watches the canvas.** With none the thread stays open and awaiting reply, a watch armed later does not replay it, and the page gives no notice; the Designer now reads the threads awaiting reply on every pull and after every publish and answers them (README, role § Comments, `/design-publish` step 7).
- **The mode is per canvas, and the README now says what that means for a mixed need:** a rough board beside a finished one is a second canvas. Nothing in the checker changed.
- **In a wireframe canvas an edit to the wording of `placeholder`, `aria-label`, `alt` or `title` no longer sends an approved row back to review:** the link check lists the row on a `CONTENT-ONLY` line, as it does for text. An attribute added or removed, and every other attribute, still counts as structure.
- **The role and `/design-publish` now say how a canvas is started on the built-in `Artifact` tool** (`quickstart` with intent `design`, a `publish` with the type's `type_url` and a `title`, then the files), that `read` of `artifact-type/dc-runtime.js` saves the runtime `render.py` needs, and what `read` with `paths` and `list` cost on that surface.
- **`/design-pull`'s diff step tells the Designer to state a moved element's old and new parent from the two files**, and to say when it crossed a `data-state` boundary (an editor's drag can paste an element outside its state's container).
- **`/design-pull`'s link check before the go-ahead now reads approvals against the pulled files**, so a `STALE-APPROVAL` or `CONTENT-ONLY` line shows before you say go, not after the take-in. The check checks out nothing and moves no branch or index.
- **The role now says elevation tokens are left out of `tokens.css`** (the converter writes colours, spacing and radius; an elevation is a level in dp), so a screen cannot read one as `var()`; the converter already named each on stderr. Token names are unchanged.

### Fixed

- **The link check no longer hangs on a start tag that is never closed and carries many quoted attributes** (about 18 or more; the gate and the `in_progress/` and `dev_complete/` move check waited with no output); the tag is rejected at once and the next tag is read. `normalise-canvas.py` no longer reads past an unclosed `<script` into the next tag.
- **The link check reads three things as the formats allow, so three false findings stop:** an artboard root whose `data-ux` and `data-stories` are single-quoted, or that follows a comment quoting other ones (a false `ARTBOARD` line); a registry row with no closing `|` (a false `GATE-CELL`); and a card's `design: none #comment` with no space after the `#` (a false `DESIGN-KEY`, and `uncompared` in the pin-drift report). A registry table with no leading `|` is still not read.
- **The link check's `FENCE` line now says a list item or quote that ends before the closing line leaves a fence open, and ends with a `Next:`** (close the fence, or indent every line of it to the item's text).

## [0.6.2]

### Action required

- **A design row says which comparison made it `identical`: `identical (image)` or `identical (structure)`.** The QA cell check refuses a bare `identical` (`names no comparison`), with a `Next:` saying what to write. `identical (image)` is for a seat that opened the pin PNG and the build PNG and compared them; `identical (structure)` is for a seat that read the pinned `.dc.html` against the source, and the check refuses it unless the pin's canvas is a wireframe canvas in effect at the pin; a seat that can do neither writes `diffs: <element ids>` or asks (`requirements/design/README.md` § 5 is the one statement). **Dev now makes both images at handoff**, `UX-NNN-<state>-pin.png` (`git show <pin>:requirements/design/<canvas>/renders/<Screen>-<state>.png > dev/evidence/<card-id>/UX-NNN-<state>-pin.png`) and `UX-NNN-<state>-build.png`, committed to the trunk, so QA has none to make; `dev/evidence/README.md` exempts these two fixed names from naming a file for its AC. A card already holding a PASS design row with a bare `identical` is refused at landing: rewrite the row, with the word for the comparison made. Run the line below first; it names each such card.
  Verify: bad=0; for c in progress/{in_progress,blocked,dev_complete,qa_complete}/*.md progress/subtasks/*/{in_progress,blocked,dev_complete,qa_complete}/*.md; do [ -f "$c" ] || continue; awk -F'|' '$3 ~ /PASS/ && $4 ~ /design/ { p = $5; gsub(/"[^"]*"/, "", p); gsub(/`/, "", p); if (p ~ /@[0-9a-fA-F]+: *identical *([;,]|dev\/|UX-|$)/) f = 1 } END { exit !f }' "$c" && { echo "$c: a design row says a bare identical"; bad=1; }; done; [ "$bad" = 0 ]

## [0.6.1]

### Action required

- **Push the Designer's commits, and push each new one as it is made.** The gates read `origin/<trunk>`; a take-in, an approval or a `Last pull` that only your clone holds is judged missing and reads as a false `STALE-APPROVAL` or `PIN-ORDER`. `/design-pull` and `/design-publish` now run `scripts/design/trunk-sync.sh check` first and stop on a trunk that is ahead, behind or diverged, with a `Next:`; `trunk-sync.sh push` pushes as it is and reads the remote back. A diverged trunk takes `git merge origin/<trunk>`, never a rebase or `register-commit.sh`: either gives a commit a new sha that `CANVAS.md` and the gate cells do not name. Run `trunk-sync.sh check` now; `push` what it names.
  Verify: [ ! -f scripts/design/trunk-sync.sh ] || bash scripts/design/trunk-sync.sh check
- **Push the commit each card in flight is pinned to.** A card lands only when every pin in its `design:` key is a commit the trunk holds; a pin only your clone has is refused at `qa_complete/`, with a `Next:` (push it, or the PM re-pins the entry). The line below reads the trunk as the kit does (`$KWT_REMOTE`, else `origin`; its `HEAD`, else `init.defaultBranch`, else the last-resort name `kit-init` writes into `kanban-worktree.sh`, else `main`) and covers slices and `blocked/`.
  Verify: r="${KWT_REMOTE:-origin}"; b="$(git symbolic-ref --short "refs/remotes/$r/HEAD" 2>/dev/null)"; b="${b#"$r/"}"; [ -n "$b" ] || b="$(git config --get init.defaultBranch)"; [ -n "$b" ] || b="$KWT_TRUNK_LAST_RESORT"; [ -n "$b" ] || b="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="${KWT_TRUNK_LAST_RESORT:-\(.*\)}"$/\1/p' scripts/lib/kanban-worktree.sh 2>/dev/null)"; [ -n "$b" ] || b=main; for c in progress/{in_progress,dev_complete,blocked}/*.md progress/subtasks/*/{in_progress,dev_complete,blocked}/*.md; do [ -f "$c" ] || continue; for p in $(sed -n '/^design:/p' "$c" | grep -oiE '@[0-9a-f]{7,40}'); do git merge-base --is-ancestor "${p#@}" "$r/$b" || exit 1; done; done
- **A screen that reads a token it never declares goes red at the gate.** A token-named property (as `TOKEN-VALUE` names it) that a screen, or a sheet or screen it loads, reads by `var(--name)` with no fallback (`var(--name,)`, an empty fallback, is read as a bare read), when no rule of the screen, its sheets or its imported screens declares it (a `[data-theme]` block's declaration counts), gets no value from the canvas: an elevation or a radius shows nothing in the render. `check-design-links.py --strict` reports it as `TOKEN-UNDECLARED`. Run it first; for each finding the Designer declares the property with the token's value in a `:root` block or in a sheet the screen links, using the artifact tools. An imported screen that reads a token only its importer declares is shown as a `TOKEN-VIA-IMPORTER` line, which is not counted.
  Verify: [ ! -f scripts/design/check-design-links.py ] || { out="$(python3 scripts/design/check-design-links.py --strict 2>&1)"; [ $? -le 1 ] && ! printf '%s\n' "$out" | awk '$1 == "TOKEN-UNDECLARED" { f = 1; print } END { exit !f }'; }
- **A row for a screen that was drawn and then deleted goes red at the gate.** `check-design-links.py --strict` reports an `open` or `changes` registry row whose file is not there, but only when git once held that file, as an `ARTBOARD` finding (`<UX id> is registered (<gates>) but <file> is not there`): a screen briefed in a row and not yet drawn is no finding, nor is any row where git cannot answer (no repository, no commit). Run it first; for each finding restore the file, mark the row `superseded`, or delete the row. The `ARTBOARD` line for an approved row whose file is not there is as before. A row that reuses the file name of a screen deleted earlier is reported too (give it a fresh file name), and a shallow clone that lacks the commit that held a deleted screen reads it as never held.
  Verify: [ ! -f scripts/design/check-design-links.py ] || { out="$(python3 scripts/design/check-design-links.py --strict 2>&1)"; [ $? -le 1 ] && ! printf '%s\n' "$out" | awk '$1 == "ARTBOARD" && / is registered \(/ { f = 1; print } END { exit !f }'; }

### Changed

- **`render.py` stops all of Chrome when a board times out or `render.py` itself is signalled.** Chrome's helper processes (renderer, GPU) are separate processes, and a `--timeout` used to stop only the main one, leaving the helpers spinning on a core each; `render.py` now starts Chrome in its own process group and ends the group (TERM, then KILL after two seconds) on a timeout, on a TERM, HUP or INT sent to `render.py` (which then exits 143, 129 or 130), and after each board. Output and other exit codes are unchanged.
- **`render.py` prints `OVERFLOW <board> <content>px > <board>px` after an `OK` line when a board's content is taller than its size in `canvas.json`**, so a reader who cannot view the PNG still sees a cut-off table. It is a report; the exit code is unchanged. The Designer role doc also says a script that writes boards is committed under `requirements/design/<canvas>/tools/`.
- **A `/design-pull` entered from `/design-publish` step 6 still shows the diff and waits for your go-ahead**; a go given before the diff existed is not one.
- **On the built-in `Artifact` tool, `/design-publish` re-reads every `project/` file just before the send** and stops with `/design-pull` if any sha moved from the manifest, and, if the tool refuses the send as unviewed, reads the page and runs again; step 6 runs `/design-pull` before `Last publish` is written when a read-back sha differs, sent or unsent.
- **The link check says `UNROWED <file>`** for an artboard no registry row names and no screen with a row imports (a report line, never counted), and the `ARTBOARD` lines it prints for a row whose file is not there end in a `Next:`.
- **The pull skill's `both` block names no file whose pulled bytes equal the repo's**, so a send that landed before its record was written no longer stops the pull; **the publish skill, at the first publish too, puts the boards in the pull's spelling first** (`normalise-canvas.py`) and commits what it rewrote, so a `data-props` written spaced, or with `1e3`, is sent compact and a later pull reads no change in it.
- **`m3-tokens.mjs` refuses every argument error** with the usage and exit 64, before it writes anything: a `--name` or `--out` with no value (empty, or another `--` flag), an unknown argument, a second seed.
- **The contrast audit says a token file that holds no colour token** when it is a theme file (`<ns>.<theme>.tokens.json`), or the base file of a namespace that has theme files (unless it only shares non-colour tokens beside a `<ns>.light.tokens.json` and theme files that all hold colours) or of a run that measured nothing (`UNREAD <file>: holds no color.* token, so its theme is not measured`, and for a base file `... so its base theme is not measured`, each with a hint of where colours go), where `{}` or spacing alone left that theme unmeasured and the audit silent; `--strict` fails on it, like an unreadable file. A theme file is any `<ns>.<x>.tokens.json`, so non-colour tokens go in `<ns>.tokens.json`; a namespace of non-colour tokens alone with no theme file stays quiet. `render.py` takes `--suffix -x` spaced as well as `--suffix=-x` (a following option name is not taken as the suffix), and `m3-tokens.mjs --help` exits 0 with its usage (a call with no seed still exits 64).
- **A PRD line of three backticks indented four spaces right after a list item is read as a fence inside that item, as the AC gate reads it** (a list item's text starts after its marker and the spaces that follow it, and a fence opens up to three columns past that). With no closing line it reports `FENCE <file>:<line>: a code fence is never closed`, where it read an indented code block before. Put a line of prose, or a heading, between the list and the block (the block is then code, not a fence), or close the fence.
- **A card or slice whose every AC is `(UI)` is refused at landing** (`qa-verdict-no-observed`): its design row is judged by the cell check but is not core evidence, so the table needs one `test` or `file:line` row, or a row of another kind ending in a quoted `path:line`. **End the design cell with `; <path>:<line> "<quote>"`**, the code that shows the AC met and a verbatim quote of it found on that line, as for a `file:line` quote: the landing re-reads it and the row is the observed row. A quote that does not count is not refused; the refusal lists it when the table has no other observed row. The table keeps one row per AC, and the design checks read the cell without that pointer. A `path:line` that does not resolve is refused as in any row. A card in flight whose only AC is `(UI)` and whose verdict row was a `file:line` row (the 0.3.0 route) takes the `path:line "quote"` of that row onto its `design` row.
- `SETUP.md` step 6 tells you to add the gate row to `GATES` in `scripts/verify.sh`; nothing runs `--strict` until you do. `--leaving` takes the card's file path (`<card file>`), and `README` says `disable` leaves cards in flight pinned.
- **A Designer with no human present ends a `/design-pull` at the uncommitted-file stop and at the go-ahead, says why and does not wait** (`designer.md` rule 11). At the go-ahead it puts `project/` and `CANVAS.md` back as on a "no". Rule 4 now reads "never waits on a pin".

### Fixed

- **A `>` inside a quoted `data-props` value no longer hides a board from `normalise-canvas.py` or reads as a change.** A props value such as `Next >` ended the script tag early, so the board was neither rewritten nor compared in the one spelling; a page save that re-spelled it then read `STALE-APPROVAL` and drift. Both sides now read the tag with quotes honoured.
- **A change to only the root's `data-stories` keeps an approval and a pin whatever the root's layout.** Attributes on their own lines, or a single-quoted value, used to read `STALE-APPROVAL` and drift; the `ARTBOARD` line reads a single-quoted `data-stories` too.
- **A canvas copied from `CANVAS.template.md` and not yet filled in reads clean under `--strict`**: the template's example rows carry the skipped placeholder id `UX-NNN`. **`render.py` ends a timed-out board's reason with a newline**, so reasons of successive boards no longer run together.
- **A page save's re-spelling of a board's `data-props` (the `&quot;` form, or spaces) moves no value, so it is no `STALE-APPROVAL` and no drift** (pin-drift says `respelled`); a changed value still is. A `<ns>.wire.tokens.json` is left out of what a pin and an approval cover. A token file named `dark.tokens.json` or `wire.tokens.json` alone is that theme. A dark value in `:root` or a media query is a `TOKEN-VALUE` that says a theme is a `[data-theme]` block.
- **A card parked in `blocked/` with no pin is no `UNPINNED` finding and no unresolved pin-drift row.** A card's AC bullets are read as the core reads them (a checkbox bullet, numbered or quoted, any id such as `B1`; a plain bullet that says `(UI)` is no AC), and a slice's drift row carries the slice's own id. The design rows check refuses a pin only a local branch holds, saying so when the short sha is ambiguous or a shallow clone may lack the history (`git fetch --unshallow`), and prints a `Next:` for each kind of reason.
- **The audit** labels a pair `LOW light [<ns>]:` when there is more than one token namespace; it takes the larger of `height` and `min-height`, adds a content-box element's padding, leaves a hidden input out, measures each token namespace's pairs apart (a failing pair is no longer hidden by another namespace) and reads an overlay colour in no pair as a `NOTE`, not `UNREAD`.
- **The normaliser** keeps a reference with no `;` as written when a browser would (`&copy=2`, `&copyx`, `?x=1&notify&y=2`), so it neither rewrites the value nor hides a real change as a re-save (a legacy name is kept literal before `=` or an ASCII letter or digit, as the spec says); `resolve-anchor.py` finds a percent-encoded board name; the pull skill's both-sides and drop blocks handle a file name with a space, and its anchor step says how to write an apostrophe.
- The 0.3.0 upgrade item's Verify line fails only on the pin findings it names, not on a stale approval.
- **The link check reads a tag whose quoted attribute value holds a `>`**: a colour literal, a linked sheet or an imported screen after such an attribute is found, where the tag used to end at the `>`. A quote opens a value only after `=`, so an apostrophe in an unquoted value or a stray quote in a name hides nothing after it.
- **The checkers no longer read rare shapes as `clean`.** A token whose value holds an alias inside a longer string (`0 0 1px {base.c}`) follows the alias; a change between two different invalid byte sequences is `uncompared` for a pin and a stale approval; a `<td>`, `<th>`, `<tr>`, `<li>`, `<dt>`, `<dd>`, `<option>`, `<rt>` or `<rp>` ends the open one before it (an `<li>` is not ended across a section or a table), so a shared element after an unclosed cell is no longer read as inside a state's branch.
- **An artboard whose canvas directory moved together with an edit** reads `differs at HEAD` (back to review) instead of `missing at that commit`; in a wireframe canvas the file it was approved at must carry the row's UX id.
- **A screen superseded at HEAD** prints `(screen superseded)` with a Next (re-pin to the row that replaces it) on its pinned state's line, and an approval's sha or a card's pin this clone cannot see names `git fetch --unshallow`; `SETUP.md` says the gate needs full history.

## [0.6.0]

### Added

- **A wireframe mode for a canvas** (`- **Mode:** wireframe [decision: D-NN]` in `CANVAS.md`; requirements `README` § 6). For a canvas that is a wireframe of flow and content kept current with the PRD, with the build as the visual anchor: gate 1 is approved per round and stays good through a change of text, numbers or style (the link check compares structure: the ordered tags, ids, states and links), gate 2 reads `build` and is not judged, and `--strict` shows an `UNCOVERED` or `STALE-PENDING` finding that reaches only such canvases as `UNCOVERED-WIRE` or `STALE-PENDING-WIRE` without counting it. The mode needs a ruling `requirements/DECISIONS.md` holds, or it is not in effect (`WAIVER`). A canvas without the line is read exactly as before, so nothing is required of a project that does not want it.

## [0.5.0]

### Added

- **`/design-pull` and `/design-publish`**, the Designer's canvas order as commands (`.claude/skills/`). The pull lists the canvas once, compares shas, reads only what
  differs one path at a time and verifies each, normalises, resolves each sent comment's anchor, shows the diff and commits only on your go-ahead, and publishes
  nothing. The publish refuses a canvas that moved since the last pull, sends only what changed with the version its check used, stops on a `warnings` entry or a 409 over a
  person's edit, reads back by sha and only then answers and resolves the threads. Each says which surface it is written for (the `claude-artifacts` server, or
  the built-in `Artifact` tool as documented), makes a read-only sign-in call first and ends with a `Next:` when it is refused; nothing passes through a person.
- **`scripts/design/normalise-canvas.py`** gives a page save's re-serialising (a sorted `canvas.json` with an empty `attachments`, a board's `data-props` in `&quot;` form)
  the spelling an agent writes, so the drift checks and approvals read no change where no value moved; **`scripts/design/resolve-anchor.py`** turns a
  sent comment's anchor into `<Board>.dc.html#<element id>`, and says `UNRESOLVED` with the reason when it cannot.
- `COMMENTS.md` gains a `thread` column (the thread's id), so a pull updates a thread it already logged; one made from an older template gets the column by hand (no script reads the table). The pull lays its files over `project/` and runs the link check before you decide, and puts `project/` and `CANVAS.md` back on a no.
- `CANVAS.md` gains a `## Manifest` section: per `project/` file, the canvas sha and the repo sha (they differ only for a file the normaliser rewrote); a `CANVAS.md` made from an older template gets the section from the first pull, which then treats every file as changed.
- Requirements: `claude-code` (2.1.228 or later, optional: the commands and comment replies) and `claude-ai-login` (an agent-side requirement the commands make as their first call).
- The Designer role drops its last needs-the-next-version lines.

## [0.4.0]

### Added

- **The renderer.** `scripts/design/render.py <project/> <out/> --runtime <dc-runtime.js> [--theme wire] [--scheme light|dark] [--scale 2]`
  draws a canvas's boards with Chrome on this machine, the colour scheme forced (light unless asked; Chrome's setting is applied the right way round) and `data-theme` set, so a wire
  review is `--theme wire`. **It needs the design runtime, which the module does not ship**; a copy comes from a person or from a
  session that has the built-in Artifact tool (the claude-artifacts server serves the file's text but writes nothing to disk; that a downloaded
  canvas carries it is untested). Without one it says
  `RUNTIME-ABSENT` and exits 3; without Chrome, `CHROME-ABSENT`. A copy that is cut short, empty or another file draws a plausible
  screen without running, so a board whose page did not report the runtime's hooks is a `FAIL` (`RUNTIME-DID-NOT-RUN`) with no PNG.
- **The audits.** `scripts/design/contrast-audit.py` measures every `on-X` on `X` pair and the text on the surfaces in each theme (WCAG
  4.5:1) and flags a button, link or input styled below 44 px; a report, `--strict` makes a failure the exit status.
- **The token tools.** `scripts/design/m3-tokens.mjs <seed> --name <ns> --out requirements/design/tokens` (Node 22 or later, optional)
  writes Material 3 colour roles, shape, spacing and elevation from one seed as `<ns>.tokens.json`, `.dark` and `.wire` (greyscale);
  the seed's hue and chroma are kept, the same seed gives the same bytes, and the output passes the contrast audit. It uses a vendored,
  patched copy of `material-color-utilities` (Apache-2.0; `scripts/design/vendor/NOTICE`). `scripts/design/dtcg-convert.py` writes a
  design system's `tokens.json` and `tokens.css` from the token files, unprefixed, in the shape the design type's compiler writes; it reads
  `#rgb` and a colour object's `alpha`, and a colour, spacing or radius token it cannot read is named (`NOT CONVERTED`) and the exit status is 1.
  The audit prints `UNREAD` for a colour with an alpha, since its contrast depends on what is behind it, and for a token file that is not JSON
  (`--strict` fails on both); it names the colour tokens outside `color.*` that no pair measures in a `NOTE` line, which does not fail. The
  converter takes a token's family from its `$type` (`brand.leaf` is a colour), not from the head of its path, and writes `0` as given.
  `render.py` notes a file the page asked for that the project lacks (`NOTE-404`) and a `console.error` call from the page (`NOTE-LOGIC`, a board whose logic failed).
- The Designer role drops its three needs-the-next-version lines for these; the packaged `/design-pull` and `/design-publish` skills stay
  on it. No action: nothing runs until the Designer or a person runs it.

## [0.3.0]

### Action required

- **Cards in flight when the `design` module is carried to this version can need one step each.** A card pinned to a commit that holds no render of its state: the PM re-pins its entry to the commit that holds the render (the one allowed re-target); `check-design-links.py --leaving <card>` shows it (`NO-RENDER`), and so does the landing. A card whose `(UI)` AC has QA's `file:line` row: QA writes a `design` row with the images instead (shown at landing). A card with `design: none` and a `(UI)` AC: the PM pins it, or takes the tag off if the card builds no screen (`--strict` shows it, `DESIGN-NONE`). The Verify line runs `--strict` and fails only on the pin findings above (`UNPINNED`, `UNRESOLVED`, `BARE-PIN`, `DESIGN-KEY`, `DESIGN-NONE`, `DESIGN-MISSING`), which it prints; a stale approval (the Designer sets the row to `changes` and has it approved again) or a landed `qa_complete/` card with `design: none` and a `(UI)` AC (the PM closes it to `done/`) is shown by `--strict` and does not hold the upgrade.
  Verify: [ ! -f scripts/design/check-design-links.py ] || { out="$(python3 scripts/design/check-design-links.py --strict 2>&1)"; [ $? -le 1 ] && ! printf '%s\n' "$out" | awk '$1 ~ /^(UNPINNED|UNRESOLVED|BARE-PIN|DESIGN-KEY|DESIGN-NONE|DESIGN-MISSING)$/ { f = 1; print } END { exit !f }'; }

### Added

- **The card gate.** A move check on `in_progress/` and `dev_complete/` (`scripts/move-check.d/in_progress/50-design-pin.sh`, and
  the same file at `dev_complete/`): a card arriving there from `todo/`, or from `blocked/` when it was never in progress, is refused,
  with the reason and a `Next:` line and nothing changed, unless each `design:` entry carries an `@<commit>` that resolves and
  holds the screen, of a row whose `gate1` is `approved@<sha>` (an ancestor of the pin, still true on the trunk), or the line
  carries a `[decision: D-NN]` the register holds. A `design:` of `none`, or one lacking a screen an AC cites (`[design: UX-NNN#state]`),
  is refused when an AC is tagged `(UI)`; a story's `UI:` line alone is only a report line. A card back from `blocked/` that was in progress before
  is checked only for being pinned (drift is reported, not blocked). It judges the trunk's design record and tool; a gate that cannot
  run (no Python, the tool not on the trunk, no answer from it) refuses as broken. Slices are judged like cards.
- **The design rows check.** A move check on `qa_complete/` (`scripts/move-check.d/qa_complete/50-design-rows.sh`, run by
  `finish-pr.sh` before its squash): a card whose AC is tagged `(UI)` or cites a screen needs a verdict row of kind `design` with an
  entry for each state it cites.
- **The design rows check also requires a design row for every `design:` entry of the card** (a card pinned to a screen cannot land
  without the proof, whatever its ACs say); a pin whose commit holds no render of its state is refused by `--leaving` (`NO-RENDER`),
  so Pin-ready names a commit after the PNGs. A `design` row whose images passed the cell check counts as the observed row for the
  landing gate, so a card or slice whose every AC is `(UI)` can land.
- **The QA design-cell check.** A cell check for evidence kind `design` (`scripts/qa-cell.d/design/50-design-cell.sh`, with
  `scripts/design/check-design-cell.py`): the QA gate refuses a PASS row unless every entry reads `identical`, its pin is a commit
  the card carries, both PNGs are committed **on the trunk** (QA commits evidence there with `register-commit.sh`, as the QA role
  says), each is a PNG, the build image is not the pin image, and the pin image is the render the pin commit holds for that screen.
- An enabled project is carried to this version by `kit-upgrade.sh`. Push the trunk so the gate reads it.

## [0.2.0]

### Action required

- **Install Python 3.9 or later.** The checkers below are Python 3 (standard library only), and the manifest now requires it:
  `./scripts/module.sh status design` says whether it holds, and `enable` refuses a project that lacks it. Without
  Python, the new pin-drift report prints a skip line and the gate row's command fails.
  Verify: python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'
- **Screens that carry colour literals, or token values, go red at the gate.** A project whose existing screens hold a colour literal
  (in a style, a style attribute, a presentation attribute, or a sheet or imported screen they load, other than as the value of a custom property
  named for a token, and other than as the `#hex` fallback of `var(--<token>, #hex)` equal to that token's value) fails
  `check-design-links.py --strict` after the upgrade, and so does a custom property named for a token that holds another value than its token (`TOKEN-VALUE`).
  Run it first; for each finding the Designer corrects the screen with the artifact tools so it uses a token, or record a
  `[decision: D-NN]` in the screen's registry row (the entry must be in `requirements/DECISIONS.md` with a Ruling that is not WITHDRAWN).

### Added

- **The checkers.** `scripts/design/check-design-links.py` reports the links between PRD stories, screens and cards in both
  directions (an uncovered `(UI)` AC, an unresolved citation, a row citing no story, a stale `Design: pending`, a stale or
  sha-less approval, a card's malformed `design:` value) and, with `--leaving <card>`, what a card leaving `todo/` owes: a pin, a
  commit that resolves and holds the screen, an approved row that still holds, or a `[decision: D-NN]` waiver on its `design:`
  line that `requirements/DECISIONS.md` confirms. A colour literal in a style, a style attribute, a presentation attribute, or a sheet or imported screen a screen loads, is a finding, except as the value of a custom property named for a token, unless the screen's registry row carries a `[decision: D-NN]` the register holds; a colour in the component script is a report line. A custom property named for a token, with no prefix (`--color-primary` for `color.primary`), must hold that token's value (`TOKEN-VALUE`), read from the selector: `:root` against the base token file, `[data-theme="x"]` against `<ns>.x.tokens.json`; a theme with no file is shown as `UNCOMPARED`. A stylesheet or script is a file under `project/`, linked by a relative path or by a leading `/` read from `project/`; one uploaded to the canvas (`/_blob/<id>`) cannot be read, and the check says `UNREAD` where the pin report says `uncompared`.
  It reads the PRD prefix from `scripts/config.sh` and refuses rather than report on no PRDs.
  `prd-view.py` lists the screens and states one PRD reaches, `flow-from-links.py` derives the screen-flow graph from the
  artboards' links, and `pin-drift.py` compares each pinned state with HEAD. A PRD or story with no `**UI:**` line reads as
  none declared and gets an info line, not a finding.
- **The pin-drift report.** `check-board.sh` prints `[+design-drift]`: for every card past `todo/` and not landed or declined,
  each pinned state as `clean`, `moved`, `drift`, `gone`, `unresolved` or `uncompared` (it could not tell, and says why: never
  `clean`), by its artboard, the tokens it uses and the local files it loads (stylesheets, scripts, images, screens it imports with `<dc-import>`, through `@import`); an uploaded sheet or script, a `var()` naming no token that no loaded sheet declares, or a mark the row does not list gives `uncompared`. A new state on a pinned screen, with its flag added to the component script, is not a change, and a state is compared by the files and tokens its own branch loads. It reports and decides nothing. A screen names a token's custom property by the token's path with hyphens for dots.

### Changed

- The gate row the module puts in `PROJECT.md` runs `python3 scripts/design/check-design-links.py --strict`; it said `N/A`.
  Upgrading replaces the block, or stages it for a merge if you edited it.
- **The Designer authors the canvas itself.** It creates and updates the Claude Design canvas with the artifact tools, by the order in
  its role (list, compare shas, pull first, edit, send with `base_version`, read back by sha); no file or brief passes through a person.
  A `warnings` entry on a publish is a stop. A plain comment was invisible to the Designer on the claude-artifacts server (seen there only): use Send to Claude. The
  packaged `/design-pull` and `/design-publish` skills are not in this version. A colour literal's next act is the Designer
  correcting the screen; the Gate 1 wire review is a local render with `data-theme="wire"` or a separate board, since the page has no
  theme switch; no tool makes a PNG, so a human copies one (Copy as PNG, 2x) or an agent that holds the design runtime renders it.
  The runtime can be read on the `claude-artifacts` surface but not written to disk from there, so a local render needs a copy kept earlier or saved by the built-in tool.
- A screen with its own registry row reports its colours on its own row, not again on a screen that imports it.

## [0.1.0]

### Added

- **The skeleton.** A Designer role (`[Designer]` commits), the rules for `requirements/design/` (layout, ids, citations,
  pins, the two review gates, flows), canvas and comments templates, a `**UI:** none` line minted into a new PRD's first
  story and `design: none` into a new card, the `design` evidence kind, and CORPUS, gate and ignore rows. No action.
- **Not in 0.1.0:** the canvas adapter (`/design-pull`, `/design-publish`), the design drift check, the card gate, the
  token generator and the colour utility, the renderer and audits, and the checkers. The Designer role lists them, and says
  to tell the user a capability needs the next version of the kit rather than improvise it.
