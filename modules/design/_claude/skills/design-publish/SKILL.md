---
name: design-publish
description: Use when the Designer must send repo changes to the Claude Design canvas — a new or changed screen, a sheet, canvas.json. Refuses unless the canvas still equals the last pull, sends only the files that changed with the version the check used, reads a warning against the manifest and stops on an edit it never pulled, reads back by sha, then answers and resolves the threads it addressed.
argument-hint: "<canvas folder under requirements/design/>"
---
<!-- KIT-CLASS: KIT — the design module's publish skill: the Designer's order for sending to the canvas, with the guards that make a stale send impossible to miss. Placed by `scripts/module.sh enable design`. See process/EXTRACTION.md. -->

# Design publish

Send what the repo holds to the canvas, safely. You do every step; nothing passes through the human, who looks at the canvas and approves gates.
Wear the Designer hat first (`.claude/roles/designer.md`); its § Conflicts has the table of results and what each means.

```
/design-publish $ARGUMENTS
```

## 0. Which surface, and are you signed in

Name your surface in one line before anything else: look at your tools.

- **A: the `claude-artifacts` server.** `list_files`, `read_file` and `publish_files` are among them. This skill is written for A.
- **B: the built-in `Artifact` tool.** `Artifact` is among them. Its steps differ in the notes marked **On B**, which come from the documentation and not from a run.
- **Both:** use A. **Neither:** do not improvise and write no local stand-in. Say: "No artifact tools in this session, so nothing was sent to the canvas."
  End with `Next: run the Designer in a Claude Code session signed in with /login (modules/design/SETUP.md).`

Then make the sign-in call once: `list_artifacts` with `limit: 1` (A) or the `Artifact` tool's `list` (B). If it is refused, stop with
`Next: run /login in Claude Code, then run /design-publish again (modules/design/SETUP.md).` An empty list is a pass.

## 1. The first publish

`CANVAS.md` says `Last pull: none` and has no canvas URL: this is a new canvas. Read the Design type's instructions and `format.md` first (`list_types`,
`describe_type`), `list_artifacts` with `type: "Design System"` for a system to use, then `create_from_type` **once**, record its URL and `version`
in `CANVAS.md`, and send `project/canvas.json` and `project/Main.dc.html` first (the first board is always `Main.dc.html`), then each other file, one
publish each, with the `version` the last result gave. Then step 6. Every later publish starts at step 2.

## 2. List, once, and refuse a canvas that moved

A: `list_files <slug>`. Keep its `version` as `V`: **the one list serves the check and the send**. Set every `project/` sha beside the manifest's
**canvas sha** in `CANVAS.md`. If any file differs, is new or is gone, **stop**: someone changed the canvas since your last pull, and sending now would
replace it. Say so and run `/design-pull` first. A version id that moved alone, with every sha equal, is no change. **One exception:** a file the human
has told you, in this conversation, to restore (they reject the canvas's edit of it) may differ; it goes in the set (step 3) with the repo's bytes, and every other difference still stops. **On B:** `list` has no hash, so read
every `project/` file with `read` (it reports each sha) and compare those.

## 3. The set to send

Every `project/` file whose current repo sha differs from the manifest's **repo sha** (a file you edited), plus repo-only files, plus
`canvas.json` only when the layout changed, plus a file the human named to restore. **Never `git diff` against the pull commit:** it misses a canvas edit the
human rejected, which only they can name. A file the repo dropped goes in `remove`; a file the canvas dropped (the pull took the deletion in) is not repo-only and is not sent back.
Send nothing else; an unchanged file is not resent. Commit the files you are about to send before the send, so `Last publish` can name a commit that holds them.

## 4. Send

A: `publish_files <slug>` with `base_version: V` (the version from step 2, not a new list), `mode: "patch"`, and the files by absolute path
(`as` is the served path, such as `project/Timer.dc.html`). One call for the set. **On B:** `publish` takes a `root` and `files`, and refuses a repo path as
`root`: stage a copy (`rsync -a --delete` the set into a temporary folder, `diff -r` it against the repo) and publish from there.

## 5. Read the result: a warning stops you

- A conflict (HTTP status 409) with a `changed` entry marked `wouldOverwrite: true`, or `liveEntry: "page"`: **do not resend your bytes with `live`.** That publish succeeds and
  replaces a person's edit. Run `/design-pull`, then redo your change on what it brought.
- A conflict (HTTP status 409) with `changed` and no `wouldOverwrite`: others moved, yours did not. List again, check step 2, then send the same set with the new `version`.
- **Success with a `warnings` entry:** the server warns whenever the version before yours came from a page save and you replaced a file in it, even when you had read
  that save. Compare each file it names with what step 2 listed, and with the manifest.
  - **Its listed sha equals the manifest's canvas sha:** the person's edit was pulled before you sent, and your change sits on top of it. Tell the human exactly
    that, restore nothing, and go to step 6.
  - **A file the human named to restore (step 2):** that is what they asked for. Say that you replaced the canvas's edit of it as they said, restore nothing, and go to step 6.
  - **Any other file, or one the manifest lacks: stop.** You replaced an edit you never pulled. Tell the human which files. The tool will not copy an earlier version
    back: if `CANVAS.md`'s `Last pull` commit holds the bytes, restore them and say so; if not, ask the human.
- A third refusal: tell the human and stop.

## 6. Read back, then record

A: `list_files` again. Every file you sent has the sha of the repo bytes you sent (the canvas holds exactly those bytes); every file you did not send has
its manifest canvas sha. This is required **despite the type's "never verify" rule**: that rule stops layout re-checks during a creation run, and this is a hash
comparison with no render, which this role makes a standing instruction. A publish reports no bytes and the server accepts stale bytes on the live version, so
the read-back is the only proof. A file whose sha differs, sent or unsent, was changed by someone since your list: run `/design-pull` before anything else,
and never re-send.

Write the new `version` and the manifest into `CANVAS.md`: `Last publish: <version> @ <repo commit>` (the commit that holds what you sent, made before the send),
canvas sha and repo sha now equal for what you sent. Commit `CANVAS.md` (`[Designer] design: publish <canvas>`).
If you changed one file with `edit_version` instead of step 4's `publish_files`, no local bytes exist: read the file back (`read_file`) and compare it with your change applied to the copy you pulled.

## 7. Answer the threads you addressed

Only now, with the change published and read back. For each thread in `COMMENTS.md` the change answers: `reply_comment` saying what changed and where. On
`summon_already_answered` an automatic reply stands: pass its `standing_reply.id` as `continues_reply_id`; an automatic reply is an acknowledgement, not the
change. Then `resolve_comment`. Both work without asking only on an artifact nobody else can open; on a shared one use `reply_shared_comment` and the user resolves.
Set the row `resolved` in `COMMENTS.md`. A plain comment never reached you (it is invisible on A); if the human mentions one, ask them to Send it to Claude.
**On B** the same comment tools are documented to exist; not observed.

Tell the human what was sent, the new version, and what to look at on the canvas. Publishing starts a watch in a session that can be woken; the `watch` tool
answered `not_armed` where this was observed, so do not promise the human a wake-up.
