# Changelog

## 3.45.0
- Open the bug reporter from the quest book, next to Close, or type /dq bug. The link goes straight to a new GitHub issue.
- Optional Wago Analytics measures book usage, quest reading, loot previews and requests for directions when analytics is enabled in Wago App.

## 3.44.0
- A click on a boss in the list opens the window of his loot beside the row: each thing with its picture in the colour of its quality, its slot and kind, its stats, and a plate: BiS, better than worn +N, worn, or not for your class (then dimmed). Hover a thing for the game's tooltip; shift-click links it. The boss whose loot is open wears a gold frame; the same click again closes it.
- The parts "Bosses" and "Quests" fold and unfold by a click on their heading.

## 3.43.3
- Fixed: "Interface action failed because of an AddOn" in fights inside dungeons. The plate and icon switches of the object highlight wait until the fight is over.
- "Way to the boss" turns the small floor plan back to the boss's floor and makes his pin pulse.
- The small floor plan is live: hover a boss for his level, how he comes out, a note on the fight and his loot weighed for you; right-click a boss for the large atlas plan.
- A short note on 123 bosses of the classic dungeons (what they do that matters, a tip), in English and Russian, in that tooltip.
- Inside a dungeon the hand no longer hangs over a corpse being looted or another creature: only over things.

## 3.43.2
- The panel no longer folds down to the current step in a fight inside a dungeon: the page stays whole, the small floor plan too.
- The world map opened by the addon is the small (windowed) one, not the full-screen one.
- "Way to the boss" and a click on a boss no longer open the atlas's big plan together with the small one: the small floor plan alone. The big one is behind a right-click on the small plan.
- Inside a dungeon the hand hangs over the thing in sight that can be used (a gong, a chest, a quest object), even where the game keeps its identity secret; and things are looked for farther off (SoftTargetInteractRange 25, put back when the light is off).

## 3.43.1
- Fixed: the arrow to a quest goal led to the first spawn on the list, which could be far off over a cliff. It now leads to the nearest spawn of the nearest goal of the quest (for "A Host of Evil": the thornweavers and cultists by the Downs, not the one battleguard point on the cliff above).

## 3.43.0
- "Share quests" on the status plate now shares every quest of the dungeon in your log with the group and asks in one English line for the ones you lack (with their English names). Others with the addon share them by themselves.
- The chat lines carry no web address any more, just "find it on CurseForge".
- Ready state: when only what is by the way in is left (to take, finish or hand in by the entrance or the pad), the green "All quests taken - you can go into the dungeon" shows, with "on the way: ..." and the shortest way.
- Fixed: the flight map lit a wrong point (Brackenwall instead of Freewind Post). The point lit is now the one the panel and the arrow show, by its whole name.
- Right-click on a quest opens the journal on that quest; the dark window it used to open is gone.

## 3.42.0
- The getting ready goes in three stages: first the quests far from the dungeon you have to run to, then those to ask of the group, then what is by the way in (done on arriving). The status follows: "Take N more" with the first errand, "Ask the group to share: N" with an "Ask to share" button, or "At the entrance: ..." last.
- The "Share" word is always on top; out of a group it says to join one.

## 3.41.2
- Fixed: an item your class cannot wear (leather for a mage, an axe for a priest) is no longer weighed as "better than worn" or "best in slot", in the loot line or anywhere else.

## 3.41.1
- The errands are ranked by the distance from the dungeon: the far ones on top, those by the entrance at the bottom, so the road ends at the door. The status says "Start with" and its button "Way to the first".
- Quests a group member can share are marked with the group's picture in light blue.

## 3.41.0
- A "Share" word on top of the panel when in a group: one click shares every quest of the dungeon in your log with the group, and asks in the group chat for the shareable ones you lack (with a word about the addon). Group members with the addon share the asked quests by themselves.
- A shareable quest given neither at the entrance nor inside is no longer an errand to run to: it goes last with "ask the group to share it: no need to run there", and is left out of "Take N more" and the nearest errand.

## 3.40.2
- The panel has no dark ground again by default: it reads as part of the game's own quest list (/dq back gives the dark ground).

## 3.40.1
- Closer to the approved layout: no dashes before the lines, the rule under each section label.
- "Chains done: ask the group to share" no longer shows while the last step of a chain is still to do.

## 3.40.0
- Addons of the group and the guild tell each other their version, unseen; when someone near you has a later one, your chat says once that a new version is out and to update it with the CurseForge or Wago app.
- After a boss of a dungeon run, out of combat, the group hears one line about the addon with its CurseForge link - only when someone in the group does not have it, and not more than once in two hours. Switch it off in the minimap menu or with /dq share.

## 3.39.0
- A new layout of the panel and the book (designed with ChatGPT, approved by the owner):
  - On top, one status plate in one of five colours with a button: gold "Take N more quests of M" (way to the nearest), blue "Hand in N" (way to hand in), green "All taken: you can go in" (shortest way to the entrance), grey "You have been inside already", red "Next boss" inside (way to the boss).
  - Outside, two sections: "To take" and "Taken"; each quest is its name in gold, one line of what to do, with whom, where and how far, and a dim note (a group member can share it, take it at the entrance).
  - Inside: the next boss as the red plate, "What to do at the boss", the bosses, then the quests.
  - The book's right page is dark, with gold headings: What to do, Where, Chain.
  - The tips are no longer on the panel.

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
