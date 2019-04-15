--- Turret Control
-- Helps manage OpenModularTurrets turret blocks that have serial IO
-- @Author: Brodur
-- @Version: 2.3
-- @Requires:
-- https://pastebin.com/WvF00A71 : JSON Utility functions
-- https://pastebin.com/pLpe4zPb : Menu functions
-- https://pastebin.com/SKwM2UZH : Lua JSON Library

local term = require("term")
local component = require("component")
local event = require("event")
local json = require("json")
local menu = require("menu")
local jsonutil = require("jsonutil")
local fs = require("filesystem")

local m = {}
local tb = "turret_base"
local lb = "-------------------------------"

local mmopts = {
  "Summary",
  "Targeting",
  "User Admin",
  "Push Config",
  "Exit"
}

local db = {}
local toRemove = {}
local jsondir = "/home/settings.json"

--- Trims strings
-- Gets rid of trailing white space or special characters.
-- @param s The string to trim.
-- @return The trimmed string.
function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--- Summary output
-- Outputs the summary of a selected turret.
function m.summary()
  term.setCursor(1,1)
  print(mmopts[1] .. "\n")
  print("Trusted players")
  print(lb)

  for k,v in pairs(db.users) do
    print(" - " .. k, v and "[Admin]" or "[Trusted]")
  end
  print("\nAttacks")
  print(lb)
  print("Mobs:\t\t" .. tostring(db.targets.setAttacksMobs))
  print("Neutrals:\t" .. tostring(db.targets.setAttacksNeutrals))
  print("Players:\t" .. tostring(db.targets.setAttacksPlayers))

  print("\n\nPress enter to continue...")
  term.read()
end

--- Set Attack
-- Sets the attack setting for all turrets.
-- @param flag   	1 or 2, corresponds to true or false, toggles the attack mode.
-- @param option	Which option was chosen in the target function
function m.setAttack(flag, option)
local methods = {"setAttacksMobs", "setAttacksNeutrals", "setAttacksPlayers"}
  local arguments = {true, false}
  db.targets[methods[option]] = arguments[flag]
  db.hasChanges = true
end

---Target
-- Selects the targeting parameter
function m.target()
  local options = {"Attack Mobs", "Attack Neutrals", "Attack Players", "Exit"}
  local opt = -1
  while opt ~= #options do  
    opt = menu.list(options, mmopts[2])
    if opt ~= #options then 
      local flag = menu.dialog(options[opt], "True", "False")
      m.setAttack(flag, opt)
    else break end
  end
end

--- Add Trusted Player
-- Adds a trusted player to all turrets, either with or without admin privileges.
-- @param player	The player to add.
-- @param usrType	1 for trusted, 2 for admin.
function m.addTrustedPlayer(player, usrType)
  local args = {false, true}
  for k,_ in pairs(db.users) do
    if player == k then error("Cannot add a user that already exists!") end
  end
  db.users[player] = args[usrType] 
  db.hasChanges = true
end

--- Remove Trusted Player
-- Removes a user from the trusted players list.
-- @param player  The user to remove.
function m.removeTrustedPlayer(player)
  toRemove[#toRemove+1] = player
  db.users[player] = nil
  db.hasChanges = true
end

--- Users
-- Launches the add or remove user dialog
function m.users()
  local options = {"Add a trusted user", "Remove a trused user","Exit"}
  local opt = -1
  while opt ~= #options do
    opt = menu.list(options, mmopts[3])
    if opt == 1 then 
      local userTypes = {"Trusted", "Admin"}
      term.write("Add a trusted player: ")
      local player  = trim(term.read())
      local usrType = menu.dialog("User or Admin?", "User", "Admin")
      local opt = menu.dialog("Add \'" .. player .. "\' as " .. userTypes[usrType] .." type user?", "Confirm", "Cancel")
      if opt == 1 then
        m.addTrustedPlayer(player, usrType)
      end
    end
    if opt == 2 then
      local users = {"Cancel"}
      for k,v in pairs(db.users) do users[#users+1] = k end
      local user = -1
      while user ~= 1 do
        user = menu.list(users, "Select a user")
        if user ~= 1 then
          local player = users[user]
          local confirm = menu.dialog("Remove \'" .. player .. "\' from trusted users?", "Confirm", "Cancel")
          if confirm == 1 then 
            m.removeTrustedPlayer(player)
            table.remove(users, user)
          end
        end
      end
    end
  end
end

--- Distribute Json
-- Disseminates the settings from the database to all turrets.
function m.distribJson()
  for _,v in pairs(db.turrets) do
    for _,player in pairs(toRemove) do
      component.invoke(v, "removeTrustedPlayer", player)
    end

  	for user,priv in pairs(db.users) do
      component.invoke(v, "addTrustedPlayer", user, priv)
  	end
    for meth,bool in pairs(db.targets) do
      component.invoke(v, meth, bool)
    end
  end
  toRemove= {}
end

--- Sub menu
-- Determines which menu function to call.
-- @param index The selected index in the main menu options table.
function m.subMenu(index)
  local turrets = {}
  for k in pairs(component.list(tb)) do turrets[#turrets+1] = k end 
  db.turrets = turrets

  if index == mmopts[1] then m.summary() end
  if index == mmopts[2] then m.target() end
  if index == mmopts[3] then m.users() end
  if index == mmopts[4] then m.distribJson() end
end     

--- On Load
-- Initializes the database and grabs the initial turrets.
function m.onLoad()
  if not fs.exists(jsondir) then 
    db = {
		hasChanges=false,
		targets={setAttacksMobs=false,
				 setAttacksNeutrals=false,
				 setAttacksPlayers=false
				},
		turrets = {},
		users = {}
	}
	jsonutil.save(db, jsondir)
  end
					
  db = jsonutil.load(jsondir)
  for k in pairs(component.list(tb)) do db.turrets[#db.turrets+1] = k end
  m.main()
end

--- Main
-- Launches the main logic and displays the top level menu.
function m.main()
  local mmoptTitle = "Main Menu"
  local mmopt = -1 

  while mmopt ~= #mmopts do
    if db.hasChanges then
      jsonutil.save(db, jsondir)
      db.hasChanges = false
      m.distribJson()
    end
    if mmopt ~= #mmopts then
      mmopt = menu.list(mmopts, mmoptTitle)
      m.subMenu(mmopts[mmopt])
    end
  end
end

--- On Component Added
-- Push the stored config when a new turret is detected.
-- @param eventType	The type of event, passed by event listener.
-- @param address	The hardware address of the new component.
-- @param componentType 	The type of the new component.
-- @todo figure out why the event listener is not firing all of the time, until that is figured disregard this function
-- function onComponentAdded(eventType, address, componentType)
--   if componentType == "turret_base" then
--     distribJson()
--   end
-- end

-- event.listen("component_added", onComponentAdded)
m.onLoad()
return m