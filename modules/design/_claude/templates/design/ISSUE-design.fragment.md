<!-- KIT-CLASS: KIT — guide for a card whose work has screens: the `design:` and `design-scope:` keys. A new card is minted with `design: none`; copy the rest into its frontmatter. See process/EXTRACTION.md. -->
# Card keys for work with screens

```
design: none                                  # no screen (the value a card is minted with)
design: [UX-001#<state>, UX-002#<state>]      # in todo/: unpinned, copied from the ACs' markers
design: [UX-001#<state>@<commit>]             # after the PM's pin (leaving todo/): one @<commit> per entry
design-scope: []                              # element ids this card does NOT build; empty means everything
```

- In `todo/` the key is unpinned. Leaving `todo/` copies `@<commit>`, written by the PM at the Designer's `Pin-ready: <sha>`,
  in a `register-commit` before the move. Only a row whose `gate1` is `approved@<sha>` can be pinned, or the pin carries a
  named waiver in a `[decision: D-NN]`.
- A pinned card is never re-targeted; a later design change to a pinned state is new work and needs a `D-NN`
  (`scripts/ask.sh --role Designer --card <PREFIX>-NNN`).
- `design-scope:` lists element ids drawn in the pinned render that this card does not build (dimmed, inert, titled in the
  design). Everything else in the render must match the build.
- A path in a card is qualified with the commit it was true at (`<path> at <sha>`); cite screens by `UX-NNN#state`.
