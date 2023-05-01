##TAS Step Planner
This mod allows you to record your actions and then export those actions for use in creating tool-assisted speedruns.

This is a updated version of [TAS Helper](https://mods.factorio.com/mod/tas_helper) by [pallet12](https://mods.factorio.com/user/pallet12). Currently it supports exporting to Factorio TAS Generator(*FTG*) ([Youtube showcase](https://www.youtube.com/watch?v=V9tuNoDqc0E&ab_channel=EZRaiderz), [Getting on track like a pro TAS World Record](https://www.youtube.com/watch?v=geEoRQ2JEbM&ab_channel=EZRaiderz), [github](https://github.com/MortenTobiasNielsen/Factorio-TAS-Generator)). You will need to copy/paste the exported tasks into the TAS Generator save file.

###Settings
This mod uses a custom mod settings handler. Where the settings are handled through a GUI and synced with settings storage.
However for this to work, "Use different mod settings per save" needs to be turned off. From the main menu:
1. open *Settings*
2. open *Other*
3. Find *"Use different mod settings per save"*, and *uncheck* it.

###How to use it
Here is a recommended workflow:

1. *Save* - In *FTG*, save your current tasks, say to tas_save.txt.
2. *Generate Script* - as normal.
3. *Open save file in a text editor* - Open/reopen tas_save.txt so that it is up to date (because you are going to be pasting into it and then saving!).
4. *Play the script* - as normal with the TAS mod and this mod enabled. (Also check out [Game Speed Controls](https://mods.factorio.com/mod/game-speed) to speed up/pause the playback.) If there are any errors/mistakes in your tasks list, then fix them in *FTG* and repeat from step 1. Remember to save and reopen tas_save.txt so that it is up to date!
5. *Record* - Press the 'Record' button and do your desired actions.
6. *Export* - Press 'Export (EZR)' and follow the instructions to add your new actions to tas_save.txt.
7. *Open save file in the TAS tool* - Open the file in *FTG* to see your additions.
8. *Repeat!*

Make sure to make regular backups of the TAS save file (tas_save.txt) in case you accidentally make a mistake while copy/pasting! You don't want to accidentally paste over all your work then close your text editor without realizing! (You can just make a copy of tas_save.txt in your file explorer after every few changes.)

###New features - compared to TAS Helper
* *Bug-fixes*
* *Settings* for limiting which actions to record
* *Walk capture*
* *Auto-build ghost* - making it easier to convert a plan into an action-list
* *Export color* - to color your imported tasks
* *Multibuild* - merging several build actions into a single task
* *Fast-replace* - merge of actions

###Hotkeys
Hover over the GUI buttons or check out the controls settings in-game to see the default hotkeys.

###Notes
Some actions are captured, and some cannot be captured because of limitations in/difficulties with the Factorio modding API.

Here are the actions that are captured:

* Build
* Rotate
* Mine - buildings, ore, trees & rocks
* Take/Put - But only when 'fast transferring' (i.e. 'ctrl + click' or 'shift + click' on an entity). If you click on a building to open your/its inventory and then transfer by clicking on item stacks, it will not be captured.
* Set recipe, chest limit, splitter priority/filter or filter inserter filters - Including copy/pasting settings between entities.
* Researching a technology
* Crafting
* Walking

####The following are *not captured*:
* Pick up/drop item (i.e. pressing 'F' or 'Z')
* Queue Research
####Additionally, there are some bugs in *FTG* which mean that some things cannot be exported (even if they are recorded correctly):
* Clearing recipe.

Also you can use editor mode, however some actions will not be captured if the game is paused. Unpausing the game should make everything work normally.