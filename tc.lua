--- Turret Control
-- Helps manage OpenModularTurrets turret blocks that have serial IO
-- @Author: Brodur
-- @Version: 3.1
-- @Requires:
-- serialutils.lua, menu.lua

local term = require("term")
local component = require("component")
local event = require("event")
local menu = require("menu")
local fs = require("filesystem")
local sz = require("serialutils")

local m = {}
local tb = "turret_base"

local mmopts = {
  "Summary",
  "Targeting",
  "User Admin",
  "Push Config",
  "Exit"
}

local privs = {
  [1] = false, 
  [2] = true, 
  admin = true, 
  trusted = false 
}

local db = {}
local toRemove = {}
local dbdir = "/home/settings.lua"

--- Trims strings
-- Gets rid of trailing white space or special characters.
-- @param s The string to trim.
-- @return The trimmed string.
function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--- To String
-- Convert the saved config into a string
-- @returns The pretty string of the config.
function toString()
  local lb = "-------------------------------\n"
  str = "Trusted players:\n"
  str = str .. lb --Line break
  for user,priv in pairs(db.users) do
    str = str .. " - " .. user .. "\t" .. tostring(priv and "[Admin]" or "[Trusted]") .. "\n"
  end

  str = str .. "\nAttacks:\n"
  str = str .. lb --Line break
  str = str .. "Mobs:\t\t" .. tostring(db.targets.setAttacksMobs) .. "\n"
  str = str .. "Neutrals:\t" .. tostring(db.targets.setAttacksNeutrals) .. "\n"
  str = str .. "Players:\t" .. tostring(db.targets.setAttacksPlayers ) .. "\n"
  return str
end 
--- Summary output
-- Outputs the summary of a selected turret.
function m.summary()
  term.setCursor(1,1)
  print(mmopts[1] .. "\n")
  print(toString())
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
function m.targetMenu()
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
-- @param priv	 	True for Admin, False for Trusted.
function m.addTrustedPlayer(player, priv)
  if db.users[player] ~= nil then error("Cannot add a user that already exists!") end
  db.users[player] = priv
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
-- Launches the add or remove user dialog.
function m.usersMenu()
  local options = {"Add a trusted user", "Remove a trusted user","Exit"}
  local opt = -1
  while opt ~= #options do
    opt = menu.list(options, mmopts[3])
    if opt == 1 then 
      usersMenuAdd()
    end
    if opt == 2 then
      usersMenuRemove()
    end
  end
end

--- Users Menu Add
-- Add user menu with confirm and privilege.
function usersMenuAdd()
  local userTypes = {"Trusted", "Admin"}
  term.write("Add a trusted player: ")
  local player  = trim(term.read())
  local usrType = menu.dialog("Trusted or Admin?", "Trusted", "Admin")
  local confirm = menu.dialog("Add \'" .. player .. "\' as " .. userTypes[usrType] .." type user?", "Confirm", "Cancel")
  if confirm == 1 then
    m.addTrustedPlayer(player, privs[usrType])
  end
end

--- Users Menu Remove
-- Remove users menu list.
function usersMenuRemove()
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

--- Distribute Config
-- Disseminates the settings from the database to all turrets.
function m.distribConfig()
  updateTurrets()
  for _,uuid in ipairs(db.turrets) do

    for _,player in ipairs(toRemove) do 
      component.invoke(uuid, "removeTrustedPlayer", player)
    end

  	for user,priv in pairs(db.users) do
      component.invoke(uuid, "addTrustedPlayer", user, priv)
    end
    
    for meth,isTarget in pairs(db.targets) do
      component.invoke(uuid, meth, isTarget)
    end
  end
  toRemove= {}
end

--- Get Turrets
-- Get the connected turret components.
function updateTurrets()
  db.turrets= {}
  for turret in pairs(component.list(tb)) do 
    db.turrets[#db.turrets+1] = turret
    db.hasChanges = true;
  end
end


function save()
  sz.save(db, dbdir)
  db.hasChanges = false
end

--- Sub menu
-- Determines which menu function to call.
-- @param index The selected index in the main menu options table.
function m.subMenu(index)
  if index == mmopts[1] then m.summary() end
  if index == mmopts[2] then m.targetMenu() end
  if index == mmopts[3] then m.usersMenu() end
  if index == mmopts[4] then m.distribConfig() end
end     

--- On Load
-- Initializes the database and grabs the initial turrets.
function m.onLoad()
  if not fs.exists(dbdir) then 
    db = {
      hasChanges=false,
      targets = {
        setAttacksMobs=false,
        setAttacksNeutrals=false,
        setAttacksPlayers=false
      },
      turrets = {},
      users = {}
	  }
    save()
  end
					
  db = sz.load(dbdir)
  updateTurrets()

  event.listen("component_added", onComponentAdded)     --Wire up turret added.
  event.listen("component_removed", onComponentRemoved) --Wire up turret removed.

  m.main()
end

--- Main
-- Launches the main logic and displays the top level menu.
function m.main()
  local mmoptTitle = "Main Menu"
  local mmopt = -1 

  while mmopt ~= #mmopts do
    if db.hasChanges then
      m.distribConfig()
      save()
    end
    if mmopt ~= #mmopts then
      mmopt = menu.list(mmopts, mmoptTitle)
      m.subMenu(mmopts[mmopt])
    end
  end
  save() -- ensure save on exit
end

--- On Component Added
-- Push the stored config when a new turret is detected.
-- @param _	The type of event, passed by event listener.
-- @param address	The hardware address of the new component.
-- @param componentType 	The type of the new component.
-- @todo figure out why the event listener is not firing all of the time, until that is figured disregard this function
function onComponentAdded(_, address, componentType)
  if componentType == "turret_base" then
    m.distribConfig()
  end
end

--- On Component Removed
-- Remove turrets from the database is they are removed physically.
-- @param _	The type of event, passed by event listener.
-- @param address	The hardware address of the  component.
-- @param componentType 	The type of the  component.
function onComponentRemoved(_, address, componentType)
  if componentType == "turret_base" then
    db.turrets[address] = nil
  end
end

m.onLoad()
return m
