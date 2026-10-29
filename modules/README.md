<!-- KIT-CLASS: KIT — the index of the optional modules the kit ships, disarmed; one row per module. See process/EXTRACTION.md.
     KIT-DISPOSITION: DELETE-IF-UNUSED — an unused option reads as a promise; remove modules/ (or the directory
     of a module you will not enable) or record keeping it on purpose in process/LOCAL-PROCEDURES.md. -->
# modules/ — optional modules, shipped off

Nothing here is read by a harness: a module is stored disarmed and does nothing until
`./scripts/module.sh enable <name>`. What a module is, how to enable and disable one, and how to write
one: [`process/MODULES.md`](../process/MODULES.md). `./scripts/module.sh list` shows what is enabled.

A new module joins this table in the same change that adds its directory; the self-test checks that each module has a row. A row may outlive a module whose directory the project deleted.

| Module | What it is |
|---|---|
| [`example`](example/module.manifest) | A toy to read and copy, and what the self-test enables: it shows where each kind of thing a module adds lands. |
