--- Menu
-- Provides various CLI menus
-- @Author: Brodur
-- @Version: 1.0
local term = require("term")
local event = require("event")
local menus = {}

function menus.list(m, header)
  local header = header or "Menu List"
  local n=1
  
  while(true) do
    term.clear()
    term.setCursor(1,1)
    term.write(header)
    term.setCursor(1,2)

    for i=1, #m, 1 do
      if(i==n) then
        term.write(" [" .. m[i] .. "]\n")
      else 
        term.write("  " ..  m[i] .. "\n")
      end
    end
  
    local _,_,_,key = event.pull("key_down")  
  
    if(key==200 and n>1) then --go up
      n = n-1
    end
    if(key==208 and n<#m) then --go down
      n = n+1
    end
    if(key==28) then --exit
      break
    end
  end
  
  term.clear()
  term.setCursor(1,1)
  return n
end

function menus.dialog(prompt, lOpt, rOpt)
  local prompt = prompt or "Continue"
  local lOpt = lOpt or "YES"
  local rOpt = rOpt or "NO"
  local n = 1

  term.write(prompt.."\n")

  while true do
    local x, y =term.getCursor()
    term.clearLine()    
    
    if n==1 then
      term.setCursor(x, y)
      term.clearLine()
      term.write ("["..lOpt.."]   "..rOpt)
    else
      term.setCursor(x, y)
      term.clearLine()
      term.write(" "..lOpt.."   ["..rOpt.."]")
    end
  
    term.setCursor(x, y)   
    local _,_,_,key = event.pull("key_down")  
  
    if key==203 then n=1 end
    if key==205 then n=2 end
    if key==28  then break end
  end
  term.write("\n") 
  return n
end

return menus