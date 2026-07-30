#!/bin/sh
cd "$1" 2>/dev/null || exit 0
branch=$(git branch --show-current 2>/dev/null)
if [ -n "$branch" ]; then
    printf '⎇ %s | ' "$branch"
fi
