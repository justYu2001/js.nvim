#!/bin/bash
set -e

WORKTREE_DIR=".."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$1" ]; then
  # No args: use current branch
  branch=$(git branch --show-current)
  if [ "$branch" = "main" ]; then
    folder="$branch"
  elif [[ "$branch" == */* ]]; then
    folder="${branch#*/}"  # extract after /
  else
    folder="$branch"
  fi
  git worktree add "$WORKTREE_DIR/$folder"
else
  # With arg: create new branch
  branch="$1"
  if [[ "$branch" == */* ]]; then
    folder="${branch#*/}"
  else
    folder="$branch"
  fi
  git worktree add -b "$branch" "$WORKTREE_DIR/$folder"
fi

cd "$WORKTREE_DIR/$folder"

echo "Worktree created at $WORKTREE_DIR/$folder"
