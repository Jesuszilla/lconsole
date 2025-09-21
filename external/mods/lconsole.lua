---Lua console for I.K.E.M.E.N-Go
---
---authors: Jesuszilla
---
---license: MIT         
---
---***note: PLEASE REMEMBER TO REMOVE THIS FILE WHEN DISTRIBUTING YOUR
---GAME!!!***
---
---This module is capable of executing arbitrary Lua code. Please
---exercise caution and utilize the `findLuaMethod` and `man`
---commands for more information about the available Lua commands
---and what they do.
---
---Comments on this module can be read after installing the sumneko
---VSCode/Codium extension.
lconsole = {}
man_table = {}
local didDisableCtrl = false
local funcs = {}

-- Dump all functions
-- for k, v in pairs(_G) do
-- 	-- Global function ignore list (Lua standard functions)
-- 	local ignore = {
-- 		_G = true,
-- 		_printregs = true,
-- 		_VERSION = true,
-- 		assert = true,
-- 		collectgarbage = true,
-- 		dofile = true,
-- 		error = true,
-- 		getfenv = true,
-- 		getmetatable = true,
-- 		ipairs = true,
-- 		load = true,
-- 		loadfile = true,
-- 		loadstring = true,
-- 		module = true,
-- 		newproxy = true,
-- 		next = true,
-- 		pairs = true,
-- 		pcall = true,
-- 		print = true,
-- 		rawequal = true,
-- 		rawget = true,
-- 		rawlen = true,
-- 		rawset = true,
-- 		require = true,
-- 		select = true,
-- 		setfenv = true,
-- 		setmetatable = true,
-- 		tonumber = true,
-- 		tostring = true,
-- 		type = true,
-- 		unpack = true,
-- 		xpcall = true,
-- 		-- plus any modules like math, string, table, os, etc.
-- 		math = true,
-- 		string = true,
-- 		table = true,
-- 		os = true,
-- 		coroutine = true,
-- 		utf8 = true,
-- 		package = true,
-- 	}
--     if type(v) == "function" and not ignore[k] then
-- 		table.insert(funcs, k)
--         --print("Global function:", k)
--     end
-- 	table.sort(funcs)
-- 	for _, name in ipairs(funcs) do
-- 		print(string.format("register_man('%s', '', '')", name))
-- 	end
-- end

--#region SETTINGS

lconsole.NUM_CONSOLE_COLS  = 75   -- you may need to change this depending on your font
lconsole.NUM_CONSOLE_ROWS  = 20   -- number of rows to display in the console
lconsole.TOTAL_IGNORE_TIME = 4    -- adjust for key buffer dead time
lconsole.CURSOR_BLINK_RATE = 30   -- cursor blink rate
lconsole.CURSOR_CHAR       = '_'  -- cursor character
lconsole.CONSOLE_PREFIX    = '> ' -- console prefix string
--#endregion

