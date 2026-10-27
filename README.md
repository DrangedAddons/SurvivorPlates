# SurvivorPlates

An [Azeroth Survivors](https://discord.gg/azerothsurvivors) addon. It's a companion to **SurvivorsDragonUi** that adds the nameplate settings you'd expect from a WoW nameplate addon: stacking, size, and target highlighting.

Click the minimap button or type `/asp` in game to open the settings. Every change shows at once.

## Settings

**Stacking**
- **Mode:** Stack moves overlapping plates upward so you can read each one. Overlap leaves them where the game puts them.
- **Gap between plates**, **Overlap before they stack** (how much two plates must overlap sideways), **Highest stack** and **Movement speed** (0 jumps straight to place).
- **Keep stacks on screen**, **Only stack in combat**.
- **Click area follows the plate:** clicking a stacked plate targets its mob.

**Size:** width, height, scale, font size, name position (above, inside, hidden), health text.

**Target and priority:** target scale, a gold border on the target, fading other plates while you have a target, and a separate scale for bosses and guardians.

Settings are per character.

## Commands
- `/asp`: open or close the settings
- `/asp reset`: back to defaults
- `/asp minimap`: show or hide the minimap button
- `/asp status`: whether it's hooked into SurvivorsDragonUi, and how many plates it sees

## Requirements
SurvivorsDragonUi with its nameplate skin on. SurvivorPlates resizes and moves that skin, so it does nothing without it. If a SurvivorsDragonUi update changes how its plates are built, SurvivorPlates switches itself off and says so in chat.
