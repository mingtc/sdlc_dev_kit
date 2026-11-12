<!-- KIT-CLASS: KIT — the example module's release notes, in the shape of the kit's own; kit-upgrade.sh reads them while the module is enabled. See process/EXTRACTION.md. -->
# The example module — release notes

Each release is a `## [X.Y.Z]` section, newest first. An entry under `### Action required` becomes an item on
the upgrade checklist of a project that has the module enabled and last took an older version; entries under
any other heading are not read. Nothing here is read while the module is disabled.

To give a release an entry, add a `### Action required` heading to its section and a bullet beneath it. A bullet
may carry an indented `Verify: <command>` line, as the kit's own do: `--finish` runs it in the project and
refuses on a non-zero exit. Write a command that tests the state the bullet asks for in a project that did it;
one that is true whether or not the project did it checks nothing. This first release owes no one an action, so
it has no such heading.

## [0.1.0]

### Added

- **The toy module.** It adds a role, a skill, an arm, an evidence kind with its cell check, a move check, two
  fragments, a table in `PROJECT.md` and a `.gitignore` block, to show where each lands. No action.