-- Legacy MConsole command
addHotkey('BACKQUOTE', true, false, false, true, true, 'toggleConsole()')
-- new/macOS alias because Command⌘ + ` is a system command on there
addHotkey('t', true, false, false, true, true, 'toggleConsole()')

-- Extra MacBook debug aliases
addHotkey('p', true, false, false, true, false, 'toggleDebugPause()')
addHotkey('EQUALS', true, false, false, true, true, 'changeSpeed(1)')
addHotkey('MINUS', true, false, false, true, true, 'changeSpeed(-1)')

-- Paste into console
addHotkey('v', true, false, false, false, true, 'lconsole.pasteText(getClipboardString())')

-- #region STRINGBUFFER IMPLEMENTATION
StringBuffer = {}
StringBuffer.__index = StringBuffer
function StringBuffer.new()
	local self = setmetatable({}, StringBuffer)
	self.chars = {}
	return self
end

---Appends the given string to the end of the StringBuffer
---@param str string The string to add to the end of the buffer
function StringBuffer:append(str)
	self:insert(str, #self.chars+1)
end

---Removes a character from the StringBuffer at the given index
---@param idx integer The index of the character to remove
function StringBuffer:remove(idx)
	table.remove(self.chars, idx)
end

-- Metamethod to index the StringBuffer
function StringBuffer:__index(key)
    if key == 'length' then
        return #self.chars
    elseif type(key) == 'number' then
        return self.chars[key]
    else
        return StringBuffer[key]
    end
end

-- Metamethod to modify a StringBuffer by indexing
function StringBuffer:__newindex(key, value)
    if type(key) == "number" then
        self.chars[key] = value
    else
        rawset(self, key, value)
    end
end

---Converts the StringBuffer to a lowercase string
---@return string
function StringBuffer:lower()
	return table.concat(self.chars):lower()
end

---Converts the StringBuffer to an uppercase string
---@return string
function StringBuffer:upper()
	return table.concat(self.chars):upper()
end

---Inserts the string at the given index into the StringBuffer
---@param str string The string to insert
---@param idx integer The position in the StringBuffer to insert the string into
function StringBuffer:insert(str, idx)
	idx = (idx and idx > 0) and idx or 1
	for i=1, #str do
		table.insert(self.chars, idx+i-1, str:sub(i,i))
	end
end

---Converts the StringBuffer to its string representation
---@return string
function StringBuffer:toString()
	return table.concat(self.chars)
end

---Returns a substring of the StringBuffer as another StringBuffer object.
---@param start integer The start index
---@param stop integer The stop index
---@return table StringBuffer The new StringBuffer object
function StringBuffer:sub(start, stop)
	local len = #self.chars
    start = start >= 0 and start or len+start+1
    stop = stop and (stop >= 0 and stop or len+stop+1) or len

	start = math.max(1, math.min(start, len))
	stop = math.max(1, math.min(stop, len))

    local subBuffer = StringBuffer.new()
    for i = start, stop do
        subBuffer:append(self.chars[i])
    end

    return subBuffer
end
-- #endregion

---Registers a command with the manual command.
---@param commandName string The exact name, case-sensitive, of the function whose info should be registered.
---@param description string A concise description of what the command does.
---@param args string The arguments, separated by newlines and their data type specified next to it in parentheses e.g. idx (integer)
---@param ret string (optional) What the method returns, if any. Blank implies void.
function register_man(commandName, description, args, ret)
	local man_entry = {description = description, args = args}
	if ret then
		man_entry['ret'] = ret
	end
	man_table[commandName] = man_entry
end

-- #region DEFAULT LUA METHODS (MAN TABLE)
register_man("addChar", "Adds a character to the select screen.", "char (string) - The path to the character .DEF to add")
register_man("addHotkey", "Adds a hotkey to the listener.", "key (string) - The key to listen to,\nctrl (boolean) - If true, Ctrl must be held down for this hotkey to function,\nalt (boolean) - If true, Alt must be held down for this hotkey to function,\nshift (boolean) - If true, Shift must be held down for this hotkey to function,\npause (boolean) - If true, the hotkey can function during pause,\ndebugKey (boolean) - If true, is disabled when debug is disabled,\nfunction (function) - The function to call when this hotkey combo is activated")
register_man("addStage", "Adds a stage to the select screen.", "stage (string) - The path to the stage .DEF to add")
register_man('ailevel', 'Returns the AI level of the current entity.', 'None', 'aiLevel (int) - The AI Level of the current entity.')
register_man('airjumpcount', 'Returns the current air jump count of the current entity', 'None', 'ajc (int) - The current air jump count of the current entity.')
register_man('alive', 'Returns the alive status of the active entity', 'None', 'true if the entity is alive, false otherwise')
register_man('alpha', 'Returns the given alpha component of the current alpha for the active entity', 'type (str) - Alpha type. Valid values are "source" and "dest".', 'alpha (int) - the requested component of the current alpha')
register_man('angle', 'Returns the angle of the active entity', 'None', 'deg (float) - The current angle of the entity')
register_man('anim', 'Returns the number of the currently playing Anim of the active entity', 'None', 'animNo (int) - The current animNo of the active entity')
register_man("animAddPos", "Offsets the given anim by the given x,y coordinates.", "anim (Anim) - the anim to use,\nx (int) - the x position to offset by\ny (int) - the y position to offset by")
register_man("animDraw", "Draws the given animation.", "anim (Anim) - The reference to the Anim to draw.")
register_man("animGetLength", "Gets the length of the given anim, in frames.", "anim (Anim) - The reference to the anim whose length to calculate.")
register_man("animGetPreloadedCharData", "Returns the preloaded animation data of the given character", 'entity (SelectChar) - The reference to the SelectChar whose data to load.')
register_man("animGetPreloadedStageData", "Returns the preloaded animation data of the given stage", 'entity (SelectStage) - The reference to the SelectStage whose data to load.')
register_man("animGetSpriteInfo", "Returns a table containing the information of the given sprite.", "anim (Anim) - The reference of the anim to use,\ngroup (int) (optional) - The sprite group to search for,\nnumber (int) (optional) - The sprite number to search for")
register_man("animNew", "Creates a new anim from the provided AIR syntax string.", "air (string) - The AIR syntax to parse for creating a new animation.", "The new Anim")
register_man("animReset", "Resets the animation to its first frame and resets animTime", "anim (Anim) - The reference to the Anim to reset.")
register_man("animSetAlpha", "Sets the alpha of the given Anim.", "anim (Anim) - The reference of the anim to set the alpha for,\nsrc (int) - Source alpha (from 0-256),\ndst (int) - Dest alpha (from 0-256)")
register_man("animSetColorKey", "Sets the color key of the given Anim.", "anim (Anim) - The reference of the Anim to use,\nmask (int) - The color slot in the palette to use for the mask color (from 0-255).")
register_man("animSetFacing", "Sets the facing of the given Anim.", "anim (Anim) - The Anim to set the facing for,\nfacing (int) - The Facing value to set. Valid values are 1 and -1.")
register_man("animSetPalFX", "Sets the PalFX of the given Anim.", "anim (Anim) - The Anim reference to set the PalFX for.\npalfx (table) - A table containing the parameter(s) of the palFX to set. Valid keys are time, add, mul, sinadd, sinmul, sincolor, sinhue, invertall, invertblend, color, and hue.")
register_man("animSetPos", "Sets the pos of the given Anim.", "anim (Anim) - The Anim reference to use.\nx (float) - The X pos to set the anim to.\ny (float) - The Y pos to set the anim to.")
register_man("animSetScale", "Sets the scale of the given Anim.", "anim (Anim) - The Anim reference to use.\nx (float) - The X scale to set.\ny (float) - The Y scale to set.\nrelative (bool) - If true, will also scale according to the global Lua sprite scale. If false, scale will be absolute.")
register_man("animSetTile", "Sets the given Anim to display tiled.", "anim (Anim) - The reference of the Anim to use.\nx (int) - The X pos to begin drawing the tiled Anim at.\ny (int) - The Y pos to begin drawing the tiled Anim at.\nsx (int) - The X spacing to use between tiles.\nsy - The Y spacing to use between tiles.")
register_man("animSetWindow", "Sets the window of the given Anim.", "anim (Anim) - The Anim reference to use.\nx (float) - The X position of the window.\ny (float) - The Y position of the window.\nw (float) - The width of the window.\nh (float) - The height of the window.")
register_man('animUpdate', 'Updates the given Anim (advances by one frame)', 'anim (Anim) - The Anim reference to update')
register_man('animelemcount', 'Returns the number of AnimElems in the current Anim for the active entity.', 'None', 'animElemCount (int) - The number of animElems in the currently playing anim for the active entity')
register_man('animelemno', 'Returns the number of the animElem in the current Anim that would be displayed at the specified time. The argument to animelemno represents the time to check, expressed in game ticks, relative to the present.', 'time (int) - The time in ticks, relative to the present, to check by.', 'animElem (int)')
register_man('animelemtime', 'Gets the animation-time elapsed since the start of a specified element of the current Anim. Useful for synchronizing events to elements of an animation action. (reminder: first element of an action is element 1, not 0) ', 'animElem (int) - the element number to check', 'The animElemTime elapsed since the provided animElem.')
register_man('animexist', 'Returns true if the specified Anim number exists for the player, false otherwise. The result of this trigger is undefined if the player is in a custom state.', 'animNo (int) - The number of the animation to check existence for.', 'true if the provided anim number exists, false otherwise')
register_man('animframe', 'Returns the given component of the current animation frame of the active entity.', "type (string) - The component to return. Valid values are 'alphadest', 'alphasource', 'angle', 'group', 'hflip', 'image', 'numclsn1', 'numclsn2', 'num', 'time', 'vflip', 'xoffset', 'xscale', 'yoffset', 'yscale'", 'v (int) or (float) - The value of the parameter.')
register_man('animlength', 'Returns the total length, in frames, of the current animation of the active entity.', 'None', 'animLen (int) - The length, in frames, of the current animation.')
register_man('animplayerno', 'Returns the playerNo of the owner of the active anim of the current entity', 'None', 'pNo (int) - The playerNo of the owner of the active anim.')
register_man('animtime', "Gives the difference between the looptime of the current animation action and the player's animation-time", 'None', 'animTime (int) - The time from the end of the animation. This number is always negative during the duration of the animation, and approaches the end at 0.')
register_man('animtimesum', 'Returns the time elapsed so far into the given anim, in ticks.', 'None', 'timeSum (int) - The time elapsed so far into the given anim, in ticks.')
register_man('attack', 'Returns the current attack value, from a scale of 0-100', 'None', 'atck (number) - The current attack value.')
register_man('authorname', 'Returns the authorName of the active entity', 'None', 'authorName (string) - The authorName of the active entity.')
register_man('backedge', 'Returns the back edge pos of the stage relative to current entity facing.', 'None', 'backEdge (float) - The back edge pos of the stage.')
register_man('backedgebodydist', "Returns the distance of the current entity's back width from the back edge of the stage.", 'None', 'backEdgeBodyDist (float) - The distance from the back width of the current entity from the back edge of the stage')
register_man('backedgedist', 'Returns the distance of the current entity from the back edge of the stage', 'None', 'backEdgeDist (float) - The distance of the current entity from the back edge of the stage.')
register_man('batchDraw', 'Batch draws the given table of select screen cell animations', 'selectCellAnims (table) - The table of select screen cell animations. Each item in the table must contain the keys "anim" (Anim Userdata reference), "x" (x pos), "y" (y pos), and "facing" (facing direction).')
register_man("bgDraw", "Draws the given BG", "bg (BGDef) - The BGDef to draw.\ntop If true, will draw top layers.\nx (float) - The X position to draw the BG at.\ny (float) - The Y position to draw the BG at.\nscl (float) - Uniform scale to scale the BG by.")
register_man("bgNew", "Creates a new BG from the given SFF and DEF", "sff (SFF) - The reference of the SFF to load.\ndef (string) - The path to the .DEF file of the BG.\nname (string) - The name of the BG.", "The new BG.")
register_man("bgReset", "Resets the given BG.", "bg (BGDef) - The reference of the BGDef to use.")
register_man('bgmvar', 'Gets the associated property of the currently playing BGM.', 'property (string) - The property to retrieve. Valid values are filename, freqmul, length, loop, loopcount, loopend, loopstart, position, startposition, volume.', 'res (dynamic) - The return value of the requested property.')
register_man('boolToInt', 'Converts a boolean to an integer for use in CNS/ZSS.', 'value (boolean) - The boolean value to convert', 'result (int) - 1 for true, 0 for false')
register_man('botboundbodydist', "Like BotBoundDist, except this trigger accounts for the player's bottom edge parameter, as defined by the Depth state controller.", 'None', 'bbbd (float) - BotBoundBodyDist')
register_man('botbounddist', "BotBoundDist gives the distance between the player's z-axis and the botbound limit of the stage.", 'None', 'bbd (float) - BotBoundDist')
register_man('bottomedge', 'Returns the Y position of the bottom edge of the screen, in absolute stage coordinates. ', 'None', 'bottomEdge (float) - The Y position of the bottom edge of the stage.')
register_man('cameraposX', "Gets the X value of the camera's position relative to the stage.", 'None', 'cameraPosX (float) - The current X position of the camera.')
register_man('cameraposY', "Gets the Y value of the camera's position relative to the stage.", 'None', 'cameraPosY (float) - The current Y position of the camera.')
register_man('camerazoom', 'Gets the current camera zoom factor', 'None', 'zoom (float) - The current zoom factor of the camera.')
register_man('canrecover', 'If the player is currently in a falling state, returns true if they are currently able to recover, and false if they are not currently able to recover. If the player is not currently falling, the output of this trigger is undefined.', 'None', 'canRecover (boolean) - true if the player can recover, false otherwise.')
register_man('changeAnim', 'Changes the animation of the currently running player.', 'animNo (int) - The animNo to change to.')
register_man('changeSpeed', 'Adds add% to the currently running game speed, or changes to the next speed multiplier if no argument specified.', 'add_percent (optional) (int) - The percentage to add to the game speed.')
register_man('changeState', 'Changes the state of the currently running player.', 'stateNo (int) - The stateNo to change to.')
register_man("charChangeAnim", "Changes the given character's animation to the provided animation number.", "pn (int) - The playerNo to change.\nan (int) - The animation number to change to.\nelem (int) - The AnimElem to change to.", "true if the character changed to the given anim, false otherwise.")
register_man("charChangeState", "Changes the given character to the given state.", "pn (int) - The playerNo to change.\nst (int) - The StateNo to change to.", "true if the character changed to the given state, false otherwise.")
register_man("charMapSet", "Sets the map for the given player.", 'pn (int) - The playerNo to set the map for.\nmap_name (string) - The name of the map to set.\nvalue (float) - The value to set the map to.\nmap_type (string) - Valid values are "add" and "set"')
register_man("charSndPlay", "Plays a sound for the given player.", "pn (int) - The playerNo to play the sound from.\ng (int) - Sound group\nn (int) - Sound number\nvo (int) - The volume to play the sound at, from 0 to 100\nf (boolean) - If true, will play the sound from FightFX\nch (int) - Sound channel\nlw (boolean) - If true, will be low priority\nfr - Frequency multiplier\nlp (boolean) - If true, the sound will loop\np (float) Pan value\npriority (int) - Sound priority\nloopstart (int) - Loop start sample position\nloopend (int) - Loop end sample position\nstartposition (int) - Sample position to begin playing from\nloopcount (int) - Number of times to loop the effect")
register_man("charSndStop", "Stops all sounds if no argument is given, or for the given playerNo.", "pn (int) (optional) - The playerNo to stop all sounds for. Leave nil or blank to stop all sounds entirely.")
register_man("charSpriteDraw", "Draws a sprite from the given playerNo. Used to display character faces in lifebars.", "pn - PlayerNo to draw the sprite from.\nspr_table (table) - A table containing the info for the sprite to draw. See start.lua for an example.", "true if the sprite was drawn, false otherwise.")
register_man('clamp', 'Returns a value clamped to an inclusive range between min and max', 'value (float) - The value to clamp.\nmin (float) - The minimum value to clamp by.\nmax (float) - The maximum value to clamp by.', 'clamped (float) - The result of the clamp.')
register_man("clear", "Clears the clipboard text for all entities.", "None")
register_man("clearAllSound", "Clears all sound channels", "None")
register_man("clearColor", "Clears the color of the screen and fills it with the given color (all values are from 0-255)", "r (int) - The red component to fill the screen with,\ng (int) - The green component to fill the screen with,\nb (int) - The blue component to fill the screen with,\na (int) (optional) - The alpha component to use.")
register_man("clearConsole", "Clears the I.K.E.M.E.N console text", "None")
register_man("clearSelected", "Select screen only. Clears the selected characters and stage.", "None")
register_man('closeMenu', 'Closes the menu.', 'None')
register_man('clsnoverlap', "Returns true if the player's specified collision box type is overlapping another player's collision boxes.\n\nThis trigger uses Ikemen's internal collision detection, so it will work even with angled and rescaled boxes.", "box_type_1 (string) The player's collision box type. Valid values are clsn1, clsn2, and size.\npId (int) - The ID of the player against which to check the overlap.\nbox_type_2 - The target's collision box type. Valid values are clsn1, clsn2, and size.")
register_man('clsnvar', 'Returns the specified CLSN coordinate from the specified CLSN index. Back always returns the back coordinate, and front always returns the front coordinate, even if they are reversed in the .AIR file. All coordinates are in the same coordinate space as .AIR.', 'value_type (string) Valid Values are clsn1, clsn2, and size\nindex (int) - The index of the CLSN to check.\nelem (string) - The CLSN element to return. Valid values are back, front, top, and bottom')
register_man('codeInput', 'Checks commands in any Lua context (no need for a fight).', 'name (string) - The name of the command to check.')
register_man('combocount', "Returns the total number of hits done by the player's side in the currently ongoing combo.", 'None', 'comboCount (int) - The number of hits in the current combo.')
register_man('command', 'Returns true if the command by the specified name is active.', 'name (string) - The name of the command to check.', 'true if the user has input the specified command, false otherwise')
register_man("commandAdd", 'Adds the provided command string to the character .CMD for use in-game.", "cl (CommandList) - The CommandList reference to add the command to.\nname (string) - The name of the command.\ncommandStr - The command string e.g. "~D,DF,F"\ntime (int) - The time required to execute the command.\nbufTime (int) - The time to buffer the command.')
register_man("commandBufReset", "Resets the entire buffer for the given CommandList.", "cl (CommandList) - The CommandList reference to reset.")
register_man("commandGetState", "Gets the active state of the given command", "cl (CommandList) - The CommandList reference to use.\nname (string) - The name of the command to check.", "true if the command is active, false otherwise")
register_man("commandInput", "Sends inputs to the given index into the command buffer.", "cl (CommandList) - The CommandList reference to use.\ni (int) - The index at which to insert the command into the buffer.")
register_man("commandNew", "Creates a new CMD/CommandList object.", "None")
register_man('connected', 'Returns true if connected to an opponent in a netplay game, false otherwise.', 'None', 'true if connected to an opponent ovver the network, false otherwise.')
register_man('consecutivewins', 'Returns the number of consecutive wins for the active player', 'None', "numWins (int) - The number of consecutive wins from the current player's teamside")
register_man('const', 'Returns the given value from the constants. See the wiki for the full list.', 'constName (string) - The name of the constant to retrieve, all lowercase.', 'const (variable) - The value of the provided constant.')
register_man('const1080p', "Converts a value from the 1080p coordinate space to the entity's coordinate space. The conversion ratio between coordinate spaces is the ratio of their widths.", 'value (float) - The value to convert.', "The 1080p value converted to the entity's coordinate space.")
register_man('const240p', "Converts a value from the 240p coordinate space to the entity's coordinate space. The conversion ratio between coordinate spaces is the ratio of their widths.", 'value (float) - The value to convert.', "The 240p value converted to the entity's coordinate space.")
register_man('const480p', "Converts a value from the 480p coordinate space to the entity's coordinate space. The conversion ratio between coordinate spaces is the ratio of their widths.", 'value (float) - The value to convert.', "The 480p value converted to the entity's coordinate space.")
register_man('const720p', "Converts a value from the 720p coordinate space to the entity's coordinate space. The conversion ratio between coordinate spaces is the ratio of their widths.", 'value (float) - The value to convert.', "The 720p value converted to the entity's coordinate space.")
register_man('continue', 'Returns true if on the Continue screen, false otherwise.', 'None', 'true if on continue screen, false otherwise')
register_man('ctrl', 'Returns true if the entity has control, false otherise', 'None', 'true if the entity has control, false otherwise')
register_man('debugFlag', 'Sets the debug flag for the given TeamSide', 'teamSide (int) - 1 for P1 side, 2 for P2 side')
register_man('debugmode', 'Returns information related to the debug mode.', 'param_name (string) -  The name of the parameter to check. Valid values are: accel, clsndisplay, debugdisplay, lifebarhide, wireframedisplay, roundrestarted', 'res (dynamic) - The value of the given debug item,')
register_man('decisiveround', "Returns true if the match will conclude if the player's team wins.", 'None')
register_man('defence', "Returns the entity's current defence value. This value accounts for all defence multipliers.", 'None', 'def (float) - The current defence value.')
register_man('dialogueReset', 'Resets dialogue for all characters.', 'None')
register_man('displayname', 'Returns the DisplayName of the active entity.', 'None')
register_man('dizzy', 'Returns true if the character is dizzied, false otherwise.', 'None', 'true if the character is dizzied, false otherwise.')
register_man('dizzypoints', 'Returns the amount of dizzy points the entity has.', 'None', 'dizzyPoints (int) - The amount of dizzy points the player has.')
register_man('dizzypointsmax', 'Returns the maximum amount of dizzy points the entity can have.', 'None', 'maxDizzyPoints (int) - The maximum amount of dizzy points the entity can have.')
register_man('drawgame', "Returns true if the player's team has ended the round in a draw, false otherwise.", 'None', "true if the player's team has ended in a draw, false otherwise.")
register_man('drawpal', 'Returns the value of the group and index of the palette being used to draw the sprites at the moment, unlike PalNo, which returns the palette selected in the character select screen.', 'param_type (string) - Valid values are: group, index', 'param (int) - The drawPal group or index.')
register_man('endMatch', 'Immediately ends the current match.', 'None')
register_man('enemy', 'Redirects the Lua context to the enemy.', 'idx (optional) - The 0-based index of the enemy to use.', 'true if the context successfully switched, false otherwise')
register_man('enemynear', 'Redirects the Lua context to the nearest enemy.', 'idx (optional) - The 0-based index of the nearest enemy to check.')
register_man('enterNetPlay', 'Enters netplay mode and either tries to connect to the given host IP, or listen for incoming connections.', 'hostIP (optional) (string) - The IP address of the host to connect to.')
register_man('enterReplay', 'Enters replay mode using the provided replay file as input.', 'fileName (string) - The name of the file to load for replay data.')
register_man('envshakevar', "Returns the value of the provided EnvShake variable.', 'name (string) - The name of the EnvShake variable to retrieve. Valid values are 'time', 'freq', and 'ampl'.")
register_man('esc', 'Returns true if the escape key was pressed, false otherwise', 'None', 'true if esc was pressed, false otherwise')
register_man('exitNetPlay', 'Immediately exits netplay.', 'None')
register_man('exitReplay', 'Immediately stops replay playback.', 'None')
register_man('explodvar', 'Returns the value of the given explod parameter.', 'id (int) - The ID of the explod to check. Use -1 to iterate over all.\nidx (int) - The index of the explod to check. Explod indices are in spawn order, and shifts when another explod with the same ID is destroyed.\nparam (string) - The param to check. Please check wiki for valid parameter names.')
register_man('facing', "Returns the current entity's Facing value", 'None', "facing (int) - 1 if facing right, -1 if facing left")
register_man('fade', 'Fades the given rect with the given alpha.', 'rect (rect) - The rectangle to fade.\nalpha - The alpha component to use, from 0-256.')
register_man('fadeColor', 'Fades screen with the given color in or out. Use getFrameCount() to get the current frame count.', "type (string) - Valid values are 'fadein' and 'fadeout'\ntime (int) - The game frame to start fading from.\nlength (int) - The length of the fade, in ticks.\nr - The 8-bit red component of the color to fade.\ng - The 8-bit green component of the color to fade\nb - The 8-bit blue component of the color to fade.", 'true if the fade is happening, false otherwise')
register_man('fightscreenstate', 'Allows checking if the fight screen is displaying specific screens.', 'param_name (string) - The param to check. Valid values are: fightdisplay, kodisplay, rounddisplay, windisplay.', 'fsv (bool) - true if the fight is displaying the specified screen, false otherwise')
register_man('fightscreenvar', 'Returns information about the fight screen (commonly referred to as "lifebars").', 'param_name (string) - The name of the parameter to check. Valid values are: info.author, info.localcoord.x, info.localcoord.y, info.name, round.ctrl.time, round.over.hittime, round.over.time, round.over.waittime, round.over.wintime, round.slow.time, round.start.waittime, round.callfight.time, time.framespercount', 'res (dynamic) - The requested FightScreenVar.')
register_man('fighttime', 'Returns the current time, in ticks, elapsed so far into the fight.', 'None', 'fightTime (int) - The time, in ticks, since the current fight started.')
register_man('fileExists', 'Returns true if the file at the specified path exists, false otherwise.', 'path (string) - The relative or full path to the file.', 'true if the file exists, false otherwise')
register_man('fillRect', 'Fills the given rectangle with the given color and alpha.', '')
register_man("findEntityByName", "Finds an entity by case-insensitive name search and moves the debug cursor to it", "text (string) - The partial or complete text to search by name.")
register_man("findEntityByPlayerId", "Finds an entity by player ID search and moves the debug cursor to it", "pid (integer) - The player ID to search for.")
register_man("findHelperById", "Finds a helper by helper ID search and moves the debug cursor to it", "hid (integer) - The helper ID to search for.")
register_man("findLuaMethod", "Performs a case-insensitive search (ASCII only) of available method names.", 'text (string) - The partial or complete text to search for.')
register_man('firstattack', 'Returns first attack status', 'None', 'true if the current entity performed a first attack, false otherwise.')
register_man('fontGetDef', 'Returns a table of the font .DEF information for the given Fnt', 'fnt (Fnt) - The Font reference whose .def information to retrieve.', 'def (table) - A table containing the Font .DEF information.')
register_man('fontGetTextWidth', 'Gets the width of the text in the provided font and bank.', 'fnt (Fnt) - The Font reference to use.\ntext (string) - The text to measure.\nbank (int) - The bank number in the font to use.')
register_man('fontNew', 'Loads a font .def into the given screenpack and returns the Fnt reference to it.', 'filename (string) - The name of the Font .DEF to use.\nheight (int) - The height of the font to use.')
register_man('frameStep', 'Steps forward 1 frame.', 'None')
register_man('framespercount', 'Returns the lifebar framespercount field.', 'None', 'fpc (int) - The frames per lifebar timer count.')
register_man('frontedge', 'Returns the front edge pos of the stage relative to current entity facing.', 'None', 'frontEdge (float) - The front edge pos of the stage.')
register_man('frontedgebodydist', "Returns the distance of the current entity's front width from the front edge of the stage.", 'None', 'backEdgeBodyDist (float) - The distance from the front width of the current entity from the front edge of the stage')
register_man('frontedgedist',  'Returns the distance of the current entity from the front edge of the stage', 'None', 'frontEdgeDist (float) - The distance of the current entity from the front edge of the stage.')
register_man('full', 'Restores life and power for the given playerNo', 'pno (int) - The playerNo whose life and power to refill.')
register_man('fullAll', 'Restores life and power for all players.', 'None')
register_man('fvar', "Returns the entity's float variable value at the given index.", 'fVarNo (int) - 0-39 float variable index number', 'value (float) - The value of the float variable.')
register_man('game', 'Executes a match of gameplay', 'None')
register_man('gameLogicSpeed', 'Returns the current game logic speed.', 'None', 'speed (float) - The current game logic speed.')
register_man('gameend', 'Returns true if the game engine is ending, false otherwise', 'None', 'gameEnd (boolean) - true if the game engine is ending, false otherwise')
register_man('gamefps', 'Returns the average frames per second of the running game engine. This trigger calculates and updates regardless of any internal pause activity, scripted or debug.', 'fps (float) - The average FPS of the game.')
register_man('gameheight', "Returns the current height of the game space in the entity's local coordinate space. The game space is defined as the currently-visible area of the stage in which players interact. The dimensions of the game space at a zoom factor of 1.0 is specified by the GameWidth and GameHeight parameters in config.json", 'None', 'gh (float) - The height of the game, in pixels.')
register_man('gamemode', 'Returns the current game mode.', 'None', 'mode (string) - The current game mode.')
register_man('gamespeed', 'Returns the current game speed as a percentage.', 'None', 'speed (number) - The current game speed.')
register_man('gametime', 'Returns the current game time, in ticks.', 'None', 'The elapsed game time, in ticks.')
register_man('gamewidth', "Returns the current width of the game space in the entity's local coordinate space. The game space is defined as the currently-visible area of the stage in which players interact. The dimensions of the game space at a zoom factor of 1.0 is specified by the GameWidth and GameHeight parameters in config.json", 'None', 'gw (float) - The width of the game, in pixels.')
register_man('getCharAttachedInfo', 'Returns a table with the following information from the given character .DEF: name, def, sound', 'def (string) - The name of the character .DEF file whose info to retrieve.', 'infoTable (table) - A table of the character info.')
register_man('getCharDialogue', 'Returns the table of available dialogue for the given playerNo.', 'pNo (int) - The playerNo whose dialogue to retrieve.', "dialogue (table) - A table containing the player's dialogue.")
register_man('getCharFileName', 'Retrieves the name of the .DEF of the given SelectChar no. (select screen only)', 'charNo (int) - The index of the character whose .DEF name to retrieve', 'defName (string) - The name of the character .DEF file.')
register_man('getCharInfo', 'Retrieves a table with the following info for the selected character at the given index (select screen only): name, author, def, sound, intro, ending, arcadepath, ratiopath, portrait_scale, cns_scale', 'charNo (int) - The index of the selected character whose info to retrieve.', 'infoTable (table) - The table with all the info.')
register_man('getCharMovelist', 'Retrieves the name of the character movelist of the selected character at the given index (select screen only)', '')
register_man('getCharName', 'Retrieves the displayName of the selected character at the given index (select screen only)', 'charNo (int) - The index of the selected character whose name to retrieve.', 'name (string) - The name of the selected character at the given index.')
register_man('getCharRandomPalette', 'Retrieves a random palette of the selected character at the given index (select screen only)', 'charNo (int) - The index of the selected character whose name to retrieve', 'palNo (int) - A random palette number for the selected character.')
register_man('getCharVictoryQuote', 'Retrieves the victory quote for the specified playerNo and quote index.', 'pNo (int) - The playerNo whose quotes to retrieve.\nidx (int) - The index of the victory quote to retrieve.', "quote (string) - The character's winquote at the given index")
register_man('getClipboardString', 'Returns the current string in the clipboard.', 'None', "clipboard (string) - The string that's in the current clipboard.")
register_man('getCommandLineFlags', 'Retrieves a table of command line flags I.K.E.M.E.N-Go was launched with', 'None', 'cmdFlags (table) - The command flags the engine was launched with.')
register_man('getCommandLineValue', 'Retrieves the value of the specified command line flag.', 'flagName (string) - The name of the flag whose value to retrieve.', 'value (string) - The string representation of the flag value.')
register_man('getConsecutiveWins', 'Gets the number of consecutive wins for the specified TeamSide', 'teamSide (int) - 1 for P1 side, 2 for P2 side', 'numWins (number) - The number of consecutive wins for the teamside.')
register_man('getDirectoryFiles', 'Returns a list of files in the specified path', 'path (string) - The full path to the directory.', 'fileList (table) - A list of files in the directory.')
register_man('getFrameCount', 'Gets the number of frames drawn so far.', 'None', 'frameCount (number) - The number of frames drawn so far.')
register_man('getJoystickGUID', 'Returns the GUID corresponding to the joystick at the specified index.', 'joyIdx (int) - The index of the joystick whose GUID to retrieve.', 'guid (string) - The GUID of the joystick at the specified index.')
register_man('getJoystickKey', 'Returns the number corresponding to the key input from the specified joystick index.', 'joyIdx - The index of the joystick to check.', 'keyNo (number) - The number of the joystick key pressed.')
register_man('getJoystickName', 'Returns the name of the joystick at the specified index.', 'joyIdx (int) - The index of the joystick whose name to retrieve.', 'name (string) - The name of the joystick.')
register_man('getJoystickPresent', 'Returns true if a joystick is present at the specified index, false otherwise.', 'joyIdx (int) - The index of the joystick to check for existence.', 'true if the joystick is present, false otherwise')
register_man('getKey', 'Retrieves a single keyboard input.', 'key (optional) (string) - The name of the key to check for input. Leave blank to receive a key for input.', 'result (variable) - true or false if the given key is provided and was pressed, otherwise returns the single key that was just pressed.')
register_man('getKeyText', 'Retrieves input keyboard text', 'None', 'keyText (string) - The key text string that was just input by the user.')
register_man('getMatchMaxDrawGames', 'Gets the max number of draw games the given teamside can have', 'teamSide (int) - 1 for P1 side, 2 for P2 side', 'maxDrawGames (number) - The number of max draw games the given side can have.')
register_man('getMatchWins', 'Returns the total number of matches the given teamside has won so far', 'teamSide (int) - 1 for P1 side, 2 for P2 side', 'numMatchWins (number) - The number of matches the given teamside has won so far.')
register_man('getRoundTime', 'Returns the round time elapsed so far, in ticks.', 'None', 'roundTime (int) - The round time elapsed so far, in ticks.')
register_man('getStageInfo', 'Returns a table of the following information for the selected stage (select screen only): name, def, portrait_scale, attachedchardef, stagebgm (select screen only)', 'stIdx (int) - The index of the selected stage to retrieve info for.', 'infoTable (table) - The table containing the specified info.')
register_man('getStageNo', 'Returns the number of the currently selected stage (select screen only).', 'None', 'stageIdx (number) - The index of the currently selected stage.')
register_man('getWaveData', 'Retrieves the specified sound from a given .SND file', 'sndFile (string) - The name of the .SND file to check.\ngroup (int) - The sound group to check.\nsound (int) - The sound number to check.\nmax (optional) (int) - Maximum number of loops before giving up searching for the group/sound pair.', 'data (Sound) - The WAV data of the given sound.')
register_man('gethitvar', 'Retrieves the specified GetHitVar for the active entity.', 'ghv (string) - The name of the GetHitVar to check.', 'value (variable) - The value of the GetHitVar')
register_man('groundlevel', "Returns the character's ground level, which is normally 0 but can be changed via GroundLevelOffset.", 'None', 'groundLevel (float) - The current groundLevel.')
register_man('guardbreak', "Returns true if the player's guard was broken, false otherwise.", 'None', "true if the current entity's guard was broken, false otherwise")
register_man('guardcount', 'Returns how many hits of the current attack were guarded. Similar to Hitcount.', 'None', 'guardCount (int) - The number of hits guarded in the current attack.')
register_man('guardpoints', 'Returns the amount of guard points the entity has remaining.', 'None', 'guardPts (int) - The number of remaining guard points.')
register_man('guardpointsmax', 'Returns the maximum number of guard points the entity can have.', 'None', 'guardPtsMax (int) - The maximum number of guard points the character can have.')
register_man('helper', 'Redirects the Lua context to the helper with the specified ID.', 'id (optional) - The ID of the helper to use.', 'true if the context successfully switched, false otherwise')
register_man('helperid', 'If the entity is a helper, returns their helperID (not to be confused with ID which is playerID)', 'None', 'hID (int) - The ID assigned to the helper.')
register_man('helperindex', 'Redirects the Lua context to the helper at the provided index for the active entity.', 'idx (int) - The index of the helper to switch to.', 'true if the context switched, false otherwise')
register_man('helperindexexist', 'Determines the existence of a helper at the provided index for the active entity.', 'idx (int) - The index of the helper to check', 'true if a helper exists at the given index, false otherwise')
register_man('hitbyattr', 'Checks if the player can be hit by an attack with the specified attribute. See also documentation for the attr parameter in HitDef as well as HitDefAttr.\n\nNote: Because HitBy and NotHitBy often last only one frame, player processing order can have a great influence in the return of this trigger.', 's_flag (string) - The state type flag\na_flag (string) - The attack type flag', 'true if the player can be hit by an attack with the specified attribute, false otherwise.')
register_man('hitcount', "Returns the number times the entity's current attack move has hit one or more opponents. This value is valid only for a single state; after any state change, it resets to 0. To prevent it from resetting to 0, set hitcountpersist in the StateDef (see cns documentation for details). The HitCount and UniqHitCount triggers differ only when the player is hitting more than one opponent. In the case where the player is hitting two opponents with the same attack, HitCount will increase by 1 for every hit, while UniqHitCount increases by 2.", 'None', 'The current hitcount of the current state.')
register_man('hitdefattr', "Returns the active HitDefAttr of the active entity's HitDef as a string.", 'None', 'attr (string) - The current HitDefAttr of the active HitDef.')
register_man('hitdefvar', "Returns information about the player's currently active HitDef or ReversalDef. The parameter format is the same as in the HitDef state controller.\nNote: When the player has no active HitDef or ReversalDef, this trigger will return the default values of each parameter. It is generally advised to check if a HitDef or ReversalDef is active first with HitDefAttr or ReversalDefAttr.", 'param (string) - Valid values are guard.dist.depth.bottom, guard.dist.depth.top, guard.dist.height.bottom, guard.dist.height.top, guard.dist.width.back, guard.dist.width.front, guard.pausetime, guard.sparkno, guard.shaketime, guarddamage, guardflag, guardsound.group, guardsound.number, hitdamage, hitflag, hitsound.group, hitsound.number, id, p1stateno, p2stateno, pausetime, priority, shaketime, sparkno, sparkx, sparky', 'res (dynamic) - The requested HitDefVar.')
register_man('hitfall', 'If the entity is currently in a gethit state, returns the fall flag of the hit. The output of this trigger is undefined if the player is not in a gethit state.', 'None', 'true if the entity is falling, false otherwise')
register_man('hitover', 'If the entity is in a gethit state, returns true when the hittime has expired, and false otherwise.', 'None', 'true if the entity is hurt and falling, false otherwise')
register_man('hitoverridden', 'Returns true during frame in which player has overridden default gethit behavior via HitOverride state controller, false otherwise.', 'None', 'true if the player is in the frame of a hitoverride, false otherwise')
register_man('hitpausetime', 'Returns the current hitPauseTime of the active entity.', 'None', 'hpt (int) - The hitPauseTime of the active entity.')
register_man('hitshakeover', 'If the entity is in a gethit state, returns true if the hit shake (the period when they are shaking in place) has ended, and false otherwise. ', 'None', 'true if the player is shaking for a hit, false otherwise.')
register_man('hitvelX', 'Gets the X value of the velocity imparted to the entity by a hit.', 'None', 'x (float) - The X HitVel parted to the entity.')
register_man('hitvelY', 'Gets the Y value of the velocity imparted to the entity by a hit.', 'None', 'y (float) - The Y HitVel parted to the entity.')
register_man('hitvelZ', 'Gets the Z value of the velocity imparted to the entity by a hit.', 'None', 'z (float) - The Z HitVel parted to the entity.')
register_man('id', "Returns the ID number of the player. The ID number is unique for every player throughout the course of a match. Any helper that is created during this time will also receive its own unique ID number. This trigger may be useful for getting opponents' ID numbers, to be later used with the \"playerID\" redirection keyword (see exp docs). Do not confuse playerID with targetID or helperID", 'None', 'pId (int) - the playerID of the entity.')
register_man('ikemenversion', "Returns the character's Ikemen version as a float.\nFor example, a character with ikemenversion = 0.98.2 in its DEF file will have IkemenVersion return 0.982000.", 'None', 'ikemenversion (float) - The IkemenVersion as a float.')
register_man('incustomanim', 'Returns true if the character is in a custom animation, such as when ChangeAnim2 is used in a custom state.', 'None', 'true if the character is in a custom anim, false otherwise.')
register_man('incustomstate', 'Returns true if the entity is in a custom state from a hit, false otherwise.', 'None', 'true if the entity is in a custom hit state, false otherwise')
register_man('index', "Returns the player's index as an integer. See PlayerIndex.", 'None', "pIdx (int) - The player's index")
register_man('indialogue', 'Returns true during ongoing dialogue initiated by Dialogue state controller.', 'None', 'true if dialogue is present on-screen, false otherwise')
register_man('inguarddist', 'Returns true if the entity is within the guard.dist specified by an active hitdef, false otherwise', 'None', 'true if the entity is within guarding distance, false otherwise')
register_man('inputtime', 'Returns number of frames since a given button was pressed or released. A positive number means the button is being held, while a negative number means it has been released. For players without keyctrl, it returns 0.', 'button (string) - The button to check. alid values are: B, F, D, U, a, b, c, x, y, z, s, d, w, m, L, R', 'inputTime (int) - The time in frames. since the given input was last pressed.')
register_man('introstate', 'Returns the current intro state number:\n0: Not applicable, or players have gained ctrl after "fight!"\n1: Pre-intro (RoundState = 0)\n2: Player intros (RoundState = 1)\n3: Round announcement\n4: Fight called', 'None', 'introState (int) - The current intro state.')
register_man('isasserted', "Returns true if the entity has specified AssertSpecial state controller flag asserted. Flags that affect all entities at once don't have to be asserted directly by entity to be detectable.", 'flagName (string) - The flag name to check.', 'true if the current flag is being asserted, false otherwise.')
register_man('isclsnproxy', 'Returns if the helper is a Clsn Proxy.', 'None', 'true if the helper is a CLSN proxy, false otherwise.')
register_man('ishelper', 'Used for determining if the current entity is a helper.', 'None', 'true if the current entity is a helper, false otherwise')
register_man('ishometeam', 'Used for determining if the current entity is on P1 side.', 'None', 'true if the entity belongs to P1 side, false otherwise.')
register_man('ishost', 'Returns true if the current player is a host in an online match', 'None', 'true if the player is the host of an online match, false otherwise')
register_man('jugglepoints', 'Returns the remaining juggle points between the entity and another entity with the specified ID. If the specified ID is not yet a target of the first entity, the trigger will simply return the maximum juggle points.', 'id (int) - The playerID of the entity whose juggle points should be checked.', 'jugglePts (int) - The number of remaining juggle points between this entity and the other specified.')
register_man('kill', 'Sets the life of the given playerNo.', 'pNo (int) - The playerNo to KO.\nlife (optional) (int) - The life value to set, or blank for 0')
register_man('lasthitter', 'Returns the player ID of the last player who hit somebody on the given teamside', 'teamSide (int) - 1 for P1 side, 2 for P2 side', 'pID (int) - The player ID of the last player who hit somebody.')
register_man('lastplayerid', 'Returns the last playerID that was generated by the engine.', 'None', 'pID (int) - The last ID that was generated by the engine.')
register_man('launchFight', 'Launches a fight with the given data. See launchFight(data) in start.lua for more information.', 'data (table) - The table of data to start the fight with.', 'true if the fight started successfully, false otherwise')
register_man('launchStoryboard', 'Launches a storyboard from the .DEF file at the given path.', 'filePath (string) - Path to file to storyboard .DEF to load.', 'true if the storyboard successfully loaded, false otherwise')
register_man('layerNo', 'Returns the layer number on which the character is currently being drawn on.', 'None', 'layerNo (int) - The current layerNo the character is being drawn on.')
register_man('leftedge', 'Returns the left edge pos of the stage.', 'None', 'leftEdge (float) - The left edge pos of the stage.')
register_man('lerp', 'Linear interpolation. Takes three arguments, and returns a number between two specified arguments at a specific increment.', 'a (float) - The min value.\nb (float) - The max value.')
register_man('life', 'Returns the current life this entity has remaining.', 'None', 'life (int) - The remaining life the entity has remaining.')
register_man('lifemax', 'Returns the maximum amount of life the current entity can have.', 'None', 'lifeMax (int) - The maximum amount of life this entity can have.')
register_man('loadDebugFont', 'Loads the specified font file as the debug font at the given scale. The default debug font is font/Open_Sans.def.', 'fontPath - The path to the debug font to use.\nscale (float) - The scale for the debug font')
register_man('loadDebugInfo', 'Loads the named debug info functions for running.', 'debugInfo (table) - The table of debug info function names to run.')
register_man('loadDebugStatus', 'Loads the named debug status functions for running.', 'debugStatus (table) - The table of debug status function names to run.')
register_man('loadGameOption', 'Loads the given config.ini and overwrites the current settings.', 'cfgFile (string) - The full or relative path to the config.ini to load.', 'cfg (Config Userdata) - The Userdata reference to the new Config.')
register_man('loadLifebar', 'Loads the lifebar with the specified .DEF', 'fileName (string) - The name of the lifebar .DEF file to load.')
register_man('loadState', 'Loads the last save state.', 'None')
register_man('loadStart', 'Begins loading the selected data (pre-fight only).', 'None')
register_man('loadText', 'Loads a text file into a string', 'fileName (string) - The relative or full path to the text file.', 'txt (string) - The text file as a string.')
register_man('loading', 'Returns true if the data is still loading from "loadStart", false otherwise', 'None', 'true if the data is still loading, false otherwise')
register_man('localcoordX', "Returns the X component of this entity's localcoord.", 'None', 'lclCoordX (float) - The X localcoord component of the current entity.')
register_man('localscaleY', "Returns the Y component of this entity's localcoord.", 'None', 'lclCoordY (float) - The Y localcoord component of the current entity.')
register_man('lose', 'Returns true if the current entity just lost the round, false otherwise.', 'None', 'true if the current entity just lost the round, false otherwise')
register_man('loseko', 'Returns true if the current entity just lost the round by KO, false otherwise.', 'None', 'true if the current entity just lost by a KO, false otherwise.')
register_man('losetime', 'Returns true if the current entity just lost the round by Time Over, false otherwise.', 'None', 'true if the current entity just lost by Time Over, false otherwise.')
register_man('man', "Returns information about the given Lua method name", "name (string) - The exact name, case-sensitive, of the function whose info should be returned.")
register_man('map', 'Returns the provided map of the current entity, case-insensitive', 'name (string) - The string name of the map to check.')
register_man('mapSet', 'Sets the map for the currently running character', 'mapName (string) - The name of the map to set.\nvalue (float) - The value of the map to set.')
register_man('matchReload', 'Reloads all characters and the stage, starts the match over, and closes the menu.', 'None')
register_man('matchno', 'Returns the current match number.', 'None', 'matchNo (int) - The current match number.')
register_man('matchover', 'Returns true if the match is over, false otherwise.', 'None', 'true if the match ended, false otherwise.')
register_man('matchtime', 'Returns the total time elapsed across the entire match.', 'None', 'mt (int) - The total time elapsed across the entire match.')
register_man('memberno', "Returns character's team member position. Team leader is 1, partners receive successive numbers.", 'None', 'mNo - Team member position.')
register_man('modelNew', 'Loads the given GLTF/GLB model at the given file path.', 'filePath (string) - The full or relative path to the GLTF/GLB model file.', 'model (Model Userdata) - The Userdata for the Model.')
register_man('modifyGameOption', 'Sets the value for the given game option.', 'optionName (string) - The dot-separated name of the game option to set.\noptionValue (dynamic) - The value of the option to set. Make sure the value being set is appropriate.')
register_man('motifstate', 'Allows retrieval of whether the specified post-round sequence is active.', 'param (string) - The name of the post-round sequence to check. Valid values are: continuescreen, victoryscreen, winscreen')
register_man('movecontact', "This trigger is valid only when the player is in an attack state. MoveContact gives a non-zero value if P2 has either been hit, or has guarded P1's attack. It gives 0 otherwise. P1 is the player, and P2 is their opponent.", 'None', '1 if during hitPause, up to the hittime of the HitDef, if the attack made contact.')
register_man('movecountered', "This trigger is valid only when the player is in an attack state. MoveCountered returns 1 on attack contact, at the exact frame that p1 interrupts p2 attack (true for 1 frame, even if both P1 and P2 countered each other's moves). After contact, MoveCountered's return value will increase by 1 for each game tick that P1 is not paused. It gives 0 otherwise.", 'None', '1 if during hitpause, and counts up thereafter.')
register_man('moveguarded', "This trigger is valid only when the player is in an attack state. MoveGuarded gives a non-zero value if P2 is guarding, or has guarded, P1's attack. It gives 0 otherwise. P1 is the player, and P2 is their opponent.", 'None', '1 if during guard pause, and counts up thereafter.')
register_man('movehit', "This trigger is valid only when the player is in an attack state. MoveHit gives a non-zero value if P2 has been hit by P1's attack. It gives 0 otherwise.", 'None', '')
register_man('movehitvar', "Similarly to GetHitVar, this trigger allows retrieving information about the last hit the player inflicted. This trigger works even if that hit acquired no target.", "mhv (string) - the name of the moveHitVar to retrieve. Valid values are 'cornerpush', 'frame', 'id', 'overridden', 'playerno', 'sparkx', 'sparky', and 'uniqhit'.", 'mhv (variable) - The requested moveHitVar')
register_man('movereversed', "This trigger is valid only when the player is in an attack state. MoveReversed gives a non-zero value if P1's attack has been reversed by P2.", 'None', 'moveReversed (int) - 1 if during reversal pause, and counts up thereafter.')
register_man('movetype', 'Returns the current moveType of the current entity.', 'None', 'mt (string) - The string representation of the moveType.')
register_man('mugenversion', "Returns the characer's Mugen version as a float. Returns 1.1 for characters with an Ikemen version, regardless of what's specified in the def file.", 'None', 'mv (float) - The Mugen version of the character.')
register_man('name', 'Returns the name of the current entity.', 'None', 'n (string) - The name of the current entity')
register_man('network', 'Returns true if in network or replay mode, false otherwise.', 'None', 'true if in network or replay mode, false otherwise')
register_man('numberToRune', 'Converts a number to a rune.', 'number (number) - The numeric representation of the rune, starting from 1 representing capital A.', 'rune (string) - The rune represented by the given number.')
register_man('numenemy', 'Returns the number of opponents that exist. Neutral players and normal helpers are not considered opponents.', 'None', 'numEnemy (int) - The number of opponents.')
register_man('numexplod', 'Returns the number of explods owned by this entity. If an ID is present, returns the number of explods with that ID.', 'id (int) (optional) - The explod ID to count.', 'numExplod - The number of explods.')
register_man('numhelper', 'Returns the number of helpers owned by this entity. If an ID is present, returns the number of helpers with that ID.', 'id (int) (optional) - The helper ID to count.', 'numHelper - The number of helpers.')
register_man('numpartner', 'Returns the number of partners that exist. Neutral players and normal helpers are not considered partners.', 'None', 'numPartner (int) - The number of partners that exist.')
register_man('numplayer', 'Returns the number of players that exist. Neutral players and helpers (normal or player) are not considered players. ', 'None', 'numPlayer - The number of players.')
register_man('numproj', 'Returns the total number of projectiles currently owned by the player.', 'None', 'numProj - The number of projectiles currently owned by the player.')
register_man('numprojid', 'Returns the number of projectiles of the given ID currently owned by the player.', 'id (int) - The ID of the projectile to check.', '')
register_man('numstagebg', 'Returns the number of BG elements in the stage that have the specified ID. If the ID argument is not used, or if ID is -1, it returns the total.', 'id (int) - The ID of the BG elements to check.', 'numStageBG (int) - The number of BG elements with the given ID.')
register_man('numtarget', 'This trigger takes an ID number as an optional argument. If the ID number is omitted, NumTarget returns the current number of targets for the player. If the ID number is included, then NumTarget returns the number of targets for the player which have that target ID number. The ID number must be greater than -1. An ID number of -1 or less will give the same behavior as if the ID number is omitted.', 'id (int) - The chain ID of the target to use.')
register_man('numtext', 'This trigger takes an ID number as an optional argument. If the ID number is omitted, NumText returns the number of texts owned by the player. If the ID number is included, then NumText returns the number of texts with that ID number that are owned by the player. The ID number must be greater than -1. An ID number of -1 or less will give the same behavior as if the ID number is omitted.', 'id (int) - The ID of the text to check.', 'numText (int) - The number of text objects with the given ID.')
register_man('offsetX', "Returns the value of the entity's x offset applied with OffSet sctrl.", 'None', 'offX (float) - The X offset as applied by Offset SCTRL.')
register_man('offsetY', "Returns the value of the entity's y offset applied with OffSet sctrl.", 'None', 'offY (float) - The Y offset as applied by Offset SCTRL.')
register_man('outrostate', 'Returns the current outro state number:\n0: Not applicable\n1: Payers can still act, allowing a possible double KO\n2: Players still have control, but the match outcome can no longer be changed\n3: Players lose control, but the round has not yet entered win states\n4: Player win states\n5: Round over (starting from the last frame of the RoundState sequence and continuing through the entire post-round sequence, individually detactable with MotifState trigger)', 'None', 'outroState (int) - The current outro state.')
register_man('overrideCharData', '', '')
register_man('p2', 'Redirects the Lua context to the opponent.', 'None', 'true if the context successfully switched, false otherwise')
register_man('p2bodydistX', 'Returns the X body distance of P2 from P1, where P1 is the player, and P2 is their opponent.', 'None', 'p2BDX (float) - The X distance between the nearest width boxes of P1 and the opponent.')
register_man('p2bodydistY', 'Returns the Y body distance of P2 from P1, where P1 is the player, and P2 is their opponent.', 'None', 'p2BDY (float) - The Y distance between the nearest height boxes of P1 and the opponent.')
register_man('p2bodydistZ', 'Returns the Z body distance of P2 from P1, where P1 is the player, and P2 is their opponent.', 'None', 'p2BDZ (float) - The Z distance between the nearest depth boxes of P1 and the opponent.')
register_man('p2distX', 'Returns the X distance of P2 from P1, where P1 is the player, and P2 is their opponent.', 'None', 'p2DX (float) - The X distance between P1 and the nearest opponent.')
register_man('p2distY', 'Returns the Y distance of P2 from P1, where P1 is the player, and P2 is their opponent.', 'None', 'p2DY (float) - The Y distance between P1 and the nearest opponent.')
register_man('p2distZ', 'Returns the Z distance of P2 from P1, where P1 is the player, and P2 is their opponent.', 'None', 'p2DZ (float) - The Z distance between P1 and the nearest opponent.')
register_man('p2life', "Returns the opponent's life.", 'None', 'p2Life (int) - The remaining life of the opponent.')
register_man('p2movetype', 'Returns the movetype of the opponent.', 'None', 'p2MT (string) - The movetype of the opponent.')
register_man('p2stateno', 'Returns the stateNo of the opponent.', 'None', "p2SN (int) - The opponent's current state number.")
register_man('p2statetype', 'Returns the stateType of the opponent.', 'None', 'p2ST (string) - The stateType of the opponent.')
register_man('palfxvar', 'Returns information about the player, background or global ("all") PalFX.', 'param (string) - The parameter to retrieve. Valid values are: time\nadd.r, add.g, add.b\nmul.r, mul.g, mul.b\ncolor, hue, invertall, invertblend\nbg.time\nbg.add.r, bg.add.g, bg.add.b\nbg.mul.r, bg.mul.g, bg.mul.b\nbg.color, bg.hue, bg.invertall\nall.time\nall.add.r, all.add.g, all.add.b\nall.mul.r, all.mul.g, all.mul.b\nall.color, all.hue, all.invertall, all.invertblend', 'pfv (dynamic) - The palFX value.')
register_man('palno', 'Returns the current palette number of the player.', 'None', 'palNo (int) - The current palette number of the entity.')
register_man('panicError', 'Raises an error that causes the engine to panic and exit.', 'msg (string) - Error message string.')
register_man('parent', 'Redirects the Lua context to the parent, if the current context is a helper.', 'None', 'true if the context successfully switched, false otherwise')
register_man('parentdistX', 'If the current entity is a helper, returns the X distance of the helper from its parent.', 'None', 'pDistX (float) - The X distance between the current helper and its parent.')
register_man('parentdistY', 'If the current entity is a helper, returns the Y distance of the helper from its parent.', 'None', 'pDistY (float) - The Y distance between the current helper and its parent.')
register_man('parentdistZ', 'If the current entity is a helper, returns the Z distance of the helper from its parent.', 'None', 'pDistZ (float) - The Z distance between the current helper and its parent.')
register_man('partner', 'Redirects the Lua context to the partner', 'partnerNo (int) - The index of the partner to switch to.', 'true if the context successfully switched, false otherwise')
register_man('paused', 'Returns true if the system is debug paused, false otherwise.', 'None', 'true if the system is debug paused, false otherwise.')
register_man('pausetime', 'Returns the remaining pause time of an entity. Do not confuse this with hitpausetime()', 'None', 'pauseTime (int) - The remaining pause time of the entity.')
register_man('physics', 'Returns the current physics of the entity.', 'None', 'phys (string) - The current physics handling of the entity.')
register_man('playBGM', 'Plays the specified BGM with the specified parameters.', 'bgmName (string) - The path of the BGM to play.\nloop (int) - The number of times this track should loop. Use -1 for infinite looping.\nvolume (int) - The volume to play the BGM at, from 0 to 100\nloopstart (int) - Loop start sample position.\nloopend (int) - Loop end sample position.\nstartposition - The sample position to start playing from.\nfreqmul (float) - Pitch and tempo multiplier.')
register_man("playSnd", "Plays a sound for the current player", "g (int) - Sound group\nn (int) - Sound number\nvo (int) - The volumescale to play the sound at\nf (boolean) - If true, will play the sound from FightFX\nch (int) - Sound channel\nlw (boolean) - If true, will be low priority\nfr - Frequency multiplier\nlp (boolean) - If true, the sound will loop\np (float) Pan value\npriority (int) - Sound priority\nloopstart (int) - Loop start sample position\nloopend (int) - Loop end sample position\nstartposition (int) - Sample position to begin playing from\nloopcount (int) - Number of times to loop the effect\nsgh (bool) - set to true to stop playing this sound on GetHit.\nccs (bool) - set to true to stop playing this sound on ChangeState")
register_man('player', 'Redirects the Lua context to the player at the specified index.', 'pNo (int) - The playerNo to switch context to.', 'true if the context successfully switched, false otherwise')
register_man('playerBufReset', 'Resets all the command buffers for the given playerNo, if specified. If not, clears the command buffer for all characters.', 'pNo (int) - The playerNo whose command buffer to reset.')
register_man('playercount', 'Returns the number of players.', 'None', 'pCount (int) - The number of players.')
register_man('playerid', 'Redirects the Lua context to the specified player ID.', 'pId (int) - Player ID to switch context to.', 'true if the context successfully switched, false otherwise')
register_man('playeridexist', 'Determines the existence of a given player ID', 'pId (int) - The player ID whose existence to check for.', 'true if a player with the given ID exists, false otherwise.')
register_man('playerindex', 'Redirects the Lua context to the player(helpers included) with the specified index.', 'pIdx (int) - Index of the player to switch context to.', 'true if the context successfully switched, false otherwise')
register_man('playerindexexist', 'Returns true if a player with the specified index number exists, false otherwise.', 'pIdx (int) - Index of the player whose existence to check.', 'true if the player exists, false otherwise')
register_man('playerno', 'Returns the playerNo of the active entity', 'None', 'pNo (int) - The playerNo of the active entity.')
register_man('playernoexist', 'Returns true if a player with the specified player number exists, false otherwise.', 'pNo (int) - Number of the player whose existence to check.', 'true if the player exists, false otherwise')
register_man('posX', 'Returns the X position of the current active entity.', 'None', 'x (float) - Pos X')
register_man('posY', 'Returns the Y position of the current active entity.', 'None', 'y (float) - Pos Y')
register_man('posZ', 'Returns the Z position of the current active entity.', 'None', 'z (float) - Pos Z')
register_man('postmatch', 'Returns true if the game is in post-match, false otherwise.', 'None', 'true if the game is in post-match, false otherwise')
register_man('powMax', "Sets the given playerNo's power to PowerMax", 'pNo (int) - PlayerNo whose power to set to PowerMax')
register_man('powMaxAll', "Sets the power of all players to their PowerMax", 'None')
register_man('power', 'Returns the current power of the current active entity.', 'None', 'power (int) - The current power of the entity.')
register_man('powermax', 'Returns the maximum amount of power the entity can have.', 'None', 'powerMax (int) - The maximum amount of power the entity can have.')
register_man('preloadListChar', 'Used to help generate preloaded character sprites/anims.', 'group/anim (int) - The sprite group or animNo to use.\nno (int) (not required for anim) - Sprite number to use.')
register_man('preloadListStage', 'Used to help generate preloaded stage sprites/anims.', 'group/anim (int) - The sprite group or animNo to use.\nno (int) (not required for anim) - Sprite number to use.')
register_man('prevanim', 'Returns the previous animation this entity was in prior to current.', 'None', 'prevAnim (int) - The previous anim the entity was in.')
register_man('prevmovetype', 'Returns the previous moveType this entity had prior to current.', 'None', 'prevMoveType (string) - The previous moveType this entity had.')
register_man('prevstateno', 'Returns the previous stateNo this entity was in prior to the current.', 'None', 'prevStateNo (int) - The previous stateNo this entity was in.')
register_man('prevstatetype', 'Returns the previous stateType this entity had prior to current.', 'None', 'prevStateType (string) - The previous stateType this entity had.')
register_man('printConsole', 'Prints a message to the console.', 'msg (string) - The message to print to the console.')
register_man('projcanceltime', "This trigger takes a required nonnegative ID number as an argument. If the player's last projectile to make any kind of contact was cancelled by an opponent's projectile and had the specified ID number, then this method returns the number of ticks since that contact occurred. If the specified ID number is 0, then the projectile ID is not checked. If no projectile meets all the above conditions, then this method returns -1.", 'projId (int) - ID of the proj to check.', 'pct (int) - Ticks elapsed since cancel of the projectile.')
register_man('projcontacttime', "This trigger takes a required nonnegative ID number as an argument. If the player's last projectile to make any kind of contact, made contact with the opponent and had the specified ID number, then this method returns the number of ticks since that contact occurred. If the specified ID number is 0, then the projectile ID is not checked. If no projectile meets all the above conditions, then this method returns -1.", 'projId (int) - ID of the proj to check.', 'pct (int) - Ticks elapsed since contact of the projectile.')
register_man('projguardedtime', "This trigger takes an required nonnegative ID number as an argument. If the player's last projectile to make any kind of contact was guarded by the opponent and had the specified ID number, then this method returns the number of ticks since that contact occurred. If the specified ID number is 0, then the projectile ID is not checked. If no projectile meets all the above conditions, then this method returns -1.", 'projId (int) - ID of the proj to check.', 'pgt (int) - Ticks elapsed since the projectile was guarded.')
register_man('projhittime', "This trigger takes an required nonnegative ID number as an argument. If the player's last projectile to make any kind of contact successfully hit the opponent and had the specified ID number, then this method returns the number of ticks since that contact occurred. If the specified ID number is 0, then the projectile ID is not checked. If no projectile meets all the above conditions, then this method returns -1.", 'projId (int) - ID of the proj to check.', 'pht (int) - Ticks elapsed since the projectile hit something.')
register_man('projvar', 'Returns the value of the given projectile parameter.', 'id (int) - The ID of the projectile to check. Use -1 to iterate over all.\nidx (int) - The index of the projectile to check. Projectile indices are in spawn order, and shifts when another projectile with the same ID is destroyed.\nparam (string) - The param to check. Please check wiki for valid parameter names.')
register_man('puts', 'Why would you do this?', 'Why?', 'Why?')
register_man('ratiolevel', "Returns the character's ratio level: from 1 to 4, if the level is set, otherwise it returns 0.", 'None', "ratioLevel (int) - The character's ratio level.")
register_man('receiveddamage', "Returns the total damage dealt by the opposite team to this character, in the currently ongoing combo. This value is valid as long as the opposite team combo count stays above 0, otherwise it returns 0 too.", 'None', 'recvdDmg (int) - Total damage dealt to this character in the current combo.')
register_man('receivedhits', "Returns the total number of hits done by the opposite team to this character, in the currently ongoing combo. Unlike GetHitVar(hitcount), it takes into account all hits, including those applied by HitAdd. This value is valid as long as the opposite team combo count stays above 0, otherwise it returns 0 too.", 'None', "recvdHits (int) - Total hits this character has received in the current combo.")
register_man('redlife', "Returns the amount of red life the entity has.", 'None', 'redLife (int) - The remaining red life of the entity.')
register_man('refresh', 'Refreshes the screen aand updates the sound.', 'None')
register_man("register_man", "Registers a command with man given a provided description and arguments, the latter separated by newlines (\\n)", "commandName (string) - The exact name, case-sensitive, of the function whose info should be registered.\ndescription (string) - A concise description of what the command does.\nargs (string) - The arguments, separated by newlines and their data type specified next to it in parentheses e.g. idx (int)")
register_man('reload', 'Reloads the characters, stage, and lifebars.', 'None')
register_man('remapInput', 'Remaps the input from one player index to another player index', 'src (int) - Source player index.\ndst (int) - Dest player index.')
register_man('removeDizzy', 'Unsets the system char dizzy flag for the current entity.', 'None')
register_man('replayRecord', 'Starts recording the replay file at the given path.', 'replayPath (string) - Path to the replay file to save.')
register_man('replayStop', 'Stops recording the current replay file.', 'None')
register_man('resetAILevel', 'Resets the AI Level to 0 for all CPU-controlled opponents.', 'None')
register_man('resetKey', 'Resets the system key input.', 'None')
register_man('resetMatchData', 'Clears all effects.', 'None')
register_man('resetRemapInput', 'Clears all input remaps.', 'None')
register_man('resetScore', 'Clears the score.', 'None')
register_man('reversaldefattr', "Returns the attribute string of the current entity's ReversalDef", 'None', 'reversalDefAttr (string) - The string representation of the reversalDef attr.')
register_man('rightedge', 'Returns the right edge pos of the stage.', 'None', 'rightEdge (float) - The right edge pos of the stage.')
register_man('root', 'Redirects the Lua context to the root.', 'None', 'true if the context successfully switched, false otherwise')
register_man('rootdistX', 'If the entity is a helper, returns the X distance between it and the root.', 'None', 'rootDistX (float) - The X distance between this entity and the root.')
register_man('rootdistY', 'If the entity is a helper, returns the Y distance between it and the root.', 'None', 'rootDistY (float) - The Y distance between this entity and the root.')
register_man('rootdistZ', 'If the entity is a helper, returns the Z distance between it and the root.', 'None', 'rootDistZ (float) - The Z distance between this entity and the root.')
register_man('roundReset', 'Resets the round.', 'None')
register_man('roundResetNow', 'Resets the round and closes the menu, if it is open.', 'None')
register_man('roundno', 'Returns the current round number.', 'None', 'roundNo (int) - The current round number.')
register_man('roundover', 'Returns true if the round is over, false otherwise.', 'None', 'true if the round is over, false otherwise')
register_man('roundsexisted', 'Returns the number of rounds this player has existed for.', 'None', 're (int) - Rounds this player has existed thus far.')
register_man('roundstart', 'Returns true if the round just started.', 'None', 'true if the round JUST started, false otherwise.')
register_man('roundstate', 'Returns the current state of the round.', 'None', 'rs (int) - Round state number.')
register_man('roundswon', "Returns how many total rounds the teamside has won during the current match. Resets between matches.", 'None', "rw (int) - The number of rounds this entity's team has won.")
register_man('roundtime', 'Returns the tick count since the start of the round.', 'None', 'rt (int) - The tick count since the start of the round.')
register_man('runorder', 'At the start of each frame, players are sorted into a list for code processing based on their current actions (see character processing order). RunOrder returns their position in this list as an integer.', 'None', 'ro (int) - The run order number of this entity.')
register_man('saveGameOption', 'Saves the value to the given game option.', 'None')
register_man('saveState', 'Saves the current state of the game for later reloading.', 'None')
register_man('scaleX', 'Returns the X Scale of the active entity.', 'None', 'scaleX (float) - The X scale of this entity.')
register_man('scaleY', 'Returns the Y Scale of the active entity.', 'None', 'scaleY (float) - The Y scale of this entity.')
register_man('scaleZ', 'Returns the Z Scale of the active entity.', 'None', 'scaleZ (float) - The Z scale of this entity.')
register_man('score', "Returns the current match score for the active entity's teamside.", 'None', "score (int) - The current match score for this entity's teamside.")
register_man('scoretotal', "Returns the current total score for the active entity's teamside", 'None', "st (int) - The total score of this entity's teamside")
register_man('screenheight', "Returns the height of the screen space in the entity's local coordinate space.", 'None', "sh (float) - Height of the screen space in the entity's local coordinate space.")
register_man('screenposX', "Gets the X value of the entity's position relative to the top-right corner of the screen.", 'None', "sx (float) - The X screen position of this entity relative to the top-right.")
register_man('screenposY', "Gets the Y value of the entity's position relative to the top-right corner of the screen.", 'None', "sy (float) - The Y screen position of this entity relative to the top-right.")
register_man('screenshot', 'Takes a screenshot of the current screen.', 'None')
register_man('screenwidth', "Returns the width of the screen space in the entity's local coordinate space.", 'None', "sw (float) - Width of the screen space in the entity's local coordinate space.")
register_man('searchFile', 'Searches for a file in a table containing a list of directories.', 'fileName (string) - File name to search for.\ndirTable (table) - Directory path table. Each entry in the table should be a path string.', 'filePath (string) - The full path to the first file found matching.')
register_man('selectChar', 'Selects a character for the given teamside given a character ref and a palette index.', 'ts (int) - Must be 1 or 2\ncharRef (int) - Ref to the char from the select screen.\npi (int) - Palette index (from 1-12)', '1 if there are still characters to select, 2 if everyone is finished being selected.')
register_man('selectStage', 'Selects a stage from the stage select list.', 'sNo (int) - Stage index')
register_man('selectStart', 'Clears the selected characters and starts the character selection process.', '')
register_man('selectno', 'Returns the selectNo of the current player.', 'None', 'sNo (int) - The select number of the current player.')
register_man('selfState', 'Sets the current entity to the given stateNo in their own states.', 'sn (int) - StateNo to return to.')
register_man('selfanimexist', "Like AnimExist, except that this only checks P1's animation data. If P1 has been given P2's animation data by a hit, SelfAnimExist will not check P2's animation data to determine whether or not a given action exists.", 'animNo (int) - The animNo to check for existence.', "true if the anim exists in P1's data, false otherwise")
register_man('selfstatenoexist', "Checks for the existence of a state only within P1's state numbers, even when P1 is custom stated by a hit. Returns 1 if there is a statedef with the specified number. Otherwise it returns 0. Use the statedef number you want to recognize in parentheses.", 'None', 'true if the character has this stateNo in their own set of states, false otherwise.')
register_man('setAILevel', 'Sets the AILevel for the active entity.', 'level (int) - AILevel value (0-8)')
register_man('setAccel', 'Sets the acceleration factor of the game speed.', 'accel (float) - Accel value.')
register_man('setAutoLevel', 'Sets the auto level for autolevel.save writing.', 'al (boolean) - true for enabled, false for disabled.')
register_man('setCom', 'Sets the given player to CPU control at the specified AILevel.', 'pNo - Player number.\naiL - AI Level (1-8)')
register_man('setConsecutiveRounds', 'Toggles consecutive rounds', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('setConsecutiveWins', 'Sets the number of consecutive wins for the specified team side.', 'ts (int) - The teamside to modify\nconsec_wins (int) - The number of consecutive wins to assign to the team.')
register_man('setContinue', 'Sets the continue flag.', 'toggle (bool) - true to toggle on, false to toggle off.')
register_man('setDizzyPoints', 'Sets the dizzy points for the current entity.', 'dp (int) - The dizzy points to set to.')
register_man('setGameMode', 'Sets the current game mode.', 'gameMode (string) - The game mode to set.')
register_man('setGameSpeed', 'Sets the game speed.', 'gs (int) - The game speed to set.')
register_man('setGuardPoints', 'Sets the guard points for the current entity.', 'gp (int) - The guard points to set to.')
register_man('setHomeTeam', 'Sets the given teamside as the home team.', 'ts (int) - Team Side to set as home team.')
register_man('setKeyConfig', '', '')
register_man('setLife', 'Sets life for the current entity to the given value, if they are alive.', 'life (int) - The life value to set to.')
register_man('setLifebarElements', '', '')
register_man('setLifebarLocalcoord', 'Sets the localcoord values for the lifebar.', 'localcoord_x (int) - The X dimension for the localcoord\nlocalcoord_y - The Y dimension for the localcoord')
register_man('setLifebarOffsetX', 'Sets the X offset factor for drawing all lifebar elements.', 'x_off (float) - The X value to offset all lifebar elements by')
register_man('setLifebarOffsetY', 'Sets the Y offset factor for drawing all lifebar elements.', 'y_off (float) - The Y value to offset all lifebar elements by')
register_man('setLifebarPortraitScale', 'Sets the scale for lifebar portraits.', 'scale (float) - The scale factor to use for lifebar portraits.')
register_man('setLifebarScale', 'Sets the scale for the lifebars.', 'scale (float) - The scale factor to use for all lifebar elements.')
register_man('setLifebarScore', 'Sets the score for the lifebars.', 'score_p1 (int) - The P1 score\nscore_p2 (int) - The P2 score')
register_man('setLifebarTimer', '', '')
register_man('setLuaLocalcoord', 'Sets the localcoord for Lua elements.', 'lc_x (int) - The X localcoord dimension\nlc_y (int) - The Y localcoord dimension')
register_man('setLuaPortraitScale', 'Sets the scale for Lua portraits.', 'scale (float) - The scale factor to use for Lua portraits.')
register_man('setLuaSpriteOffsetX', 'Sets the X offset for Lua sprites.', 'xOff (float) - The X offset to set to.')
register_man('setLuaSpriteScale', 'Sets the scale for Lua sprites.', 'scale (float) - The scale factor to use for Lua sprites.')
register_man('setMatchMaxDrawGames', 'Sets the number of max draw games for the match for the given teamside.', 'ts (int) - The team side to assign max draw games to.\nmaxDrawGames (int) - The max draw games to set.')
register_man('setMatchNo', 'Sets the internal match number.', 'matchNo (int) - The current match number.')
register_man('setMatchWins', 'Sets the number of match wins for the given team side.', 'ts (int) - The team side to modify\nnumWins (int) - The number of wins to assign to the team.')
register_man('setMotifDir', 'Sets the system motif directory to the specified path.', 'filePath (string) - The full or relative filepath to the motif directory.')
register_man('setPlayers', 'Sets the number of players in the system.', 'numPlayers (int) - The number of players to set.')
register_man('setPower', 'Sets power for the current entity.', 'p (int) - The power to set for this entity.')
register_man('setRedLife', 'Sets red life for the current entity.', 'rl (int) - The red life to set for this entity.')
register_man('setRoundTime', 'Sets the max round time for the game.', 'rt (int) - The max round time.')
register_man('setTeamMode', 'Sets the team mode for the given team side.', 'ts (int) - The team side to modify.\ntm (int) - The Team Mode to set.\nnt (int) - The team size to set.')
register_man('setTime', 'Sets the current round time to the specified value.', 'rt (int) - The round time to set to.')
register_man('setTimeFramesPerCount', 'Sets the frames per count of the current lifebar.', "fpc (int) - The frames per count to set for the lifebar's timer")
register_man('setWinCount', 'Sets the win count for the given team side.', 'ts (int) - The teamside to set the win count for\nwins (int) - the number of wins to set for the team side')
register_man('sffNew', 'Creates a new SFF from the given file path.', 'filePath (string) - The full or relative path to the .SFF to load.', 'sff (SFF Userdata) - The new SFF Userdata reference.')
register_man('sign', 'Returns the sign of the current number as +/- 1', 'num (number) - The number to check the sign of.', '1 if the number is positive, -1 if the number is negative, 0 for 0.')
register_man('sleep', 'Sleeps for the given amount of nanoseconds.', 'sleepTime_ns (int) - Sleep time in nanoseconds.')
register_man('sndNew', 'Loads a new SND file from the given path.', 'sndPath (string) - Path to the SND file.', 'snd (Snd) - The Snd structure.')
register_man('sndPlay', 'Plays a sound from a .SND file.', 'snd (Snd) - The SND to use\ngroup (int) - Sound group\nnumber (int) - Sound number\nvs (int) - Volume scale (0-100)\npan (float) - Panning\nloopstart (int) - Loop start sample\nloopend (int) - Loop end sample\nstartposition (int) - Start position sample')
register_man('sndPlaying', 'Returns true if the given sound is playing.', 'snd (Snd) - SND instance to use\ngroup (int) - Sound group\nnumber (int) - Sound number', 'true if the given sound is playing, false otherwise')
register_man('sndStop', 'Stops the sound playing on the given channel', 'ch (int) - The channel of the sound to stop playing.')
register_man('soundvar', 'Returns the specified sound channel parameter. Use -1 for channelNo to find the first sound available.', '')
register_man('sprpriority', 'Returns the current sprite layer priority of the active entity.', 'None', 'sprPriority (int) - The sprite priority of the current entity.')
register_man('sszRandom', 'Returns a random integer from the game seed. Use this to prevent desyncs.', 'None', 'random (int) - A random integer.')
register_man('stagebackedgedist', 'Returns the distance to the stage edge (corner) behind the player.', 'None', 'sbed (float) - The distance to the stage edge (corner) behind the player.')
register_man('stagebgvar', "Returns information about the stage's BG elements.", 'id (int) - The ID of the element to be checked\nidx (int) - The index of the element to be checked\nparam (string) - The parameter to check. Valid values are: actionno, delta.x, delta.y, id, layerno, pos.x, pos.y, start.x, start.y, tile.x, tile.y, velocity.x, velocity.y', 'res (dynamic) - The requested parameter.')
register_man('stageconst', "Returns the value of one of the stage's constants. Stage constant variables can be set under stage's DEF [Constants] section.", 'param - The name of the constant to return.', 'c (float) - The constant to return.')
register_man('stagefrontedgedist', 'Returns the distance to the stage edge (corner) in front of the player.', 'None', 'sfed (float) - The distance to the stage edge (corner) in front of the player.')
register_man('stagetime', "Returns the stage's internal time, or the amount of ticks since the last stage reset. The value returned by this trigger corresponds directly to the amount of times stage backgrounds have been updated (taking into account pausebg, resetbg, etc), allowing one to for instance reliably synchronize attachedchar actions to what's currently displayed by the stage.", 'None', 'stagetime (int) - The current StageTime.')
register_man('stagevar', 'Returns information about the stage. A limited number of parameters are supported.', 'param (string) - The name of the stage parameter to check. Valid values are: info.name, info.displayname, info.authorname, camera.ytension.enable, camera.boundleft, camera.boundright, camera.boundhigh, camera.boundlow, camera.verticalfollow, camera.floortension, camera.tensionhigh, camera.tensionlow, camera.tension, camera.startzoom, camera.zoomout, camera.zoomin, camera.zoomindelay, camera.zoominspeed, camera.zoomoutspeed, camera.tensionvel, camera.cuthigh, camera.cutlow, camera.yscrollspeed, camera.autocenter, playerinfo.leftbound, playerinfo.rightbound, playerinfo.topbound, playerinfo.botbound, scaling.topscale, bound.screenleft, bound.screenright, stageinfo.zoffset, stageinfo.zoffsetlink, stageinfo.xscale, stageinfo.yscale, shadow.angle, shadow.xangle, shadow.yangle, shadow.intensity, shadow.color, shadow.yscale, shadow.fade.range, shadow.xshear, shadow.offset, shadow.window, shadow.projection, shadow.focallength, reflection.intensity, reflection.angle, reflection.xangle, reflection.yangle, reflection.yscale, reflection.offset, reflection.window, reflection.projection, reflection.focallength, info.ikemenversion, info.mugenversion, stageinfo.localcoord.x, stageinfo.localcoord.y.', 'res (dynamic) - The requested stageVar value.')
register_man('stand', 'Sets the given player to the stand state.', 'pNo (int) - The playerNo to make stand up.')
register_man('standAll', 'Sets all players to the stand state.', 'None')
register_man('standby', 'Returns true if character is under standby effect (assigned by TagOut sctrl).', 'None', 'sb (bool) - true if character is under standby effect (assigned by TagOut sctrl), false otherwise.')
register_man('stateInfo', '', '')
register_man('stateno', 'Returns the current stateNo of the current entity.', 'None', 'sno (int) - The current stateNo of the current entity.')
register_man('stateowner', 'Switches the context to the owner of the currently running state.', 'None', 'true if the context successfully switched, false otherwise')
register_man('stateownerid', 'Returns the ID of the owner of the currently running state for the current entity.', 'None', 'soid (int) - The ID of the owner of the currently running state.')
register_man('stateownername', 'Returns the name of the owner of the currently running state for the current entity.', 'None', 'son (string) - The name of the owner of the currently running state.')
register_man('stateownerplayerno', 'Returns the playerNo of the owner of the currently running state for the current entity.', 'None', 'sop (int) - The playerNo of the owner of the currently running state.')
register_man('statetype', 'Returns the current statetype of the current entity.', 'None', 'st (string) - The current statetype as a string of "S", "C", "A", or "L"')
register_man('statusInfo', '', '')
register_man('stopAllSound', 'Stops all playing sounds.', 'None')
register_man('stopSnd', 'Stops all sounds playing for the current entity.', 'None')
register_man('synchronize', "Don't.", "Just don't.")
register_man('sysfvar', 'Returns the value of the system float var at the given index.', 'sfvidx (int) - The index of the SysFVar to check.', 'sfv (float) - The value of the SysFVar.')
register_man('sysvar', 'Returns the value of the system int var at the given index', 'svidx (int) - The index of the SysVar to check.', 'sv (int) - The value of the SysVar.')
register_man('target', 'Switches the context to the current target.', 'id (int) - The ID of the target.\nidx (int) - The index of the affected target.', 'true if the context successfully switched, false otherwise')
register_man('teamleader', 'Returns playerno of the character that is considered a team leader. In modes where only one player is controlled in particular round (single, turns and ratio) it will be either 1 or 2, depending on team side. In simul and tag modes, team leader is the first party member (again 1 or 2) by default, but who is considered a leader can be also dynamically adjusted via optional TagIn sctrl leader parameter.\n\nManually swapping leader changes lifebar elements assignment - leader always uses P1 (or P2, depending on team side) lifebar elements, remaining players positions are moved accordingly, in ascending players order.', 'None', 'pNo (int) - The playerNo of the player who is considered team leader.')
register_man('teammode', 'Returns the team mode of the current player side.', 'None', 'tm (string) - The team mode, as a string. Valid values are: "single", "simul", "turns", and "tag"')
register_man('teamside', 'Returns the team side of the current entity.', 'None', 'ts (int) - The team side of the current entity.')
register_man('teamsize', 'Returns the team size of the current entity.', 'None', "ts (int) - The size of the current entity's team")
register_man('textImgDraw', 'Draws the current textImg reference.', 'textImg (TextSprite Userdata) - The TextSprite to draw.')
register_man('textImgNew', 'Creates a new textImg reference.', 'None', 'textImg (TextSprite) - The new TextSprite Userdata reference.')
register_man('textImgSetAlign', 'Sets the alignment for the textImg.', 'textImg (TextSprite) - The TextSprite to modify.\nalign (int) - The alignment for the TextSprite (-1 for left, 0 for center, 1 for right).')
register_man('textImgSetAngle', 'Sets the angle for the textImg.', 'textImg (TextSprite) - The TextSprite to modify.\nangle (float) - The angle for the TextSprite.')
register_man('textImgSetBank', 'Sets the bank for the textImg to use for drawing.', 'textImg (TextSprite) - The TextSprite to modify.\nbank (int) - The bank in the font to use for the TextSprite.')
register_man('textImgSetColor', 'Sets the color for the textImg to use for drawing.', 'textImg (TextSprite) - The TextSprite to modify.\nr (int) - The red component, from 0-255\ng (int) - The green component, from 0-255\nb (int) - The blue component, from 0-255')
register_man('textImgSetFont', 'Sets the font for the textImg to use for drawing.', 'textImg (TextSprite) - The TextSprite to modify.\nfnt (Fnt) - The Fnt Userdata to use for drawing.')
register_man('textImgSetPos', 'Sets the pos for the textImg to use for drawing.', 'textImg (TextSprite) - The TextSprite to modify.\nx (float) - the X position of the textImg.\ny (float) - the Y position of the textImg.')
register_man('textImgSetScale', 'Sets the scale for the textImg to use for drawing.', 'textImg (TextSprite) - The TextSprite to modify.\nx (float) - The X Scale of the textImg.\ny (float) - The Y Scale of the textImg.')
register_man('textImgSetText', 'Sets the text for the textImg to use for drawing.', 'textImg (TextSprite) - The TextSprite to modify.\ntext (string) - The text to set the textImg for drawing.')
register_man('textImgSetWindow', 'Sets the window for the textImg to use for drawing.', 'textImg (TextSprite) - The TextSprite to modify.\nx (float) - The X position of the Window\ny (float) - The Y position of the Window\nw (float) - The width of the Window\nh (float) - The height of the Window')
register_man('textImgSetXShear', 'Sets the X shear for the textImg to use for drawing.', 'textImg (TextSprite) - The TextSprite to modify.\nxShear (float) - The X shear factor')
register_man('tickspersecond', 'Returns the number of ticks per second. Useful for time calculations.', 'None', 'tps (int) - The current ticks per second.')
register_man('time', 'Returns the current state time of the current entity.', 'None', "t (int) - The state time of the current entity.")
register_man('timeelapsed', 'Returns the amount of clock ticks since the battle began (0 if time is disabled). Value returned by this trigger corresponds to lifebar timer (only ticks during RoundState = 2)', 'None', 'te (int) - The amount of clock ticks since the battle began (0 if time is disabled).')
register_man('timemod', 'Returns the remainder when the state-time of the player is divided by the specified value.\n\nThe % operator subsumes the functionality of TimeMod, so it is recommended that you use % instead.', 'modVal (int) - The value to mod time by.', 'tm (int) - The remainder when the state-time of the player is divided by the specified value.')
register_man('timeremaining', 'Returns the amount of clock ticks until time over (-1 if time is disabled). Value returned by this trigger corresponds to lifebar timer (only ticks during RoundState = 2)', 'None', 'tr (int) - the amount of clock ticks until time over (-1 if time is disabled).')
register_man('timetotal', 'Returns the total number of clock ticks that have elapsed so far. Takes into account previous rounds and matches since the start of this game mode.', 'None', 'tt (int) - the total number of clock ticks that have elapsed so far.')
register_man('toggleAI', 'Toggles AI for the given player.', 'pNo (int) - The playerNo to toggle AI for.')
register_man('toggleClsnDisplay', 'Toggles collision box display.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleContinueScreen', 'Toggles the continue screen.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleDebugPause', 'legacy mconsole command for toggling debug pause and closing the menu.', 'None')
register_man('toggleDialogueBars', 'Toggles the dialogue bars.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleFullscreen', 'Toggles fullscreen mode.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleLifebarDisplay', 'Toggles lifebar display.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleMaxPowerMode', 'Toggles max power for all ', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleMaxPowerModeAll', 'legacing mconsole command for toggling max power for all and setting the debug flags for P1 and P2.', 'None')
register_man('toggleNoSound', 'Toggles system no sound.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('togglePause', 'Toggles system paused.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('togglePlayer', 'Toggles the player on or off.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('togglePostMatch', 'Sets the post-match toggle flag.', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleVsync', 'Toggles vertical synchronization (Vsync).', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleVictoryScreen', 'Toggles the victory screen', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleWinScreen', 'Toggles the win screen', 'toggle (bool) - true to toggle on, false to toggle off')
register_man('toggleWireframeDisplay', "Toggles wireframe display (only for 3D BG's)", 'toggle (bool) - true to toggle on, false to toggle off')
register_man('topboundbodydist', "Like TopBoundDist, except this trigger accounts for the player's top edge parameter, as defined by the Depth state controller.", 'None')
register_man('topbounddist', "TopBoundDist gives the distance between the player's z-axis and the topbound limit of the stage.", 'None')
register_man('topedge', 'TopEdge returns the y position of the top edge of the screen, in absolute stage coordinates. ', 'None')
register_man('uniqhitcount', "Returns the total number of hits the player's current attack move has done. This value is valid only for a single state; after any state change, it resets to 0. To prevent it from resetting to 0, set hitcountpersist in the StateDef (see cns documentation for details). The HitCount and UniqHitCount triggers differ only when the player is hitting more than one opponent. In the case where the player is hitting two opponents with the same attack, HitCount will increase by 1 for every hit, while UniqHitCount increases by 2.", 'None')
register_man('updateVolume', 'Updates the BGM volume.', 'None')
register_man('var', 'Returns the value of the int variable at the specified index.', 'None', 'idx (float) - The variable index to check.')
register_man('velX', 'Returns the X velocity of the current active entity.', 'None', 'x (float) - Vel X')
register_man('velY', 'Returns the Y velocity of the current active entity.', 'None', 'y (float) - Vel Y')
register_man('velZ', 'Returns the Z velocity of the current active entity.', 'None', 'z (float) - Vel Z')
register_man('wavePlay', 'Plays a Sound reference.', 's (Sound) - Sound Userdata\ng (int) - Sound group\nn (int) - Sound number')
register_man('win', "Returns true if the player (or the player's team, in team mode) has won the round, false otherwise.", 'None', "true if this entity's team has won, false otherwise")
register_man('winhyper', "Returns true if the player (or the player's team, in team mode) has won the round with the finishing blow being a hyper attack.", "true if this entity's team has won by hyper, false otherwise")
register_man('winko', "Returns true if the player (or the player's team, in team mode) has won the round by KO, false otherwise.", '')
register_man('winnerteam', "Returns true if the player is on the winning team, false otherwise.", 'None')
register_man('winperfect', "Returns true if the player (or the player's team, in team mode) has won the round by Perfect (no lost life), false otherwise.", 'None')
register_man('winspecial', "Returns true if the player (or the player's team, in team mode) has won the round with the finishing blow being a special attack.", 'None')
register_man('wintime', '', '')
register_man('xangle', 'Returns the X angle of the current entity.', 'None', 'xangle (float) - The X angle of the current entity.')
register_man('xshear', "Returns the value of the player's xshear applied with TransformSprite sctrl.", 'None', "xshear (float) - The X shear value of the current player's sprite.")
register_man('yangle', 'Returns the Y angle of the current entity.', 'None', 'yangle (float) - The Y angle of the current entity.')
-- #endregion

local blinkTimer = 0
local drawCursor = false
local consoleOn = false
local consoleRect = nil
local consoleFont = nil
local consoleText = nil
local currCommand = StringBuffer.new()
local currCommandCursorPos = 1
local consoleFontTotalHeight = 0
local lastHistoryItem = 0
local consoleLines = {}
local consoleHistory = {}
local ignoreTime = 0 -- to prevent appending a bunch of characters when the user is just trying to type 1

function toggleConsole()
	resetKey()
    consoleOn = not consoleOn
    -- ON
	if consoleOn then
		local debugFontScale = gameOption("debug.fontScale")

		-- Get the console font now
		if consoleFont == nil then
			consoleFont = fontNew(gameOption("debug.font"), -1)
			-- Now get the info from the .def for the total height
			local consoleFontDef = fontGetDef(consoleFont)
			consoleFontTotalHeight = main.f_round(consoleFontDef.Size[2] + consoleFontDef.Spacing[2])
		end

        -- Create the overlay
		if consoleRect == nil then
			local x1 = 8
			local y1 = 10
			local height = consoleFontTotalHeight * debugFontScale * lconsole.NUM_CONSOLE_ROWS
			local width = gameOption('video.GameWidth')
            consoleRect = rect:create({
					x1 = x1,
					y1 = y1,
					x2 = width - x1*2,
					y2 = height + y1 * debugFontScale,
					r = 32,
					g = 32,
					b = 32,
					src = 256,
					dst = 85,
					defsc = false
				}
			)
        end
		if consoleText == nil then
			-- Create the console text object
			consoleText = textImgNew()
			textImgSetFont(consoleText, consoleFont)
			textImgSetBank(consoleText, 0)
			textImgSetScale(consoleText, debugFontScale, debugFontScale)
			-- Create the console text object for all rows
			for i=1,lconsole.NUM_CONSOLE_ROWS-1 do
				local consoleLineTextImg = textImgNew()
				textImgSetFont(consoleLineTextImg, consoleFont)
				textImgSetBank(consoleLineTextImg, 0)
				textImgSetPos(consoleLineTextImg, consoleRect.x1 + 4, consoleRect.y1 + i*(consoleFontTotalHeight * debugFontScale))
				textImgSetScale(consoleLineTextImg, debugFontScale, debugFontScale)
				textImgSetWindow(consoleLineTextImg, consoleRect.x1, consoleRect.y1, consoleRect.x2, consoleRect.y2 - (consoleFontTotalHeight * debugFontScale))
				local consoleEntry = {text = '', textImgObj = consoleLineTextImg}
				table.insert(consoleLines, consoleEntry)
			end
		end
		hook.add("main.menu.loop", "lconsole", lconsole.loop)
		hook.add("menu.menu.loop", "lconsole", lconsole.loop)
        hook.add("loop", "lconsole", lconsole.loop)
    -- OFF
	else
		-- Disable ctrl for all players
		for i=1,numplayer() do
			if player(i) and map('_iksys_debug_disable_ctrl') > 0 then
				mapSet('_iksys_debug_disable_ctrl', 0, 'set')
			end
		end
		hook.stop("main.menu.loop", "lconsole")
		hook.stop("menu.menu.loop", "lconsole")
        hook.stop("loop", "lconsole")
	end
end

---Returns information about the given command
---@param name string The exact name, case-sensitive, of the function whose info should be returned.
function man(name)
	local foundObj = man_table[name]
	if foundObj then
		local output = ('description:\n%s\n\nargs:\n%s'):format(foundObj.description, foundObj.args)
		-- If there's a return value, just append it
		if foundObj.ret then
			output = output .. ('\n\nreturn: %s'):format(foundObj.ret)
		end
		lconsole.printString(output)
	else
		lconsole.printString(('No manual information found for %s'):format(name))
	end
end

---Performs a case-insensitive search (ASCII only) of available method names.
---@param text string The partial or complete text to search for.
function findLuaMethod(text)
	local foundMethods = {}
	local textLower = text:lower()
	for k,_ in pairs(man_table) do
		if k:lower():find(textLower) then
			table.insert(foundMethods, k)
		end
	end

	if ('findluamethod'):match(textLower) then
		table.insert(foundMethods, 'findLuaMethod')
	end

	if ('man'):match(textLower) then
		table.insert(foundMethods, 'man')
	end

	if ('register_man'):match(textLower) then
		table.insert(foundMethodName, 'register_man')
	end

	if #foundMethods > 0 then
		local foundMethodsStr = table.concat(foundMethods, ', ')
		local sigStr = ('Method signatures matching provided text: %s'):format(foundMethodsStr)
		lconsole.printString(sigStr)
	else
		lconsole.printString(('No method signatures found matching provided text: %s'):format(text))
	end
end

---Prints the given string to the regular I.K.E.M.E.N console, taking care of any word wrapping and
---newlines
---@param str string The string to print in the console.
function printToConsoleFormatted(str)
	-- Split by newline
	local substrings = {}
	local debugFontScale = gameOption('debug.fontScale')
	for line in str:gmatch('([^\n]*)\n?') do
		table.insert(substrings, line)
	end

	-- Print each substring
	for i, substring in ipairs(substrings) do
		if substring == "" and i < #substrings then
			printConsole(' ')
		else
			-- Split the line into segments with word wrapping
			local words = {}
			for word in substring:gmatch('%S+') do
				table.insert(words, word)
			end
			local lineBuffer = StringBuffer.new()
			for _, word in ipairs(words) do
				local strToFit = lineBuffer:toString() .. ' ' .. word
				if (fontGetTextWidth(consoleFont, strToFit, 0) * debugFontScale) <= screenwidth() then
					-- Looks good, add the word to the line buffer
					lineBuffer:append(word .. ' ')
				else
					-- Dump current buffer
					printConsole(lineBuffer:toString())

					-- Create a new line buffer
					lineBuffer = StringBuffer.new()
					lineBuffer:append(word .. ' ')
				end
			end
			-- Print any remaining content in the line buffer
			if lineBuffer.length > 0 then
				printConsole(lineBuffer:toString())
			end
		end
	end
end

--Pastes text into the interactive Lua console.
function lconsole.pasteText(str)
	if currCommand ~= nil and str ~= nil then
		currCommand:append(str)
		currCommandCursorPos = currCommandCursorPos + #str
	end
end

---Prints the given object to the interactive Lua console,
---handling any newlines (\n) and word wrapping
function lconsole.print(obj)
	local str = tostring(obj)
	lconsole.printString(str)
end

---Prints the given string to the interactive Lua console,
---handling any newlines (\n) and word wrapping
---@param str string The string to print.
function lconsole.printString(str)
	-- Split by newline
	local substrings = {}
	for line in str:gmatch('([^\n]*)\n?') do
		table.insert(substrings, line)
	end
	local debugFontScale = gameOption('debug.fontScale')

	-- Print each substring
	for i, substring in ipairs(substrings) do
		if substring == "" and i < #substrings then
			for i=1,#consoleLines-1 do
				consoleLines[i].text = consoleLines[i+1].text
			end
			consoleLines[#consoleLines].text = ''
			print(' ')
		else
			-- Split the line into segments with word wrapping
			local words = {}
			for word in substring:gmatch('%S+') do
				table.insert(words, word)
			end
			local lineBuffer = StringBuffer.new()
			for _, word in ipairs(words) do
				if (fontGetTextWidth(consoleFont, lineBuffer:toString() .. word, 0) * debugFontScale) <= (consoleRect.x2 - consoleRect.x1) then
					-- Looks good, add the word to the line buffer
					lineBuffer:append(word .. ' ')
				else
					local lineBufStr = lineBuffer:toString()
					for i=1,#consoleLines-1 do
						consoleLines[i].text = consoleLines[i+1].text
					end
					consoleLines[#consoleLines].text = lineBufStr
					print(lineBufStr)

					-- Create a new line buffer
					lineBuffer = StringBuffer.new()
					lineBuffer:append(word .. ' ')
				end
			end
			-- Print any remaining content in the line buffer
			if lineBuffer.length > 0 then
				local lineBufStr = lineBuffer:toString()
				for i=1,#consoleLines-1 do
					consoleLines[i].text = consoleLines[i+1].text
				end
				consoleLines[#consoleLines].text = lineBufStr
				print(lineBufStr)
			end
		end
	end

	-- Set the text
	for _, consoleTextLine in ipairs(consoleLines) do
		-- print(consoleTextLine.text)
		textImgSetText(consoleTextLine.textImgObj, consoleTextLine.text)
	end
end

function lconsole.loop()
	local debugFontScale = gameOption('debug.fontScale')
	if consoleOn then
		if consoleRect ~= nil then consoleRect:draw() end
		if consoleText ~= nil then textImgDraw(consoleText) end
		if consoleHistory and #consoleHistory > 0 then
			for _, lineText in ipairs(consoleLines) do
				textImgDraw(lineText.textImgObj)
			end
		end

		if roundstate() > 1 then
			-- Disable ctrl for all players
			for i=1,numplayer() do
				if player(i) and map('_iksys_debug_disable_ctrl') == 0 then
					mapSet('_iksys_debug_disable_ctrl', 1, 'set')
				end
			end
			didDisableCtrl = true
		end
		if debugmode("roundreset") then
			for i=1,numplayer() do
				if player(i) then
					mapSet('_iksys_debug_disable_ctrl', 0, 'set')
				end
			end
			didDisableCtrl = false
		end

		-- Only while input accepted
		if ignoreTime == 0 then
			local lastKey = getKey()
			-- resetKey()
			if lastKey and lastKey ~= '' then
				-- Remove last char
				if lastKey == "BACKSPACE" then
					if currCommandCursorPos > 1 then
						local prevIdx = math.max(1,currCommandCursorPos-1)
						currCommand:remove(prevIdx)
						currCommandCursorPos = prevIdx
					end
				elseif lastKey == "DELETE" then
					if currCommandCursorPos >= 1 and currCommandCursorPos <= currCommand.length then
						currCommand:remove(currCommandCursorPos)
					end
				elseif lastKey == "RETURN" then
					-- easter egg
					if string.match(currCommand:lower(), "it(\'?)s%s+a%s+beautiful%s+day%s+in%s+the%s+neighbo(u?)rhood") then
						lconsole.printString("Won't you be my neighbor?")
					-- regular command
					else
						local cmdStr = currCommand:toString()
						local f, err = loadstring(cmdStr)

						if f then
							-- Add to history
							table.insert(consoleHistory, cmdStr)
							lconsole.printString(cmdStr)

							setfenv(f, _G)
							local success, res = pcall(f)

							-- Tell the user about the error
							if not success then
								lconsole.printString("Error executing statement: " .. cmdStr)
								lconsole.printString(res)
							end
						else
							lconsole.printString("Syntax error: " .. err)
						end
					end

					-- Clear command and reset history cursor position
					currCommand = StringBuffer.new()
					currCommandCursorPos = 1
					lastHistoryItem = #consoleHistory+1
				elseif lastKey == "LEFT" then
					currCommandCursorPos = math.max(1, currCommandCursorPos-1)
				elseif lastKey == "RIGHT" then
					currCommandCursorPos = math.min(currCommand.length+1, currCommandCursorPos+1)
				elseif lastKey == "UP" then
					if #currCommand > 0 then
						consoleHistory:insert(currCommand:toString())
					end
					currCommand = StringBuffer.new()
					lastHistoryItem = math.max(1, lastHistoryItem-1)
					if lastHistoryItem > 0 and lastHistoryItem <= #consoleHistory then
						currCommand:append(consoleHistory[lastHistoryItem])
					end
					currCommandCursorPos = currCommand.length+1
				elseif lastKey == "DOWN" then
					currCommand = StringBuffer.new()
					lastHistoryItem = math.min(#consoleHistory+1, lastHistoryItem+1)
					if lastHistoryItem > 0 and lastHistoryItem <= #consoleHistory then
						currCommand:append(consoleHistory[lastHistoryItem])
					end
					currCommandCursorPos = currCommand.length+1
				else
					local keyText = getKeyText()
					if keyText and #keyText > 0 then
						keyText = string.sub(keyText, 1, 1)
						currCommand:insert(keyText, math.min(currCommandCursorPos, currCommand.length+1))
						currCommandCursorPos = currCommandCursorPos + #keyText
					end
					resetKey()
				end
				-- Prevent junk from getting in the buffer
				ignoreTime = lconsole.TOTAL_IGNORE_TIME
			end
		else
			ignoreTime = ignoreTime - 1
		end

		-- Set the current command text
		if blinkTimer == 0 then
			local newBuffer = StringBuffer.new()
			local consoleWidth = lconsole.NUM_CONSOLE_COLS - #(lconsole.CONSOLE_PREFIX)
			local truncatedTxtStart = math.max(1, currCommandCursorPos - consoleWidth + 1)
			local truncatedTxtEnd = math.min(currCommand.length, truncatedTxtStart + consoleWidth - 1)
			if currCommand.length > 0 then
				if currCommand.length > consoleWidth then
					newBuffer = currCommand:sub(truncatedTxtStart, truncatedTxtEnd)
				else
					newBuffer:insert(currCommand:toString():sub(1, lconsole.NUM_CONSOLE_COLS-#(lconsole.CONSOLE_PREFIX)))
				end
			end
			newBuffer:insert(lconsole.CONSOLE_PREFIX, 1)

			-- Draws cursor character
			if drawCursor then
				if currCommandCursorPos <= consoleWidth then
					if currCommandCursorPos > currCommand.length+1 then
						newBuffer:append(lconsole.CURSOR_CHAR)
					else
						newBuffer[#(lconsole.CONSOLE_PREFIX) + currCommandCursorPos] = lconsole.CURSOR_CHAR
					end
				else
					local truncatedCursorPosition = #(lconsole.CONSOLE_PREFIX) + currCommandCursorPos - truncatedTxtStart + 1
					newBuffer[truncatedCursorPosition] = lconsole.CURSOR_CHAR
				end
			end
			local txt = newBuffer:toString()

			blinkTimer = lconsole.CURSOR_BLINK_RATE

			textImgSetText(consoleText, txt)
			textImgSetPos(consoleText, consoleRect.x1 + 4, consoleRect.y2 + consoleFontTotalHeight * debugFontScale / 2.0)
			drawCursor = not drawCursor
		else
			blinkTimer = blinkTimer - 1
		end
	else
		if didDisableCtrl then
			-- Disable ctrl for all players
			for i=1,numplayer() do
				if player(i) then
					mapSet('_iksys_debug_disable_ctrl', 0, 'set')
				end
			end
			didDisableCtrl = false
		end
	end
end