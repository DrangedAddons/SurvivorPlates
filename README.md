# SurvivorPlates

An [Azeroth Survivors](https://discord.gg/azerothsurvivors) addon. It's a companion to **SurvivorsDragonUi** that adds nameplate settings: collapsing piles of mobs into one plate, size, and target highlighting.

Click the minimap button or type `/asp` in game to open the settings. Every change shows at once.

## Settings

**Piles**
- **Mode:** **Spread** (the default) leaves plates where the game puts them. The game already spreads them so they never overlap. **Collapse piles** shows one plate per pile of mobs, with a count ("Gurubashi Scout x12"). The pile's other plates are hidden and can't be clicked.
  - A plate that touches any plate in a pile joins it, whatever the mob. Plates of the same mob are also picked up from a few plate rows away, and piles that touch merge.
  - A plate only leaves its pile when its mob dies. A plate the game hides for a moment (off screen, out of range) keeps its place for a minute.
  - If your target is in a pile, the pile shows your target's plate.
  - Bosses and guardians are never piled.
- **Sideways overlap to join:** lower picks up same-mob plates from further to the side.
- **Only collapse in combat.**
- **Game plate frame size (test):** shrinks the game's own plate frames under the skin. If the game spaces plates by their current size, lower values let plates overlap. Best tried in Spread mode.
- **Pile bars:** a panel listing each pile as a bar, like boss bars, with the mob's name, the pile's count and its average health. Click a bar to target the nearest mob with that name. Bosses and guardians come first, then the biggest piles.
  - **Position:** **Where you drag it** (untick **Lock pile bars** to move it) or **Above your character**. The camera keeps your character in the middle of the screen, so above your character means a set height above the middle; **Height above your character** adjusts it.
  - **Show nameplates in the world:** untick it to hide every enemy plate in the world and use only the pile bars. The bars then list single mobs too.
  - **Most pile bars** and **Pile bars scale** set its size.

There's no overlap mode. The game spreads its plates before any addon sees them, and doesn't tell addons where a mob's head really is, so plates can't be put back on top of each other.

**Size:** width, height, scale, font size, name position (above, inside, hidden), health text.

**Target and priority:** target scale, a gold border on the target, fading other plates while you have a target, and a separate scale for bosses and guardians.

Settings are per character.

## Commands
- `/asp`: open or close the settings
- `/asp reset`: back to defaults
- `/asp minimap`: show or hide the minimap button
- `/asp status`: whether it's hooked into SurvivorsDragonUi, how many plates it sees and how many are hidden in piles
- `/asp debug`: a cyan dot where the game places each plate, hidden ones included

## Requirements
SurvivorsDragonUi with its nameplate skin on. SurvivorPlates resizes and hides that skin, so it does nothing without it. If a SurvivorsDragonUi update changes how its plates are built, SurvivorPlates switches itself off and says so in chat.
