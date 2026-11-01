<!-- KIT-CLASS: KIT — the human steps to start using the design module. Stays in modules/design/; nothing here is placed into a project. See process/EXTRACTION.md. -->
# Setting up the design module

What you do, once, before the Designer is useful. The checkers need Python 3.9 or later (standard library only): `enable` refuses without it and names how to get it, and `./scripts/module.sh status design` says whether it still holds.

1. **Enable it and push.** `./scripts/module.sh enable design`, commit the paths it prints, push the trunk. Until the push,
   `check-board.sh` does not know the `[Designer]` tag.
2. **Start a canvas.** Copy `.claude/templates/design/CANVAS.template.md` and `COMMENTS.template.md` into
   `requirements/design/<canvas>/` as `CANVAS.md` and `COMMENTS.md`, named for the product (never a PRD), and re-mark the copies
   `KIT-CLASS: PROJECT`.
3. **Add the Designer to `PROJECT.md` § Roles** (`.claude/roles/designer.md`, active) and to the adapter's roles table, which
   must match it.
4. **Fill the Designer's project duties** in `.claude/roles/designer.md`: the canvas and its owner, the design system you start
   from, the breakpoint. Write *"this project declares none"* where it is so.
5. **If you use Claude Design:** run the Designer in a Claude Code CLI or desktop session signed in with `/login` (artifacts are off by
   default in the Agent SDK and with `-p`); the Designer creates the canvas and keeps `CANVAS.md` current. **The Designer authors the
   screens** with the artifact tools and carries nothing to you: you look at the canvas, approve the gates and may change it by hand.
   Two habits matter. To make the Designer act on a comment, use **Send to Claude**: a plain comment was invisible to it (seen on the claude-artifacts server). To have a
   PNG of a state, use **Copy as PNG** on the canvas (it is 2x); no tool exports one. Comments reach a session only for a canvas
   private to you or shared within your organisation.

**What the packaged commands need.** `/design-pull` and `/design-publish` need Claude Code 2.1.228 or later (`claude --version`; comments came in 2.1.221 and
automatic replies in 2.1.228; `enable` checks and only warns, since the checkers need none of it) and a claude.ai account signed in to it: run `/login`. The skills make one
read-only call first (`list_artifacts`) and stop with a `Next:` naming this file when it is refused. The Designer runs `/design-pull` before it changes anything
and after you have edited the canvas by hand: it shows you what changed and commits only on your go-ahead. `m3-tokens.mjs` needs Node 22 or later; `render.py` needs Chrome or Chromium and a copy of the design runtime
that you or a Claude Code session with the built-in Artifact tool provide (the module cannot ship it).
