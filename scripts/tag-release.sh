#!/usr/bin/env bash
#------------------------------------------------------------------------------
# tag-release.sh — create and push release tags for this repo
#
# PURPOSE
#   - Automates tagging with both:
#       1. A semver tag (immutable, e.g. v1.2.3)
#       2. A moving major tag (mutable, e.g. v1)
#   - Ensures both tags are updated together (atomic push).
#   - Prompts the user with safe defaults but allows overrides.
#
# BEHAVIOR
#   1. Verifies clean working tree.
#   2. Detects upstream default branch (via remote HEAD).
#   3. Fetches and pulls latest upstream changes.
#   4. Suggests a moving major tag:
#        • Existing vN pointing at HEAD, else
#        • Major from latest semver tag, else v1.
#   5. Suggests a semver bump (patch bump of latest semver).
#   6. Prompts user for both values (with defaults).
#   7. Creates annotated semver tag and moves/creates major tag.
#   8. Pushes both tags atomically to upstream, using
#      `--force-with-lease` for the moving major tag so no
#      accidental clobbering occurs.
#
# REQUIREMENTS
#   - Git 2.20+ (for --force-with-lease on tags).
#   - A configured upstream remote (default: "upstream").
#
# ENVIRONMENT
#   - UPSTREAM_REMOTE (optional): override remote name (default: upstream).
#   - DRY_RUN=1          : print commands instead of executing (optional).
#
# USAGE
#   ./scripts/tag-release.sh
#
# EXAMPLES
#   - Normal run (default upstream):
#       ./scripts/tag-release.sh
#
#   - Use origin instead of upstream:
#       UPSTREAM_REMOTE=origin ./scripts/tag-release.sh
#
#   - Dry run to preview git commands:
#       DRY_RUN=1 ./scripts/tag-release.sh
#
# NOTES
#   - The semver tag is immutable; moving major tag (e.g. v1) is
#     force-updated with lease protection.
#   - Tag messages are prompted interactively; defaults to "Release vX.Y.Z".
#------------------------------------------------------------------------------

set -euo pipefail

# Configurable via env
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
DRY_RUN="${DRY_RUN:-0}"

# Command runner that honors DRY_RUN=1
_run() {
	echo "+ $*"
	if [[ "$DRY_RUN" != 1 ]]; then
		"$@"
	fi
}

# --- Helpers ---------------------------------------------------------------

# Print an error and exit non-zero.
# Usage: die "message"
die() {
	echo "Error: $*" >&2
	exit 1
}

# Ensure working tree and index are clean.
# Exits if there are staged or unstaged changes.
require_clean_tree() {
	if ! git diff --quiet || ! git diff --cached --quiet; then
		die "Working tree not clean. Commit or stash changes first."
	fi
}

# Detect the upstream default branch name.
# Echoes branch name (e.g., "main"). Dies if remote/branch not found.
detect_upstream_branch() {
	git remote show "$UPSTREAM_REMOTE" >/dev/null 2>&1 ||
		die "Remote '$UPSTREAM_REMOTE' not found. Set UPSTREAM_REMOTE or add the remote."

	local head_branch
	head_branch="$(git remote show "$UPSTREAM_REMOTE" | awk '/HEAD branch/ {print $NF}')"
	[[ -n "$head_branch" ]] || die "Could not detect upstream default branch."
	echo "$head_branch"
}

# Fetch tags and branches from the upstream remote.
fetch_upstream() {
	_run git fetch "$UPSTREAM_REMOTE" --tags --prune
}

# Pull the upstream default branch (ff-only) if currently checked out.
# Usage: pull_upstream_default <branch>
pull_upstream_default() {
	local branch="$1"
	local cur_branch
	cur_branch="$(git rev-parse --abbrev-ref HEAD)"
	if [[ "$cur_branch" == "$branch" ]]; then
		_run git pull --ff-only "$UPSTREAM_REMOTE" "$branch"
	else
		echo "Note: current branch is '$cur_branch' (upstream default is '$branch'). Skipping pull."
	fi
}

# Return success if arg looks like a valid moving major tag (vN).
is_valid_major_tag() {
	[[ "$1" =~ ^v[0-9]+$ ]]
}

