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
   Two habits matter. To make the Designer act on a comment, use **Send to Claude**: a plain comment is invisible to it. To have a
   PNG of a state, use **Copy as PNG** on the canvas (it is 2x); no tool exports one. Comments reach a session only for a canvas
   private to you or shared within your organisation.

The packaged pull and publish skills, the card gate, the token generator and the other tools state their own
requirements here once they are installed. Until the skills are, the Designer follows the order in its role (list, compare shas,
pull first, edit, send with `base_version`, read the result, read back). While one is absent from your project, asking the Designer for it gets the answer
that it needs the next version of the kit, which brings it.
