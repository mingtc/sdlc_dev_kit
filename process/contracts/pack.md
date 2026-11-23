<!-- KIT-CLASS: KIT — contract sheet: packs (list, verify, unpack, remove). See process/EXTRACTION.md. -->
# CONTRACT — packs

## 1. PURPOSE

Files the kit ships but most projects never read cost tokens in every grep and every agent's context.
A **pack** ships them inside the zip as one file nothing reads into, and gives the project a way to put
them on disk and to take them off again without a hand edit and without touching anything it changed.

## 2. HARD INVARIANTS

- **A pack is one git bundle holding one root commit; its tree is the files, at the paths they unpack to.** Reading
  one needs git and a POSIX shell and nothing else.
  *Why:* the kit's floor is git and a POSIX shell; an archiver the floor does not name would be a second
  requirement every project meets at the first unpack.
- **A pack's bytes are a function of its members and the build epoch.**
  *Why:* the release gate that rebuilds the zip and compares it needs the same input to give the same file,
  and needs a different epoch to give a different one.
- **Members are regular files on a closed alphabet of path characters; a symlink, a gitlink, a `.git` component, a
  `..` component and two paths that differ only by case are refused, when the pack is built and again when it
  is read.**
  *Why:* git's own object check accepted a pack holding `.git/hooks/…`; a pack that wrote a hook, or wrote
  through a link, would run code at the next commit.
- **Reading a pack changes no byte of it, and unpacking changes no byte of a member.** Members are written
  with no filter, no line-ending conversion and no attribute; a pack that does not verify is refused, never
  repaired.
  *Why:* a root `.gitattributes` rule that rewrites line endings changed a pack's bytes on checkout.
- **Unpack checks everything before it writes anything, and never overwrites.** A member already on disk
  is left exactly as it is and counted; a symlink or a file where a directory must go refuses that pack with
  nothing written for it.
  *Why:* a half-unpacked pack, or one written through a link, cannot be undone by the pack.
- **Remove deletes only what is byte-equal to the pack's copy, and names every member it kept.** An edited
  member, a member replaced by a link and a member under a link are the project's now.
  *Why:* an edited file is work. The same rule the kit upgrade and `module.sh disable` apply.
- **Neither verb commits, and a refusal changes nothing.**
  *Why:* what lands in the project's history is the project's decision.

## 3. REFUSAL CONDITIONS

- A name that is not a pack the project holds, or is not lowercase letters, digits and `-` ⇒ refuse; `list` names them.
- A pack that is not whole, or breaks a rule in § 2 ⇒ refuse, naming the file and the member; restore the pack from the
  zip or from git.
- A symlink or a file on the way to a member ⇒ refuse that pack, nothing written for it; the message names the path.
- `remove` with no name, or with `--all` ⇒ refuse: it takes one pack.

## 4. WHAT GREEN MEANS

1. `verify` exits 0 only when every pack named is whole and every member is allowed.
2. `unpack` then `remove` leaves the tree as it was, apart from directories that were empty before.
3. `remove` after an edit keeps the edited member and says so; a second `remove` does nothing and says so.

## 5. MINIMAL INTERFACE

**In:** a command (`list`, `verify [<name>]`, `unpack <name>|--all`, `remove <name>`) and the packs in the
project's pack directory.
**Out:** a line per pack, or per kept member, and an exit status: 0 done, 1 a refusal that names its next step,
2 a usage error. `unpack` and `remove` print that nothing was committed.
**Not in:** enabling a module, editing a pack, or a decision about what ships packed.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/pack.sh` — KIT-CLASS: KIT. The four verbs, over the reader.
- `scripts/lib/kitpack.sh` — KIT-CLASS: KIT. The format's one reader and builder; its header states the rules and
  its exit statuses.
