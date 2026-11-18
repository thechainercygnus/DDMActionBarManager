# DDMActionBarManager

Find outdated spell ranks on your **World of Warcraft: Forever** action
bars and upgrade them to the highest rank your character has learned.
Keep intentional downranks on the buttons where you use them.

## What it does

- Scans all eight standard action bars, including hidden bars and alternate
  pages. Each result shows the bar, button, current rank, and available rank.
- Alerts you in chat when you learn a higher rank and still have an older
  rank on a bar.
- Replaces a spell in the same slot, so you can keep using the same button
  or keybind.

The addon checks spells placed directly on action bars. Macros, items, and
pet actions are outside its scope.

## Installation

Install **DDMActionBarManager** for WoW: Forever. For a manual install,
extract or copy the folder containing DDMActionBarManager.toc so it sits
directly inside your game client's AddOns folder:

    Interface/AddOns/DDMActionBarManager/DDMActionBarManager.toc

Restart the game or run /reload, then check that the addon is enabled on
the character selection screen or in the in-game AddOns list.

## Quick start

1. Left-click the minimap button or type /ddmabm to see which spells can be
   upgraded.
2. Choose **Replace** to upgrade a slot while out of combat with an empty
   cursor. Choose **Keep rank** to retain an intentional downrank on that
   slot. **Reset kept ranks** clears those choices for your character.
3. Right-click the minimap button and open **Settings**. You can also type
   /ddmabm settings, including when the minimap button is hidden.

Left-drag the minimap button to reposition it. Its position, your settings,
and your kept ranks are saved per character.

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| **Auto-replace lower ranks** | Off | Upgrades existing and newly detected lower ranks in place. Respects **Keep rank** and waits until you are out of combat with an empty cursor. |
| **Show minimap button** | On | Shows the minimap launcher. Use /ddmabm settings to restore it after hiding it. |
| **Announce newly learned ranks in chat** | On | Reports lower ranks still on your bars after you learn a higher one. |
