# KIT-CLASS: KIT — the one declaration of the board's status folders. See process/EXTRACTION.md § 2.2.
#   Sourced by the scripts that name the set: check-board.sh, move-issue.sh, subtask.sh,
#   kit-init.sh and setup.sh. A landing reads the declaration below as text from the trunk's copy
#   of this file (lib/board-properties.sh), so keep the single-quoted `NAME='…'` shape.
#
# The status of a card is the folder it sits in. Rename a folder, or add one, by editing this line
# only: every carrier derives from it. The names are ordered by lifecycle and written
# `|`-separated, so they drop into a regular expression as they are.
KIT_STATUS_FOLDERS='todo|in_progress|dev_complete|qa_complete|blocked|done|declined'

# The directories under progress/: the set plus `history/`, where the rotated log goes. `history/`
# is a directory, not a status.
KIT_BOARD_DIRS="${KIT_STATUS_FOLDERS}|history"