# Return success if arg looks like a valid semver tag (vN.N.N).
is_valid_semver_tag() {
	[[ "$1" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]
}

# Extract the major portion (vN) from a semver tag.
# Usage: major_of_semver v1.2.3 → v1
major_of_semver() {
	[[ "$1" =~ ^v([0-9]+)\.[0-9]+\.[0-9]+$ ]] && echo "v${BASH_REMATCH[1]}"
}

# Sort semver tags in descending order (vN.N.N).
# Reads from stdin, writes to stdout.
version_sort_desc() {
	LC_ALL=C sort -t. -k1,1Vr -k2,2nr -k3,3nr
}

# Find the latest semver tag for a given major.
# Usage: latest_semver_for_major v1 → v1.2.3
latest_semver_for_major() {
	local major="$1"
	git tag -l "${major}.*" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | version_sort_desc | head -n1
}

# Suggest a moving major tag.
# Prefers: (a) existing vN tag pointing at HEAD, (b) major from latest semver, (c) v1.
suggest_major_tag() {
	local head
	head="$(git rev-parse HEAD)"
	local pointing_major
	pointing_major="$(git tag --points-at "$head" | grep -E '^v[0-9]+$' | head -n1 || true)"
	if [[ -n "$pointing_major" ]]; then
		echo "$pointing_major"
		return
	fi
	local latest_any
	latest_any="$(git tag -l 'v*.*.*' | version_sort_desc | head -n1 || true)"
	if [[ -n "$latest_any" ]]; then
		major_of_semver "$latest_any"
		return
	fi
	echo "v1"
}

# Suggest the next semver tag for a given major.
# Defaults to patch bump of latest semver, else starts at vN.0.0.
suggest_semver_bump() {
	local major="$1"
	local latest
	latest="$(latest_semver_for_major "$major" || true)"
	if [[ -z "$latest" ]]; then
		echo "${major}.0.0"
		return
	fi
	if ! [[ "$latest" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
		echo "${major}.0.0"
		return
	fi
	local M="${BASH_REMATCH[1]}" m="${BASH_REMATCH[2]}" p="${BASH_REMATCH[3]}"
	printf "v%d.%d.%d" "$M" "$m" "$((p + 1))"
}

# Prompt the user with a yes/no question.
# Usage: if confirm "Proceed?"; then ...
confirm() {
	local prompt="$1"
	read -r -p "$prompt [y/N]: " ans
	[[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

# Push the semver tag and (safely) move the moving-major tag together.
# Usage: push_tags_safely <remote> <major_tag> <semver_tag> [extra_push_flags]
push_tags_safely() {
	local remote="$1" major="$2" semver="$3" extra="${4:-}"
	[[ -n "$remote" && -n "$major" && -n "$semver" ]] || {
		echo "push_tags_safely: remote/major/semver required" >&2
		return 2
	}

	echo "Pushing tags atomically to '$remote' ..."
	# Current remote OID for the moving major tag (if any)
	local old_oid
	old_oid="$(git ls-remote --tags "$remote" "$major" | awk '{print $1}' | tail -n1)"

	if [[ -n "$old_oid" ]]; then
		# Tag exists remotely → only move it if nobody else moved it since we looked
		_run git push "$remote" --atomic "$extra" \
			--force-with-lease="refs/tags/$major:$old_oid" \
			"refs/tags/$semver:refs/tags/$semver" \
			"refs/tags/$major:refs/tags/$major"
	else
		# Tag does not exist → assert non-existence with an empty expected value
		_run git push "$remote" --atomic "$extra" \
			--force-with-lease="refs/tags/$major:" \
			"refs/tags/$semver:refs/tags/$semver" \
			"refs/tags/$major:refs/tags/$major"
	fi
}

# --- Main ------------------------------------------------------------------

require_clean_tree
up_branch="$(detect_upstream_branch)"
echo "Upstream remote: $UPSTREAM_REMOTE (default branch: $up_branch)"
fetch_upstream
pull_upstream_default "$up_branch"

# Determine defaults
default_major="$(suggest_major_tag)"
read -r -p "Moving major tag (default: $default_major): " major_tag
major_tag="${major_tag:-$default_major}"
is_valid_major_tag "$major_tag" || die "Invalid major tag '$major_tag' (expected like v1, v2)."

default_semver="$(suggest_semver_bump "$major_tag")"
read -r -p "Semver tag (default: $default_semver): " semver_tag
semver_tag="${semver_tag:-$default_semver}"
is_valid_semver_tag "$semver_tag" || die "Invalid semver tag '$semver_tag' (expected like v1.2.3)."

# Ensure chosen semver matches chosen major
semver_major="$(major_of_semver "$semver_tag")"
if [[ "$semver_major" != "$major_tag" ]]; then
	echo "Warning: semver major '$semver_major' does not match moving major '$major_tag'."
	confirm "Continue anyway?" || exit 1
fi

# Message
default_msg="Release $semver_tag"
read -r -p "Tag message (default: \"$default_msg\"): " tag_msg
tag_msg="${tag_msg:-$default_msg}"

# Pre-flight checks
if git rev-parse -q --verify "refs/tags/$semver_tag" >/dev/null; then
	die "Semver tag '$semver_tag' already exists. Choose another."
fi

# If the moving major exists, we will move it (force). Ask for confirmation.
if git rev-parse -q --verify "refs/tags/$major_tag" >/dev/null; then
	echo "Moving major tag '$major_tag' already exists and will be updated to this commit."
	confirm "Proceed to move '$major_tag'?" || exit 1
fi

# Create / move tags to current HEAD
head_short="$(git rev-parse --short HEAD)"
echo "Tagging current commit $head_short ..."
_run git tag -a "$semver_tag" -m "$tag_msg"
_run git tag -fa "$major_tag" -m "Move $major_tag to $semver_tag: $tag_msg"

# Push both tags together (safe lease on moving major)
push_tags_safely "$UPSTREAM_REMOTE" "$major_tag" "$semver_tag" "--force-if-includes"

echo "Done!"
if [[ "${DRY_RUN:-0}" == 1 ]]; then
	echo "  (dry-run) Moving major: $major_tag -> would point to $head_short"
	echo "  (dry-run) Semver     : $semver_tag -> would point to $head_short"
else
	echo "  Moving major: $major_tag -> $(git rev-parse --short "$major_tag")"
	echo "  Semver     : $semver_tag -> $(git rev-parse --short "$semver_tag")"
fi
