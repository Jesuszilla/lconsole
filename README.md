# LConsole for I.K.E.M.E.N-Go
Whether you miss the MConsole from MUGEN 1.1 or you just want to find out what Lua methods are available
to I.K.E.M.E.N-Go, this module is for you!

## Features:
* Clipboard pasting (Ctrl+V)
* Execute arbitrary Lua commands
* Uses config.ini debug font setting (change your debug font to change the font in the LConsole terminal)
* Dual output - prints to the interactive console as well as the terminal.

## Basic Usage
The main Lua methods users may find useful are the `findEntityById`, `findEntityByName`, `man`, and `register_man` commands.

Remember, when in doubt: use `man`.

### findEntityById(id)
`findEntityById` finds an entity by their internal ID as assigned by the engine. The debug context will switch to the
entity if its ID is found.

### findEntityByName(str)
Like `findEntityById`, except this does it with a case-insensitive circular search on the entity's `name` property (as
defined in the .DEF).

### man(function_name)
The bulk of functionality of this console besides the ability to execute arbitrary Lua commands. The `man` is similar to
the [man page](https://en.wikipedia.org/wiki/Man_page) in UNIX/Unix-like operating systems including Linux in that it
provides instructions on the built-in Lua functions. These are registered with the `register_man` command in
`external/mods/lconsole.lua`.


### register_man(commandName, description, args, ret)
Registers a Lua function with the LConsole `man` command. You can provide `man` implementations with your own modules
by doing something similar to the following (provided LConsole is loaded first):

```lua
-- Bool to check if lconsole defined register_man. Do this outside your loop. 
local didInitializeManEntries = false

-- ...

-- In your hook's loop somewhere.
if not didInitializeManEntries and register_man ~= nil then
  register_man('myAdd', 'Adds two numbers and returns the result.', 'a (number) - The first number to add.\nb (number) - The second number to add.', 'ret (number) - The value of a+b')
  didInitializeManEntries = true
end
```