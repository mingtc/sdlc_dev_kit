<!-- KIT-CLASS: KIT — the human steps to start using the design module. Stays in modules/design/; nothing here is placed into a project. See process/EXTRACTION.md. -->
# Setting up the design module

What you do, once, before the Designer is useful. Nothing here needs more than the kit's own git and shell.

1. **Enable it and push.** `./scripts/module.sh enable design`, commit the paths it prints, push the trunk. Until the push,
   `check-board.sh` does not know the `[Designer]` tag.
2. **Start a canvas.** Copy `.claude/templates/design/CANVAS.template.md` and `COMMENTS.template.md` into
   `requirements/design/<canvas>/` as `CANVAS.md` and `COMMENTS.md`, named for the product (never a PRD), and re-mark the copies
   `KIT-CLASS: PROJECT`. In `PROJECT.md`'s gate table the module's row is a rule set with no command yet.
3. **Fill the Designer's project duties** in `.claude/roles/designer.md`: the canvas and its owner, the design system you start
   from, the breakpoint. Write *"this project declares none"* where it is so.
4. **If you use Claude Design:** sign in to claude.ai, create the project there, and put its URL in `CANVAS.md`. Comments reach
   a session only for a canvas private to you or shared within your organisation. In this version you carry files between the
   canvas and the repo yourself, and tell the Designer when the canvas changed.

The pull and publish commands, the drift check, the card gate and the token generator state their own requirements here once
they are installed. While one is absent from your project, asking the Designer for it gets the answer that it needs the next
version of the kit.
