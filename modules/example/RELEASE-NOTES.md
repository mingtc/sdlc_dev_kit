<!-- KIT-CLASS: KIT — the example module's release notes, in the shape of the kit's own; kit-upgrade.sh reads them while the module is enabled. See process/EXTRACTION.md. -->
# The example module — release notes

Each release is a `## [X.Y.Z]` section, newest first. An entry under `### Action required` becomes an item on
the upgrade checklist of a project that has the module enabled and last took an older version; entries under
any other heading are not read. Nothing here is read while the module is disabled. An entry may carry an indented
`Verify: <command>` line, as the kit's own do: `--finish` runs it in the project and refuses on a non-zero exit.

## [0.1.0]

### Action required

- **Enable the toy through `module.sh`, not by copying its files.** A role layer for the toy without a record of the
  module means its files were copied by hand, and `module.sh disable` cannot take them back.
  Verify: [ ! -e process/roles.d/example ] || grep -q '^module example ' process/MODULES

### Added

- **The toy module.** It adds a role, a skill, an arm, an evidence kind with its cell check, a move check, two
  fragments, a table in `PROJECT.md` and a `.gitignore` block, to show where each lands. No action.
