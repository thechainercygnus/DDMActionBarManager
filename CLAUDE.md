# CLAUDE.md

Instructions for AI coding agents working in this repo.

## What this is

A WoW: Forever addon (Lua 5.1, interface 16001) that finds lower spell ranks on the eight
action bars and replaces them with the highest learned rank, with a minimap button,
settings and per-slot "Keep rank" choices saved in `DDMActionBarManagerDB`
(SavedVariablesPerCharacter). All code is in `DDMActionBarManager/DDMActionBarManager.lua`.
It's in the AddOn Manager's catalog (`../WoWForeverAddonManager/addons.json`).

## Commands

No build or automated tests. To try a change in game:

```
..\Install-DevelopmentAddOn.ps1 DDMActionBarManager
```

then `/reload`. Slash command: `/ddmabm` (`/ddmabm settings`).

Release: bump `## Version:` in the TOC in a PR; the user tags `vX.Y.Z` on `main`, and
`release.yml` publishes `DDMActionBarManager.zip`, which the AddOn Manager installs.

## Rules

- Action bar changes are protected: never call `PickupSpell`/`PlaceAction` in combat
  (`InCombatLockdown()`), or with something on the cursor. Queue and retry after
  `PLAYER_REGEN_ENABLED`, as the existing code does.
- Respect "Keep rank": never replace a slot the user marked, even with auto-replace on.
- Scope is spells placed directly on bars. Macros, items and pet actions stay out unless
  the user asks.
- The Forever API is undocumented. Only use functions confirmed by a ForeverAPIExplorer
  capture (`C_SpellBook` here) and say when you're assuming.
- Update README screenshots and the settings table when visible behaviour changes.
- CI: `secret-scan`, `codeql` and `dependency-review` must pass. Pin Actions to a full
  commit SHA with the version as a comment; give each job only the permissions it needs.
- Commits and pushes need the user's go-ahead. Work on a branch, open a PR.
