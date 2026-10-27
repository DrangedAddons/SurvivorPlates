# SurvivorPlates

An [Azeroth Survivors](https://discord.gg/azerothsurvivors) addon. It's a companion to **SurvivorsDragonUi** that adds the nameplate settings you'd expect from a WoW nameplate addon: stacking, size, and target highlighting.

Click the minimap button or type `/asp` in game to open the settings. Every change shows at once.

## Settings

**Stacking**
- **Mode:** **Spread** (the default) leaves plates where the game puts them. The game already spreads them so they never overlap. **Stack in columns** lines up plates that overlap sideways into tidy columns, packed right on top of each other.
- **Gap between plates**, **Sideways overlap to join a column**, **Leave a column beyond** (how far a mob has to get before its plate leaves; higher is stickier), **Most plates in a column** and **Movement speed** (0 jumps straight to place).
- **Plates stay in their column** (on by default): a plate that joins a column stays until its mob dies. Untick it to let plates leave once their mob gets further away than **Leave a column beyond**.
- **Keep stacks on screen**, **Only stack in combat**.
- **Click area follows the plate:** clicking a moved plate targets its mob.

There's no overlap mode. The game spreads its plates before any addon sees them, and doesn't tell addons where a mob's head really is, so plates can't be put back on top of each other.

**Size:** width, height, scale, font size, name position (above, inside, hidden), health text.

**Target and priority:** target scale, a gold border on the target, fading other plates while you have a target, and a separate scale for bosses and guardians.

Settings are per character.

## Commands
- `/asp`: open or close the settings
- `/asp reset`: back to defaults
- `/asp minimap`: show or hide the minimap button
- `/asp status`: whether it's hooked into SurvivorsDragonUi, how many plates it sees and how many it stacked
- `/asp debug`: a cyan dot where the game places each plate, to see what stacking moved

## Requirements
SurvivorsDragonUi with its nameplate skin on. SurvivorPlates resizes and moves that skin, so it does nothing without it. If a SurvivorsDragonUi update changes how its plates are built, SurvivorPlates switches itself off and says so in chat.
