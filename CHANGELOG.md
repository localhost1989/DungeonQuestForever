# Changelog

## 3.48.7
- The ways out of Thunder Bluff and the Undercity are called the lifts they are: "take the lift down" / "take the lift up" under the arrow and on the way card, instead of "pass between zones".
- A step of a chain under way says what is left of it, from the quest log (it said only "finish").
- Fixed again, for good this time: a long quest name beside the distance at the right went onto a second line over the line under it. The distance is now placed before the name is laid out.
- A quest to hand in out here says it in green at the front: "Hand in «The Gurubashi Legends of Old»: Kin'vilai • Stranglethorn Vale".
- "How to find" goes away once the goal is done.

## 3.48.6
- Fixed: a long quest name that went onto a second line beside the distance at the right was drawn over by the line under it.

## 3.48.5
- The step of a chain stands in the gold line, by the quest's name ("The Only Good Brinescale...  2/4"); the line under it begins with the step itself.
- A quest to finish out here says what the goal is taken from: "The Third Troll Legend: 0/1 • object 'Fall of Gurubashi' • Stranglethorn Vale", "Rock Elemental Shard: 3/5 • Rock Elemental • Badlands". The Gurubashi Legends step of the Drowned City's chain has a hint how to find the tablet.

## 3.48.4
- A goal taken from a thing in the world, not from a creature, is called an object: "object 'Gri'lek the Wanderer'", the tablet at the bottom of the Vile Reef, was taken for an NPC. The Vile Reef step of the Drowned City's chain has a hint how to find the tablet.
- The Drowned City's bosses are called by their Russian names on a Russian client (the database has only the English ones).

## 3.48.3
- The Drowned City has its bosses in order: Zul'Alai, Var'Taka, the Primeval Elemental (optional, in the underwater room off the Deep Archives), Captain Dreadrise, Deathless Marrow, Min'loth the Serpent.
- Fixed: a groupmate who died was taken for a boss, and once raised, for a boss alive again: every mark of the run was wiped. Players are never bosses now, and where a dungeon's bosses are not written only the game's own word of a boss's death counts.

## 3.48.2
- The tips of the new dungeons (the Drowned City's underwater room and rare encounters, Alcaz Prison's keyring, Krol'dok Stronghold's keys and Bossman Toof) are written step by step: a click on the tip shows the next step.

## 3.48.1
- Fixed: inside The Drowned City the addon did not know where you were on a Russian client (its name there is "Затонувший город"). A dungeon the addon does not recognise is noted in its saved settings, so the next ones can be added.

## 3.48.0
- Five new dungeons of Forever in the list and the book: The Drowned City (35–40), Krol'dok Stronghold (40–45), Alcaz Prison (48–53), Blackmaw Hold (55–60), Shaper's Terrace (58–60). The arrow leads to the way in, with a word on how to find it; inside, the addon knows where you are. Their quests from QuestieDB 1.1.1: six for the Drowned City, six for Krol'dok Stronghold, four for Blackmaw Hold; none known yet for Alcaz Prison and Shaper's Terrace.
- The book's list of dungeons says on hover that a right click marks a dungeon done (it leaves the list while done ones are hidden), and another brings it back.
- "You can go into the dungeon" comes as soon as all that is left is by the dungeon (to finish on the way in) or can be shared by the group: the green plate says what to do on the way and whom to ask, and the moment it turns so there is the ready sound and a line in the middle of the screen. A quest the group can share no longer keeps you outside.
- Under a quest to finish out here the line says what and where, without "do out here": the part above says it.
- Taken quests are split in parts: "Do before going in" (finish or hand in out here, first in the list), "Do at the entrance" (in the cave before the portal or within 600 yards of the way in: done on the way in, best with the group) and "Taken, done inside".
- How to find it: quests whose goal is hard to find with the arrow alone get a hint, in the unfolded card ("how to find:") and in the tooltip of the quest. First for the quests in the tunnels before the Uldaman portal: Reclaimed Treasures (both sides), Solution to Doom, Amulet of Secrets.
- Goals in the cave before a dungeon portal (those same Uldaman quests): outside, the arrow leads to the mouth of the cave; inside, straight to the goal. It no longer sends you a kilometre round the mountain to the spot above the cave.

## 3.47.2
- The one line about the addon after the first boss goes to a raid too, not only to a group (still only when someone there has no addon, and once in two hours at most). The setting is now called "Tell the group and the raid about the addon".

## 3.47.1
- After an update the addon says once in the chat what is new.

## 3.47.0
- A taken quest with two goals or more lists them under it with dashes, as the game's tracker does: the done ones struck out (on one line, without the count), the one the arrow leads to bright.
- A quest with several goals: when the goal the arrow leads to is done, the arrow goes on by itself to the nearest goal left, and the chat says which.
- Flight points you have not discovered yet, in silver, on the world map (continent and zone, even under the fog of war) and on the minimap; a farther one, within 1500 yards, waits at the rim of the minimap. Hover for its name and flight master; click to set the arrow to him.
- The arrow holds its bearing for up to three seconds between one walking way and the next, instead of pointing straight across the mountains for a moment.
- An undiscovered flight point by your way or by the goal stands under the way as a gold plate: "Flight point on the way: <name>", with the zone and distance. Click it to set the arrow to its flight master.
- The arrow no longer swings to the goal and back while a way is looked for again (off the path, after a fall): it holds its bearing until the new way is found.
- As a ghost the arrow leads to your body; on rising, back to the goal.
- The walking way begins at the node near you that makes it shortest, not at the nearest one: off the road it no longer sends you back to where the old way was; and while a new way is found the arrow holds its bearing instead of pointing back.
- The share button says "Share" with the scroll of a quest; button widths follow their words.
- Under the name of the dungeon, real buttons with a picture and a word instead of the row of words: Entrance (or Portal, Teleport, Exit), Journal, Group. "Group" shares your quests and asks for the missing ones; the blue "Ask the group to share" plate is gone: the part "The group shares" and the Group button say it. The status plate leads to the first quest you have to run for.

## 3.46.1
- "Later" (level too low, or taken inside) stands at the very bottom, under "Taken".

## 3.46.0
- Before the dungeon, what is not taken stands in parts, each with its count, folding by a click on its heading: Chains, The group shares (with the group's picture, and where to run if nobody shares), Take yourself, Later (level too low, or taken inside); then Taken.
- Fixed: the tooltip over a boss on the small floor plan broke when the boss had no level in the data.
- A taken quest with work out here says so: "do out here: <goal> • zone • distance" (it said only "do"); work inside keeps "in the log, done inside".
- How far a quest is stands in gold at the right of its name, with "via the pass" or "by flight faster" small under it, instead of at the end of the line.

## 3.45.1
- Fixed: the way could fly to a point you have not discovered yet (counted before your flight points were known). When the flight map opens and your points are learnt, the way to the goal is counted again and the arrow set anew.
- The English words of the loot window: "better than equipped +N", "equipped".

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
