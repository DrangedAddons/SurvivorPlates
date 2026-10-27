# Changelog

## 0.4.0
- **Collapse piles** mode. Mobs of the same kind that pile up share one plate with a count, like "Gurubashi Scout x12". The rest of the pile's plates are hidden and can't be clicked.
  - A plate joins a pile of the same mob when it overlaps one of the pile's plates sideways by at least the set amount and is close by. Bosses and guardians never pile.
  - Piles are kept until their mobs die. Mobs in this game don't unpile, so moving the camera doesn't break piles up or reshuffle them.
  - The pile shows your target's plate if your target is in it, so the gold border and target scale still work. Otherwise it shows the pile's oldest plate.
- "Sideways overlap to join a column" is now **Sideways overlap to join**, since it's used for piles too.
- The window's corner and `/asp status` show how many plates are hidden in piles.

## 0.3.4
- **Plates stay in their column** (on by default): once a plate joins a column it stays there until the mob dies or its plate disappears, however far the mob wanders. "Leave a column beyond" only applies with this unticked.
- A plate frame the game reuses for a different mob no longer inherits the old mob's place in a column.

## 0.3.3
- **Leave a column beyond** slider (0.5 to 6 plate widths, default 2): how far a plate's mob has to get from its column before the plate leaves it. Sideways it's that many plate widths; up and down it's six of the game's plate rows per plate width (2 = 12 rows, as before). Higher is stickier.
- The Target and priority section moved down to make room.

## 0.3.2
- **Much stickier columns.** Once a plate is in a column it stays for at least 3 seconds (was 1). After that it only leaves when its mob is far away: more than two plate widths to the side of the column, or more than 12 of the game's plate rows from the plate below it. It used to leave as soon as it stopped touching the column.

## 0.3.1
- **Stickier columns.** Plates stopped bouncing between columns:
  - Columns are remembered from one moment to the next instead of being rebuilt from scratch, and a column keeps its order. A new plate goes on top and never shuffles the others.
  - Joining is easier: a plate can now join a column from up to three of the game's plate rows away (was two and a half).
  - Leaving is harder: a plate stays in its column for at least a second after joining. After that it only leaves once it no longer touches the column sideways, or drifts twice as far away as it could join from.

## 0.3.0
- **New modes.** Mode is now **Spread** or **Stack in columns**.
  - **Spread** (the default) leaves plates where the game puts them. The game already spreads its plates so they never overlap.
  - **Stack in columns:** a plate that overlaps a nearby plate sideways by at least the set amount lines up with it in a tidy column, packed right on top. Other plates stay where the game put them.
- The old "Overlap" mode is gone. It couldn't do what it said: the game spreads plates before any addon sees them, and gives addons no way to find where the mob's head really is. A real overlap mode needs a change in the game itself.
- Settings renamed to match: **Sideways overlap to join a column** (default 30%) and **Most plates in a column**. Characters that were on Overlap are now on Spread.
- The window and `/asp status` report how many plates were moved, instead of pushed up.

## 0.2.2
- Switching Mode now snaps every plate straight to its new place. Going to Overlap drops all stacking at once instead of gliding down.
- `/asp debug` puts a cyan dot where the game places each plate. In Overlap mode every plate should sit on its dot; a plate above its dot has been moved by stacking.
- If placing plates ever hits an error, SurvivorPlates now says so in chat (and in `/asp status`). Before, an error could quietly stop plates from moving.
- `/asp debug` added to the README.

## 0.2.1
- The settings window's top-right corner now shows how many plates are on screen and how many are stacked, updated live. It used to show a count from when the window opened.
- `/asp status` also says how many plates were pushed up and the biggest push, to check whether stacking is doing anything.
- Stacking falls back to the plate's own position if its health bar has none yet.

## 0.2.0
- **Minimap button:** click it to open the settings, drag it to move it around the minimap. It sits on the edge of SurvivorsDragonUi's square minimap like its other buttons.
- **Show minimap button** tick box in the settings, and `/asp minimap` to show or hide it. Reset to defaults leaves the button and its position alone.

## 0.1.0
- First version. A companion to SurvivorsDragonUi that changes how its enemy nameplates look and stack. Open the settings with `/asp`.
- **Stacking:** overlapping plates stack upward instead of piling on top of each other. Settings: Stack or Overlap mode, gap between plates, how much two plates must overlap before they stack, highest stack, movement speed, keep stacks on screen, only stack in combat. The click area moves with a stacked plate, so clicking it targets that mob.
- **Size:** width, height, scale, font size, the name above or inside the bar or hidden, and health text (percent, current, or current / max).
- **Target and priority:** a bigger target plate with a gold border, fading every other plate while you have a target, and bigger plates for bosses and guardians.
- Settings are saved per character. Every change shows at once.
