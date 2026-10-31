<!-- KIT-CLASS: KIT — the human steps to start using the design module. Stays in modules/design/; nothing here is placed into a project. See process/EXTRACTION.md. -->
# Setting up the design module

What you do, once, before the Designer is useful. Nothing here needs more than the kit's own git and shell.

1. **Enable it and push.** `./scripts/module.sh enable design`, commit the paths it prints, push the trunk. Until the push,
   `check-board.sh` does not know the `[Designer]` tag.
2. **Start a canvas.** Copy `.claude/templates/design/CANVAS.template.md` and `COMMENTS.template.md` into
   `requirements/design/<canvas>/` as `CANVAS.md` and `COMMENTS.md`, named for the product (never a PRD), and re-mark the copies
   `KIT-CLASS: PROJECT`.
3. **Add the Designer to `PROJECT.md` § Roles** (`.claude/roles/designer.md`, active) and to the adapter's roles table, which
   must match it.
4. **Fill the Designer's project duties** in `.claude/roles/designer.md`: the canvas and its owner, the design system you start
   from, the breakpoint. Write *"this project declares none"* where it is so.
5. **If you use Claude Design:** sign in to claude.ai, create the project there, and put its URL in `CANVAS.md`. Comments reach
   a session only for a canvas private to you or shared within your organisation. **Claude Design's agent makes the screens**, not you and not the
   Designer: the Designer writes the brief in `CANVAS.md` § Brief (the UX id, states, element ids and tokens), you give it to that
   agent, and you carry its files, a PNG export of each state, and its comments back to the Designer, with any change request
   going the other way. You look and approve; you do not draw. Until `.claude/skills/design-pull/SKILL.md` is in your project
   you are that conduit; creating and updating the artifact directly is the adapter's.

The pull and publish commands, the drift check, the card gate, the token generator and the other tools state their own
requirements here once they are installed. While one is absent from your project, asking the Designer for it gets the answer
that it needs the next version of the kit, which brings it.
