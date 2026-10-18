# Coding Rules

These rules apply to all code written in this project. They are non-negotiable.

## No unnecessary comments
Only add a comment when logic is genuinely non-obvious. Never describe what code does — only why, and only when surprising. Do not add comments to code you did not change.

## No docstrings unless asked
Do not add docstrings, JSDoc blocks, or inline type annotations to existing functions unless the user explicitly requests them.

## No speculative additions
Do not add features, error handling, validation, fallbacks, or logging for scenarios that do not exist in the current task. Do not design for hypothetical future requirements.

## No collateral refactoring
Fix only what was asked. Do not clean up surrounding code, rename variables for style, or reformat lines you did not change.

## No backwards-compat debris
If code is unused after your change, delete it. Do not add removed, deprecated, or re-export shims unless the user asks.

## Minimal diffs
The correct amount of code is the minimum needed to complete the task. When in doubt, write less.
