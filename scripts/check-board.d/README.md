<!-- KIT-CLASS: KIT — the arm directory of check-board.sh: where the files go, and a pointer to the contract. See process/EXTRACTION.md. -->
# scripts/check-board.d/ — extra arms

`check-board.sh` runs every `NN-<name>.sh` here after its lettered arms, in file-name order, each as
a `[+<name>]` arm of the report. The directory ships with this file alone: add an arm by adding a
file, remove it by removing the file. Only `[0-9][0-9]-*.sh` is run, so this file and any helper
without that name are not. A missing or empty directory runs nothing.

What an arm must declare, read, print and return is stated once, in
[`process/contracts/drift-report.md`](../../process/contracts/drift-report.md) § 5.
