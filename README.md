# DDMActionBarManager

DDMActionBarManager finds direct spell slots with a higher rank learned on
your WoW: Forever character.

## Install

Copy the inner **DDMActionBarManager** folder into the client's AddOns
directory, then restart the game or run /reload. From the shared AddOns
development folder, you can also run:

    .\Install-DevelopmentAddOn.ps1 DDMActionBarManager

## Use

Left-click the minimap button or type /ddmabm to review action slots with
a higher learned rank available. Right-click the button and open
**Settings** to control chat alerts and minimap button visibility. Use
/ddmabm settings to show the button again if you hide it. Left-drag the
button to move it around the minimap.
Choose **Replace** out of combat to upgrade a slot, or **Keep rank** to
keep an intentional downrank. **Reset kept ranks** clears those choices
for the current character. The addon also alerts you in chat when it
detects a newly learned rank with older ranks still on your bars.


**Auto-replace lower ranks** is off by default. Enable it in Settings to
upgrade existing and newly detected lower ranks automatically. It respects
**Keep rank** choices and waits until you are out of combat and the cursor
is empty.

## Layout

The inner DDMActionBarManager folder contains the TOC and Lua files
installed in the game. Repository documentation lives at the root.
