# KIT-CLASS: KIT — the one definition of where a session declares its hat. See process/contracts/role-gate.md.
#   Sourced by scripts/hooks/require-role.sh (reads it), scripts/hooks/session-start.sh (clears it)
#   and scripts/kit-init.sh (ignores it, then proves the ignore). Nothing else names the path.
#
# The file is outside `.claude/`: the agent harness treats that directory as sensitive and refuses a
# session's write to it under every permission mode but bypass, so a hat file there can never be
# declared by an unattended session. `.kit/` is the kit's own session-state directory; it is
# gitignored (kit-init.sh writes the entry from this value; `.gitignore` ships the same line).
KIT_HAT_FILE_REL=".kit/session-role"
