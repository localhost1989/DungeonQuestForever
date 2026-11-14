# Changelog

## 3.38.1
- The right page of the book is readable again: the frame's own dark marble lay over the parchment.

## 3.38.0
- Marks beside the quest names: "chain" (you go through it yourself) and "shared" with the group icon (a group member can give it to you).
- When every chain outside is done and quests a group member can share are left, the panel says "Chains done: ask the group to share" with their names, and once in the middle of the screen with a sound.

## 3.37.0
- Quests given within a few hundred yards of the way into the dungeon go last in the list and say "at the entrance: take it on the way in"; chains and errands elsewhere come first.

## 3.36.0
- On the flight map, the point your way flies to is lit and pointed at with the hand, and its name is said ("fly to: ...").
- Inside a dungeon, where the game does not tell an addon which object is in sight, the game's interact icon is shown over every usable object.

## 3.35.0
- The book's list of dungeons: a dungeon where a quest or a step of its chain is in your log shows "?" (gold when ready to hand in) instead of "!"; right-click marks a dungeon done (or back); "Hide done" hides the done and marked ones.

## 3.34.0
- Lighter: only the walking graph of the continent you are on is kept read (about 5 MB instead of up to 15 MB), in cells four times larger (reading it is four times faster); the quest data keeps only the game's language (about 0.6 MB less).
- The arrow counts its way ten times a second instead of twenty (it still turns with you every frame).

## 3.33.6
- Fixed the lag on hovering the panel, the arrow and the floor plan: the tooltip titles passed the wrap flag where this client wants the alpha, and every hover raised a Lua error (some 860 in one evening's log).

## 3.33.4
- Less work while playing: routine events (quest log touched, bags, a new hall) rebuild the panel at most once a second instead of four times; the quests not for your race are worked out once per dungeon; the map lookups of the arrow are kept instead of asked twenty times a second.

## 3.33.3
- The quests your race cannot take are no longer a row on the page; they are named in the tooltip of the Quests heading.

## 3.33.2
- Fixed a freeze of a tenth of a second or more the first time a walking way was looked for on a continent (after a teleport): the reading of the paths is spread over many frames.
- After a run (its last boss dead, or a quest that begins inside already done), the page no longer calls you in: "You have been inside already", what is left there, in grey, with no sound and no arrow to the door.

## 3.33.1
- The arrow points at a spot thirty yards ahead along the way instead of the next bend, so it no longer jumps on winding roads; a way already followed goes on under overhangs (the Drag of Orgrimmar) instead of switching to the straight line.

## 3.33.0
- The loot of the next boss is listed with item pictures.
- A drop that is best in slot or better than what you wear is announced in the middle of the screen with its picture, when it is put up for a roll ("press Need") or lies in the loot window.

## 3.32.1
- A dungeon's quests that your side can take but your race cannot are named on its page: "not for you", and which races it is for (the Compendium of the Fallen: orcs, tauren, trolls).

## 3.32.0
- A quest object in sight gets the pointing hand over it, as a boss does: the game's name plate over the soft-targeted object is switched on for quest objects only, and the hand hangs over it.

## 3.31.0
- Inside a dungeon of several wings (Scarlet Monastery), the wing is known by the hall you stand in: only its bosses are listed, the next one marked, and the heading reads "Library • Scarlet Monastery". Halls where a boss of a wing was seen are learnt.
- On the floor plan the entrance is larger, lit green and labelled "Entrance".

## 3.30.1
- The arrow no longer swings back and forth on the way: a bend left behind is not gone back to; off the way, the old way keeps leading while a new one is found; the first nodes of a new way that lie behind are skipped; near the goal it stays straight a little past the edge; indoors it points straight; and it turns at a bounded speed.

## 3.30.0
- The game's interact icon now appears only over objects a quest in your log needs (not over chairs, mailboxes and the like), for every quest in the database, not only dungeon quests. The sound and the "Here it is" line come with it.

## 3.29.1
- The status "All quests taken: you can go into the dungeon" is now the first line of the page, with the game's ready-check mark, above the way to the goal.
- The three dots in the heading open the quest journal of the dungeon; right-click them for the dungeon menu.

## 3.29.0
- When every quest and chain outside a dungeon is taken, the panel says so in a green-lit row: "All taken: you can go into the dungeon", with the way to the entrance under it and a "Shortest way to the entrance" button that sets the arrow and opens the card of the way (teleport, flight or pass, whichever is shorter).
- The moment the last quest outside is taken or handed in, it is also said in the middle of the screen with a sound, once.

## 3.28.1
- A teleport or a flight is offered when it saves a fifth of the walk (and 300 yards at least), not only when it halves it. A mage in Strahnbrad bound for the Scarlet Monastery now gets the Undercity teleport instead of three kilometres through the Plaguelands. Zeppelins and boats still have to halve the walk.

## 3.28.0
- Usable objects near you get the game's own interact icon (soft targeting is switched on; switched back off as it was with `/dq glow`). When it is a thing a quest in your log needs, a sound and a line say so.

## 3.27.0
- On foot the arrow follows walkable paths around mountains and cliffs, pointing to the next bend; the distance is counted along the way. Off the way, the way is found again. A switch in the minimap settings (`/dq paths`).

## 3.26.0
- No longer needs Questie or QuestieDB: the data the addon reads is built in, in English and Russian.
- A round button on the minimap: click for settings, right-click for the journal (`/dq minimap` hides it).

## 3.25.1
First public release.

- English version: every line of the interface, the tips and the dungeon routes.
- A welcome page on first login (`/dq welcome`) and a bug-report window (`/dq bug`).
- The panel sits in the quest tracker column and looks like the game's own quests; a quest
  unfolds in place with the steps of its chain.
- Routes with flight masters, zeppelins, ships, mage teleports and passes between zones.
- Boss loot with item icons, scoring against what you wear, and "best in slot" marks.
- Automatic quest pick-up and turn-in; a button that clears junk quests.
- A menu of dungeons behind the three dots, with progress and "cleared" marks.
