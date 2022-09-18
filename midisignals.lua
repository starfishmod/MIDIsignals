-- midisignals v0.1
-- Advanced MIDI router
--    for NORNS
--
-- https://
--
-- Merge, Filter, map and more
-- your MIDI Devices connected
-- to your norns.
--
--
-- Based of MiPeX Signals
-- inspiration (code ideas) from :
-- * passthrough
-- * ORCA
--
-- Note: Norns has some issues with
-- MIDI Devices that have only one 
-- direction https://github.com/monome/norns/issues/1449

local json = include("midisignals/lib/JSON")
local mod = require "core/mods"
local filepath = _path.data.."midisignals/setup.json"

local bounds_x, bounds_y = 25, 5
local x_index, y_index, field_offset_x, field_offset_y = 3, 3, 0, 0
local currentPosX, currentPosY = 1,1
local mode = 0 -- move=0 edit=1

local processLoops = 0

local patchTable = {}
local clockTable = {}
local clockManager = nil
local midiInTable = {}
local router = {}
local MDEV_LIST = {}
local OPS_LIST = {".","-","|","+","M","V","P","C","f","1","c","n","t"}


local ops = {
 ["."] = {
    title = "E1 - Change Action",
    doRight = false,
    doDown = false,
    editExit=false
  },

 ["-"] =  {
    title = "Pass Data to Right",
    doRight = function(from)
        if from == "L" then
         return true
        end
        return false
      end,
    doDown = false,
    editExit=false
  },
  
 ["|"]= {
    title = "Pass Data to Below",
    doRight = false,
    doDown = function(from)
        if from == "T" then
         return true
        end
        return false
      end,
    editExit=false
  },

 ["+"] = {
    title = "Merge Top/Left",
    doRight = true,
    doDown = true,
    editExit=false
  },

  M = {
    title = "MIDI Device",
    doRight = false,
    doDown = false,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count)
      local cell = router[y][x]
      for i = 1,#midi.devices do -- query all ports
          if cell.id == nil or cell.id=="*" or midi.devices[i].name==cell.id and cell.id~=src then
            _norns.midi_send(midi.devices[i].dev, data)
          end
      end
    end,
    
    display = function () 
      local cell = router[currentPosY][currentPosX]
      if cell.id == nil then cell.id="*" end
      screen.move(25, 51)
      screen.text(cell.id == '*' and "-- ALL MIDI Devices --" or cell.id)
        
      if mode==1 then
        screen.text_center_rotate (120, 60, ">", 270)
        screen.text_center_rotate (122, 60, ">", 90)
      end
    end,
    
    enc = function(n,d)
      local cell = router[currentPosY][currentPosX]
      if n == 3 then
        local op_index =  tab.key(MDEV_LIST, cell.id or "*")
        op_index = (((op_index + d) -1) % tab.count(MDEV_LIST)) +1
        
        router[currentPosY][currentPosX].id = MDEV_LIST[op_index]
      end
    end,
    
    cellBuilder = function(x,y)
      local cell = router[y][x]
      if cell.id == nil then 
          return
      end
      if midiInTable[cell.id] == nil then
        midiInTable[cell.id] = {}
      end
      table.insert(midiInTable[cell.id],{x,y});
    end
  }, 
  V = {
    title = "To Virtual MIDI Ports",
    doRight = false,
    doDown = false,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count) 
        for i = 1,#midi.vports do -- query all ports
          if cell.vport == i then
            midi.vports[i].send(data) 
          end
        end
    end,

    display = function () 
      local cell = router[currentPosY][currentPosX]
      if cell.vport == nil then cell.vport=1 end
      screen.move(40, 51)
      screen.text("port:") 
      screen.move(88, 51)
      screen.text(cell.vport)
        
      if mode==1 then
        screen.text_center_rotate (120, 60, ">", 270)
        screen.text_center_rotate (122, 60, ">", 90)
      end
    end,
    
    enc = function(n,d) 
      local cell = router[currentPosY][currentPosX]
      if n == 3 then
        cell.vport = (((cell.vport + d) -1) % 16) +1
      end
    end  
    -- key = function(n,z) end,
    
  },

  P = {
    title = "Internal Patch",
    doRight = true,
    doDown = true,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count)
      if from ~= "P" then 
      
        local vport = router[y][x].vport
        
        if patchTable[vport] ~= nil then
  
          for i=1, #patchTable[vport] do
            local xP = patchTable[vport][i][1]
            local yP = patchTable[vport][i][2]
            
            if(x ~=xP or y ~=yP) then
              print ("patch "..xP.."-"..yP.. "  "..x..":"..y)
              process_cell(xP, yP, "P", data, src, count+1)
            end
          end
        end
      end
      
      return data

    end,
    
    cellBuilder = function(x,y)
      local cell = router[y][x]
       if cell.vport == nil then 
          return
      end
      if patchTable[cell.vport] == nil then
        patchTable[cell.vport] = {}
      end
      table.insert(patchTable[cell.vport],{x,y});
    end,
    
    display = function () 
      local cell = router[currentPosY][currentPosX]
      if cell.vport == nil then cell.vport=1 end
      screen.move(40, 51)
      screen.text("patch:") 
      screen.move(88, 51)
      screen.text(cell.vport)
        
      if mode==1 then
        screen.text_center_rotate (120, 60, ">", 270)
        screen.text_center_rotate (122, 60, ">", 90)
      end
    end,
    enc = function(n,d) 
      local cell = router[currentPosY][currentPosX]
      if n == 3 then
        cell.vport = (((cell.vport + d) -1) % 16) +1
      end
    end  
    
    -- process_cell = function(x, y, from, data) end,
    -- display = function () end,
    -- enc = function(n,d) end  
    -- key = function(n,z) end,
    
  }, 
  C = {
    title = "Norns Clock",
    doRight = false,
    doDown = false,
    editExit=true,
    cellBuilder = function(x,y)
       table.insert(clockTable,{x,y});
    end
    
  }, 
  f = {
    title = "Filter",
    doRight = true,
    doDown = true,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count) 
      local cell = router[y][x]
      local stat = 0xF0 & data[1] 
      --tab.print(data)
      
     -- print(from.." "..x..":"..y.."--"..stat.."="..data[1] )
      
      --tab.print(cell)
      
      if stat == 0x80 and cell.filterNote then return nil end
      if stat == 0x90 and cell.filterNote then return nil end
      if stat == 0xB0 and cell.filterCC then return nil end
      if stat == 0xC0 and cell.filterProgChange then return nil end
      if stat == 0xA0 and cell.filterPolyPress then return nil end
      if stat == 0xD0 and cell.filterChPres then return nil end
      if stat == 0xE0 and cell.filterPitch then return nil end
     -- print('a')
      
      return data
    end,
    display = function () 
      local cell = router[currentPosY][currentPosX]
      
      if cell.editPos == nil then cell.editPos=0 end
      
      --screen.level(0)
      screen.stroke()
      --screen.level(8)
      
      screen.circle(7, 55, 3)
      if cell.filterNote then screen.fill() else screen.stroke() end
      
      screen.circle(27, 55, 3)
      if cell.filterCC then screen.fill() else screen.stroke() end
      
      screen.circle(47, 55, 3)
      if cell.filterPitch then screen.fill() else screen.stroke() end
      
      screen.circle(67, 55, 3)
      if cell.filterProgChange then screen.fill() else screen.stroke() end
      
      screen.circle(90, 55, 3)
      if cell.filterChPres then screen.fill() else screen.stroke() end
      
      screen.circle(115, 55, 3)
      if cell.filterPolyPress then screen.fill() else screen.stroke() end
      
      screen.move(0, 51)
      screen.text("note cc's ptch prog chPrs plyPrs") 
      screen.level(8)
      
  --screen.fill()
      -- screen.text(cell.vport)
        
      if mode==1 then
        if cell.editPos == 0 then screen.move(0,46) screen.line(15,46) screen.stroke() end
        if cell.editPos == 1 then screen.move(20,46) screen.line(35,46) screen.stroke() end
        if cell.editPos == 2 then screen.move(40,46) screen.line(55,46) screen.stroke() end
        if cell.editPos == 3 then screen.move(60,46) screen.line(75,46) screen.stroke() end
        if cell.editPos == 4 then screen.move(80,46) screen.line(99,46) screen.stroke() end
        if cell.editPos == 5 then screen.move(104,46) screen.line(127,46) screen.stroke() end
        
        screen.move(25, 64)
        screen.text("en/dis")
        
        screen.move(84, 64)
        screen.text("< >")
      end
      
    end,
    enc = function(n,d) 
      local cell = router[currentPosY][currentPosX]
      if n == 2 then
        cell.editPos = (cell.editPos + d)  % 6
      end
    end, 
    key = function(n,z) 
      local cell = router[currentPosY][currentPosX]
      
      if n==3 and z ==0 then
        if cell.editPos == 0 then cell.filterNote = not cell.filterNote  end
        if cell.editPos == 1 then cell.filterCC = not cell.filterCC  end
        if cell.editPos == 2 then cell.filterPitch = not cell.filterPitch end
        if cell.editPos == 3 then cell.filterProgChange = not cell.filterProgChange end
        if cell.editPos == 4 then cell.filterChPres = not cell.filterChPres end
        if cell.editPos == 5 then cell.filterPolyPress = not cell.filterPolyPress end
      end
      
    end,
    
  }, 
  ["1"] = {
    title = "Channnel Filter",
    doRight = true,
    doDown = true,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count) 
      local cell = router[y][x]
      local stat = 0xF0 & data[1] 
      local ch = 0xF & data[1] 
      --tab.print(data)
      
     -- print(from.." "..x..":"..y.."--"..stat.."="..data[1] )
      
      --tab.print(cell)
      
      if stat >= 0x80 and stat <= 0xE0 then
        if cell.chLower > ch or cell.chUpper < ch then return nil end
        if cell.forceChannel then
          data[1] = stat + (cell.toChannel)
        end
      end
      
     -- print('a')
      
      return data
    end,
    display = function () 
      local cell = router[currentPosY][currentPosX]
      
      if cell.editPos == nil then cell.editPos=0 end
      if cell.chLower == nil then cell.chLower=0 end
      if cell.chUpper == nil then cell.chUpper=15 end
      if cell.toChannel == nil then cell.toChannel=0 end
      
      
      screen.move(0, 51)
      screen.text("lower upper forceCh toCh")
      
      screen.move(5, 57)
      screen.text(cell.chLower+1)
      screen.move(30, 57)
      screen.text(cell.chUpper+1)
      screen.move(50, 57)
      
      screen.stroke()
      screen.circle(62, 55, 3)
      if cell.forceChannel then screen.fill() else screen.stroke() end
        
      screen.text(cell.chUpper+1)
      screen.move(85, 57)
        
      screen.text(cell.toChannel+1)
      screen.level(8)
      
 
        
      if mode==1 then
        if cell.editPos == 0 then screen.move(0,46) screen.line(19,46) screen.stroke() end
        if cell.editPos == 1 then screen.move(24,46) screen.line(43,46) screen.stroke() end
        if cell.editPos == 2 then screen.move(48,46) screen.line(75,46) screen.stroke() end
        if cell.editPos == 3 then screen.move(80,46) screen.line(95,46) screen.stroke() end
        
        screen.move(84, 64)
        screen.text("< >")
        if cell.editPos ~= 2 then
          screen.text_center_rotate (120, 60, ">", 270)
          screen.text_center_rotate (122, 60, ">", 90)
        else
          screen.move(25, 64)
          screen.text("en/dis")
        end
      end
      
    end,
    enc = function(n,d) 
      local cell = router[currentPosY][currentPosX]
      if n == 2 then
        cell.editPos = (cell.editPos + d)  % 4
      end
      
      if n == 3 then
        if cell.editPos == 0 then cell.chLower = (cell.chLower + d)  % 16 end
        if cell.editPos == 1 then cell.chUpper = (cell.chUpper + d)  % 16 end
        if cell.editPos == 3 then cell.toChannel = (cell.toChannel + d)  % 16 end
      end
      
    end,
    key = function(n,z) 
      local cell = router[currentPosY][currentPosX]
      
      if n==3 and z ==0 then
        if cell.editPos == 2 then cell.forceChannel = not cell.forceChannel end
      end
      
    end,

  }, 
  c = {
    title = "CC Filter",
    doRight = false,
    doDown = false,
    editExit=true,
    
    -- process_cell = function(x, y, from, data) end,
    -- display = function () end,
    -- enc = function(n,d) end  
    -- key = function(n,z) end,
    
  }, 
  n = {
    title = "Note Filter",
    doRight = false,
    doDown = false,
    editExit=true,
    
    -- process_cell = function(x, y, from, data) end,
    -- display = function () end,
    -- enc = function(n,d) end  
    -- key = function(n,z) end,
    
  }, 
  t = {
    title = "Clock Filter",
    doRight = false,
    doDown = false,
    editExit=true,
    
    -- process_cell = function(x, y, from, data) end,
    -- display = function () end,
    -- enc = function(n,d) end  
    -- key = function(n,z) end,
    
  } 
}


-- CORE NORNS OVERRIDES --
if _norns.midi.eventOrig == nil then
  _norns.midi.eventOrig = _norns.midi.event
end


_norns.midi.event = function(id, data)
  _norns.midi.eventOrig(id, data)
  print(midi.devices[id].name .. "-".. data[1] .. " " ..data[2].. " " .. data[3]) 
  -- tab.print(midiInTable)
  
  if midiInTable['*'] ~= nil then
    -- print("   in to ALL")
    for i=1, tab.count(midiInTable['*']) do
      --tab.print(midiInTable['*'][i])
      local x = midiInTable['*'][i][1]
      local y = midiInTable['*'][i][2]
      if x + 1 < bounds_x then
        processLoops = 0
        process_cell(x+1, y, "L", data, id, 0)
      end
      if y + 1 < bounds_y then
        processLoops = 0
        process_cell(x, y+1, "T", data, id, 0)
      end
    end
  end
  
  local name = midi.devices[id].name
  if midiInTable[name] ~= nil then
    -- print("   in to "..name)
    for i=1, tab.count(midiInTable[name]) do
      local x = midiInTable[name][i][1]
      local y = midiInTable[name][i][2]
      if x + 1 < bounds_x then
        processLoops = 0
        process_cell(x+1, y, "L", data, id, 0)
      end
      if y + 1 < bounds_y then
        processLoops = 0
        process_cell(x, y+1, "T", data, id, 0)
      end
    end
  end
end

--


function init()
  
  -- if tab.contains(mod.loaded_mod_names(), "midisignals") then 
  --   print("midisignals already running as mod")
  --   return 
  -- end
  
  -- for key,_ in pairs(ops) do
  --   table.insert(OPS_LIST, key)
  -- end
  
  
  tab.print(OPS_LIST)
  
  
  local f=io.open(filepath,"rb")
  if f==nil then
    print("file not found: "..filepath)
    for y = 0, bounds_y do
      router[y] = {}
      for x = 0, bounds_x do
         router[y][x] = {type="."}
      end
    end
  else
    local json_file_str = f:read "*a"
    f:close()
    router = json.decode(json_file_str)
  end  
  

  
  print("Virtual Ports")
  
  for i = 1,#midi.vports do -- query all ports
    -- midi_device[i] = midi.connect(i) -- connect each device
    print(
      "port "..i..": "..util.trim_string_to_width(midi.vports[i].name,80) -- value to insert
    )
    
  end
  
  
  print("Real Ports")
  table.insert(MDEV_LIST, '*')
  for i = 1,#midi.devices do -- query all ports
    -- midi_device[i] = midi.connect(i) -- connect each device
    
    if midi.devices[i].name~= 'virtual' then
      print(
        "port "..i..": "..util.trim_string_to_width(midi.devices[i].name,80) -- value to insert
      )
      table.insert(MDEV_LIST, midi.devices[i].name)
    end
  end
  
  
   
end

function process_cell(x, y, from, data, src, count)
  local doRight = false
  local doDown = false
  local cell = router[y][x]
  
  if count > 20 then
    print("HIT PROCESS LOOP")
    return
  end
  
  --tab.print(data)
  
  if type(ops[cell.type].doRight) == "function" then
    doRight = ops[cell.type].doRight(from)
  else
    doRight = ops[cell.type].doRight
  end
  
  if type(ops[cell.type].doDown) == "function" then
    doDown = ops[cell.type].doDown(from)
  else
    doDown = ops[cell.type].doDown
  end
  
  if ops[cell.type].process_cell then
    data = ops[cell.type].process_cell(x, y, from, data, src, count+1)
    if data == nil then
      return
    end
  end
  
  if doRight and x + 1 < bounds_x then
      process_cell(x+1, y, "L", data, src, count+1)
  end
  if doDown and y + 1 < bounds_y then
    process_cell(x, y+1, "T", data, src, count+1)
  end

  
end



-- from ORCA
local function draw_op_frame(x, y, b)
  screen.level(b)
  screen.rect((x * 5) - 4, ((y * 7) - 4-- midisignals v0.1
-- Advanced MIDI router
--    for NORNS
--
-- https://
--
-- Merge, Filter, map and more
-- your MIDI Devices connected
-- to your norns.
--
--
-- Based of MiPeX Signals
-- inspiration (code ideas) from :
-- * passthrough
-- * ORCA
--
-- Note: Norns has some issues with
-- MIDI Devices that have only one 
-- direction https://github.com/monome/norns/issues/1449

local json = include("midisignals/lib/JSON")
local mod = require "core/mods"
local filepath = _path.data.."midisignals/setup.json"

local bounds_x, bounds_y = 25, 5
local x_index, y_index, field_offset_x, field_offset_y = 3, 3, 0, 0
local currentPosX, currentPosY = 1,1
local mode = 0 -- move=0 edit=1

local processLoops = 0

local patchTable = {}
local clockTable = {}
local clockManager = nil
local midiInTable = {}
local router = {}
local MDEV_LIST = {}
local OPS_LIST = {".","-","|","+","M","V","P","C","f","1","c","n","t"}


local ops = {
 ["."] = {
    title = "E1 - Change Action",
    doRight = false,
    doDown = false,
    editExit=false
  },

 ["-"] =  {
    title = "Pass Data to Right",
    doRight = function(from)
        if from == "L" then
         return true
        end
        return false
      end,
    doDown = false,
    editExit=false
  },
  
 ["|"]= {
    title = "Pass Data to Below",
    doRight = false,
    doDown = function(from)
        if from == "T" then
         return true
        end
        return false
      end,
    editExit=false
  },

 ["+"] = {
    title = "Merge Top/Left",
    doRight = true,
    doDown = true,
    editExit=false
  },

  M = {
    title = "MIDI Device",
    doRight = false,
    doDown = false,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count)
      local cell = router[y][x]
      for i = 1,#midi.devices do -- query all ports
          if cell.id == nil or cell.id=="*" or midi.devices[i].name==cell.id and cell.id~=src then
            _norns.midi_send(midi.devices[i].dev, data)
          end
      end
    end,
    
    display = function () 
      local cell = router[currentPosY][currentPosX]
      if cell.id == nil then cell.id="*" end
      screen.move(25, 51)
      screen.text(cell.id == '*' and "-- ALL MIDI Devices --" or cell.id)
        
      if mode==1 then
        screen.text_center_rotate (120, 60, ">", 270)
        screen.text_center_rotate (122, 60, ">", 90)
      end
    end,
    
    enc = function(n,d)
      local cell = router[currentPosY][currentPosX]
      if n == 3 then
        local op_index =  tab.key(MDEV_LIST, cell.id or "*")
        op_index = (((op_index + d) -1) % tab.count(MDEV_LIST)) +1
        
        router[currentPosY][currentPosX].id = MDEV_LIST[op_index]
      end
    end,
    
    cellBuilder = function(x,y)
      local cell = router[y][x]
      if cell.id == nil then 
          return
      end
      if midiInTable[cell.id] == nil then
        midiInTable[cell.id] = {}
      end
      table.insert(midiInTable[cell.id],{x,y});
    end
  }, 
  V = {
    title = "To Virtual MIDI Ports",
    doRight = false,
    doDown = false,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count) 
        for i = 1,#midi.vports do -- query all ports
          if cell.vport == i then
            midi.vports[i].send(data) 
          end
        end
    end,

    display = function () 
      local cell = router[currentPosY][currentPosX]
      if cell.vport == nil then cell.vport=1 end
      screen.move(40, 51)
      screen.text("port:") 
      screen.move(88, 51)
      screen.text(cell.vport)
        
      if mode==1 then
        screen.text_center_rotate (120, 60, ">", 270)
        screen.text_center_rotate (122, 60, ">", 90)
      end
    end,
    
    enc = function(n,d) 
      local cell = router[currentPosY][currentPosX]
      if n == 3 then
        cell.vport = (((cell.vport + d) -1) % 16) +1
      end
    end  
    -- key = function(n,z) end,
    
  },

  P = {
    title = "Internal Patch",
    doRight = true,
    doDown = true,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count)
      if from ~= "P" then 
      
        local vport = router[y][x].vport
        
        if patchTable[vport] ~= nil then
  
          for i=1, #patchTable[vport] do
            local xP = patchTable[vport][i][1]
            local yP = patchTable[vport][i][2]
            
            if(x ~=xP or y ~=yP) then
              print ("patch "..xP.."-"..yP.. "  "..x..":"..y)
              process_cell(xP, yP, "P", data, src, count+1)
            end
          end
        end
      end
      
      return data

    end,
    
    cellBuilder = function(x,y)
      local cell = router[y][x]
       if cell.vport == nil then 
          return
      end
      if patchTable[cell.vport] == nil then
        patchTable[cell.vport] = {}
      end
      table.insert(patchTable[cell.vport],{x,y});
    end,
    
    display = function () 
      local cell = router[currentPosY][currentPosX]
      if cell.vport == nil then cell.vport=1 end
      screen.move(40, 51)
      screen.text("patch:") 
      screen.move(88, 51)
      screen.text(cell.vport)
        
      if mode==1 then
        screen.text_center_rotate (120, 60, ">", 270)
        screen.text_center_rotate (122, 60, ">", 90)
      end
    end,
    enc = function(n,d) 
      local cell = router[currentPosY][currentPosX]
      if n == 3 then
        cell.vport = (((cell.vport + d) -1) % 16) +1
      end
    end  
    
    -- process_cell = function(x, y, from, data) end,
    -- display = function () end,
    -- enc = function(n,d) end  
    -- key = function(n,z) end,
    
  }, 
  C = {
    title = "Norns Clock",
    doRight = false,
    doDown = false,
    editExit=true,
    cellBuilder = function(x,y)
       table.insert(clockTable,{x,y});
    end
    
  }, 
  f = {
    title = "Filter",
    doRight = true,
    doDown = true,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count) 
      local cell = router[y][x]
      local stat = 0xF0 & data[1] 
      --tab.print(data)
      
     -- print(from.." "..x..":"..y.."--"..stat.."="..data[1] )
      
      --tab.print(cell)
      
      if stat == 0x80 and cell.filterNote then return nil end
      if stat == 0x90 and cell.filterNote then return nil end
      if stat == 0xB0 and cell.filterCC then return nil end
      if stat == 0xC0 and cell.filterProgChange then return nil end
      if stat == 0xA0 and cell.filterPolyPress then return nil end
      if stat == 0xD0 and cell.filterChPres then return nil end
      if stat == 0xE0 and cell.filterPitch then return nil end
     -- print('a')
      
      return data
    end,
    display = function () 
      local cell = router[currentPosY][currentPosX]
      
      if cell.editPos == nil then cell.editPos=0 end
      
      --screen.level(0)
      screen.stroke()
      --screen.level(8)
      
      screen.circle(7, 55, 3)
      if cell.filterNote then screen.fill() else screen.stroke() end
      
      screen.circle(27, 55, 3)
      if cell.filterCC then screen.fill() else screen.stroke() end
      
      screen.circle(47, 55, 3)
      if cell.filterPitch then screen.fill() else screen.stroke() end
      
      screen.circle(67, 55, 3)
      if cell.filterProgChange then screen.fill() else screen.stroke() end
      
      screen.circle(90, 55, 3)
      if cell.filterChPres then screen.fill() else screen.stroke() end
      
      screen.circle(115, 55, 3)
      if cell.filterPolyPress then screen.fill() else screen.stroke() end
      
      screen.move(0, 51)
      screen.text("note cc's ptch prog chPrs plyPrs") 
      screen.level(8)
      
  --screen.fill()
      -- screen.text(cell.vport)
        
      if mode==1 then
        if cell.editPos == 0 then screen.move(0,46) screen.line(15,46) screen.stroke() end
        if cell.editPos == 1 then screen.move(20,46) screen.line(35,46) screen.stroke() end
        if cell.editPos == 2 then screen.move(40,46) screen.line(55,46) screen.stroke() end
        if cell.editPos == 3 then screen.move(60,46) screen.line(75,46) screen.stroke() end
        if cell.editPos == 4 then screen.move(80,46) screen.line(99,46) screen.stroke() end
        if cell.editPos == 5 then screen.move(104,46) screen.line(127,46) screen.stroke() end
        
        screen.move(25, 64)
        screen.text("en/dis")
        
        screen.move(84, 64)
        screen.text("< >")
      end
      
    end,
    enc = function(n,d) 
      local cell = router[currentPosY][currentPosX]
      if n == 2 then
        cell.editPos = (cell.editPos + d)  % 6
      end
    end, 
    key = function(n,z) 
      local cell = router[currentPosY][currentPosX]
      
      if n==3 and z ==0 then
        if cell.editPos == 0 then cell.filterNote = not cell.filterNote  end
        if cell.editPos == 1 then cell.filterCC = not cell.filterCC  end
        if cell.editPos == 2 then cell.filterPitch = not cell.filterPitch end
        if cell.editPos == 3 then cell.filterProgChange = not cell.filterProgChange end
        if cell.editPos == 4 then cell.filterChPres = not cell.filterChPres end
        if cell.editPos == 5 then cell.filterPolyPress = not cell.filterPolyPress end
      end
      
    end,
    
  }, 
  ["1"] = {
    title = "Channnel Filter",
    doRight = true,
    doDown = true,
    editExit=true,
    
    process_cell = function(x, y, from, data, src, count) 
      local cell = router[y][x]
      local stat = 0xF0 & data[1] 
      local ch = 0xF & data[1] 
      --tab.print(data)
      
     -- print(from.." "..x..":"..y.."--"..stat.."="..data[1] )
      
      --tab.print(cell)
      
      if stat >= 0x80 and stat <= 0xE0 then
        if cell.chLower > ch or cell.chUpper < ch then return nil end
        if cell.forceChannel then
          data[1] = stat + (cell.toChannel)
        end
      end
      
     -- print('a')
      
      return data
    end,
    display = function () 
      local cell = router[currentPosY][currentPosX]
      
      if cell.editPos == nil then cell.editPos=0 end
      if cell.chLower == nil then cell.chLower=0 end
      if cell.chUpper == nil then cell.chUpper=15 end
      if cell.toChannel == nil then cell.toChannel=0 end
      
      
      screen.move(0, 51)
      screen.text("lower upper forceCh toCh")
      
      screen.move(5, 57)
      screen.text(cell.chLower+1)
      screen.move(30, 57)
      screen.text(cell.chUpper+1)
      screen.move(50, 57)
      
      screen.stroke()
      screen.circle(62, 55, 3)
      if cell.forceChannel then screen.fill() else screen.stroke() end
        
      screen.text(cell.chUpper+1)
      screen.move(85, 57)
        
      screen.text(cell.toChannel+1)
      screen.level(8)
      
 
        
      if mode==1 then
        if cell.editPos == 0 then screen.move(0,46) screen.line(19,46) screen.stroke() end
        if cell.editPos == 1 then screen.move(24,46) screen.line(43,46) screen.stroke() end
        if cell.editPos == 2 then screen.move(48,46) screen.line(75,46) screen.stroke() end
        if cell.editPos == 3 then screen.move(80,46) screen.line(95,46) screen.stroke() end
        
        screen.move(84, 64)
        screen.text("< >")
        if cell.editPos ~= 2 then
          screen.text_center_rotate (120, 60, ">", 270)
          screen.text_center_rotate (122, 60, ">", 90)
        else
          screen.move(25, 64)
          screen.text("en/dis")
        end
      end
      
    end,
    enc = function(n,d) 
      local cell = router[currentPosY][currentPosX]
      if n == 2 then
        cell.editPos = (cell.editPos + d)  % 4
      end
      
      if n == 3 then
        if cell.editPos == 0 then cell.chLower = (cell.chLower + d)  % 16 end
        if cell.editPos == 1 then cell.chUpper = (cell.chUpper + d)  % 16 end
        if cell.editPos == 3 then cell.toChannel = (cell.toChannel + d)  % 16 end
      end
      
    end,
    key = function(n,z) 
      local cell = router[currentPosY][currentPosX]
      
      if n==3 and z ==0 then
        if cell.editPos == 2 then cell.forceChannel = not cell.forceChannel end
      end
      
    end,

  }, 
  c = {
    title = "CC Filter",
    doRight = false,
    doDown = false,
    editExit=true,
    
    -- process_cell = function(x, y, from, data) end,
    -- display = function () end,
    -- enc = function(n,d) end  
    -- key = function(n,z) end,
    
  }, 
  n = {
    title = "Note Filter",
    doRight = false,
    doDown = false,
    editExit=true,
    
    -- process_cell = function(x, y, from, data) end,
    -- display = function () end,
    -- enc = function(n,d) end  
    -- key = function(n,z) end,
    
  }, 
  t = {
    title = "Clock Filter",
    doRight = false,
    doDown = false,
    editExit=true,
    
    -- process_cell = function(x, y, from, data) end,
    -- display = function () end,
    -- enc = function(n,d) end  
    -- key = function(n,z) end,
    
  } 
}


-- CORE NORNS OVERRIDES --
if _norns.midi.eventOrig == nil then
  _norns.midi.eventOrig = _norns.midi.event
end


_norns.midi.event = function(id, data)
  _norns.midi.eventOrig(id, data)
  print(midi.devices[id].name .. "-".. data[1] .. " " ..data[2].. " " .. data[3]) 
  -- tab.print(midiInTable)
  
  if midiInTable['*'] ~= nil then
    -- print("   in to ALL")
    for i=1, tab.count(midiInTable['*']) do
      --tab.print(midiInTable['*'][i])
      local x = midiInTable['*'][i][1]
      local y = midiInTable['*'][i][2]
      if x + 1 < bounds_x then
        processLoops = 0
        process_cell(x+1, y, "L", data, id, 0)
      end
      if y + 1 < bounds_y then
        processLoops = 0
        process_cell(x, y+1, "T", data, id, 0)
      end
    end
  end
  
  local name = midi.devices[id].name
  if midiInTable[name] ~= nil then
    -- print("   in to "..name)
    for i=1, tab.count(midiInTable[name]) do
      local x = midiInTable[name][i][1]
      local y = midiInTable[name][i][2]
      if x + 1 < bounds_x then
        processLoops = 0
        process_cell(x+1, y, "L", data, id, 0)
      end
      if y + 1 < bounds_y then
        processLoops = 0
        process_cell(x, y+1, "T", data, id, 0)
      end
    end
  end
end

--


function init()
  
  -- if tab.contains(mod.loaded_mod_names(), "midisignals") then 
  --   print("midisignals already running as mod")
  --   return 
  -- end
  
  -- for key,_ in pairs(ops) do
  --   table.insert(OPS_LIST, key)
  -- end
  
  
  tab.print(OPS_LIST)
  
  
  local f=io.open(filepath,"rb")
  if f==nil then
    print("file not found: "..filepath)
    for y = 0, bounds_y do
      router[y] = {}
      for x = 0, bounds_x do
         router[y][x] = {type="."}
      end
    end
  else
    local json_file_str = f:read "*a"
    f:close()
    router = json.decode(json_file_str)
  end  
  

  
  print("Virtual Ports")
  
  for i = 1,#midi.vports do -- query all ports
    -- midi_device[i] = midi.connect(i) -- connect each device
    print(
      "port "..i..": "..util.trim_string_to_width(midi.vports[i].name,80) -- value to insert
    )
    
  end
  
  
  print("Real Ports")
  table.insert(MDEV_LIST, '*')
  for i = 1,#midi.devices do -- query all ports
    -- midi_device[i] = midi.connect(i) -- connect each device
    
    if midi.devices[i].name~= 'virtual' then
      print(
        "port "..i..": "..util.trim_string_to_width(midi.devices[i].name,80) -- value to insert
      )
      table.insert(MDEV_LIST, midi.devices[i].name)
    end
  end
  
  
   
end

function process_cell(x, y, from, data, src, count)
  local doRight = false
  local doDown = false
  local cell = router[y][x]
  
  if count > 20 then
    print("HIT PROCESS LOOP")
    return
  end
  
  --tab.print(data)
  
  if type(ops[cell.type].doRight) == "function" then
    doRight = ops[cell.type].doRight(from)
  else
    doRight = ops[cell.type].doRight
  end
  
  if type(ops[cell.type].doDown) == "function" then
    doDown = ops[cell.type].doDown(from)
  else
    doDown = ops[cell.type].doDown
  end
  
  if ops[cell.type].process_cell then
    data = ops[cell.type].process_cell(x, y, from, data, src, count+1)
    if data == nil then
      return
    end
  end
  
  if doRight and x + 1 < bounds_x then
      process_cell(x+1, y, "L", data, src, count+1)
  end
  if doDown and y + 1 < bounds_y then
    process_cell(x, y+1, "T", data, src, count+1)
  end

  
end



-- from ORCA
local function draw_op_frame(x, y, b)
  screen.level(b)
  screen.rect((x * 5) - 4, ((y * 7) - 4) - 2, 6, 8)
  --screen.fill()
end

local function draw_grid()
  
  clockTable = {}
  midiInTable = {}
  
  screen.font_face(25)
  screen.font_size(6)
  screen.level(mode ==0 and 15 or 4)
  for y = 1, bounds_y do
    for x = 1, bounds_x do

      local cell = router[y][x]
      
      if ops[cell.type].cellBuilder then
        ops[cell.type].cellBuilder(x,y)
      end

      if y==currentPosY and x == currentPosX then
        draw_op_frame(x, y, 10)
      end
      screen.level(mode ==0 and 15 or 4)
      

      if cell.type=="." then
        screen.move(((x) * 5) - 3, ((y)* 7) - 1)
        screen.text(".")
      else
        screen.move(((x) * 5) - 3, ((y)* 7) )
        screen.text(cell.type)
      end
      
      screen.stroke()
    end
  end
  
  -- clock management
  if tab.count(clockTable)>0 then
    if clockManager == nil then
      clockManager = clock.run(process_clock)
    end
  else
    if clockManager ~= nil then
      clock.cancel(clockManager)
      clockManager = nil
    end
  end
    
  
  -- bottom Information
  screen.level(mode == 0 and 4 or 15)
  screen.move(0, 43)
  
  local cell = router[currentPosY][currentPosX]
  
  screen.text(ops[cell.type].title)
  
  if ops[cell.type].display then
    ops[cell.type].display()
  end
  
  
  screen.level(15)
  if mode==0 then 
    screen.move(25, 64)
    screen.text("save")
    screen.text_center_rotate (120, 60, ">", 270)
    screen.text_center_rotate (122, 60, ">", 90)
    screen.move(80, 64)
    screen.text("<< >>")
  end
  
  if ops[cell.type].editExit then
    screen.move(0, 64)
    if mode == 0 then
      screen.text("edit")
    else
      screen.text("exit")  
    end
  end
end



function redraw()
  screen.clear()
  draw_grid()
  screen.update()
end

function key(n,z)
  -- level = 3 + z * 12
  -- print("key: "..n..":"..z)
  
  local cell = router[currentPosY][currentPosX]
  
  if mode==0 and n==3 and z==0 then
    screen.move(25, 64)
    screen.text("saving..")
    local jsonEnc = json.encode(router)
    local f = io.open(filepath, "w+")
    io.output(f)
    io.write(jsonEnc)
    io.close(f)
    screen.text("saved") 
  end
  
  if mode == 1 and ops[cell.type].key and n==3 then
    ops[cell.type].key(n,z)
  end
  

  
  if ops[cell.type].editExit then
     if n==2 and z==0 then
          mode = mode==0 and 1 or 0
      end  
  end
  
  redraw()
  
end

function enc(n,d)

  if mode == 0 then
    if n == 2 then
      currentPosX = (((currentPosX + d) -1)% bounds_x ) +1
    end
    
    if n == 3 then
      currentPosY = (((currentPosY + d) -1) % bounds_y) +1
    end
    
    if n == 1 then
      local cell = router[currentPosY][currentPosX]
      local op_index =  tab.key(OPS_LIST, cell.type or ".")
      --print(op_index)
      
       op_index = (((op_index + d) -1) % tab.count(OPS_LIST)) +1
      -- print(op_index)
       router[currentPosY][currentPosX].type = OPS_LIST[op_index]
       
       --print(router[currentPosY][currentPosX].type)
      
    end
    
  else
    
    local cell = router[currentPosY][currentPosX]
    
    if ops[cell.type].enc then
      ops[cell.type].enc(n,d)
    end
  
  end
  
  
  redraw()

end

function process_clock()
  while true do
    -- print('CC')
    clock.sync(1/24)
    for i=1, tab.count(clockTable) do
      local x = clockTable[i][1]
      local y = clockTable[i][2]
      if x + 1 < bounds_x then
        processLoops = 0
        process_cell(x+1, y, "L", {0xf8}, "nornClock", 0)
      end
      if y + 1 < bounds_y then
        processLoops = 0
        process_cell(x, y+1, "T", {0xf8}, "nornClock", 0)
      end
    end
  end
end





) - 2, 6, 8)
  --screen.fill()
end

local function draw_grid()
  
  clockTable = {}
  midiInTable = {}
  
  screen.font_face(25)
  screen.font_size(6)
  screen.level(mode ==0 and 15 or 4)
  for y = 1, bounds_y do
    for x = 1, bounds_x do

      local cell = router[y][x]
      
      if ops[cell.type].cellBuilder then
        ops[cell.type].cellBuilder(x,y)
      end

      if y==currentPosY and x == currentPosX then
        draw_op_frame(x, y, 10)
      end
      screen.level(mode ==0 and 15 or 4)
      

      if cell.type=="." then
        screen.move(((x) * 5) - 3, ((y)* 7) - 1)
        screen.text(".")
      else
        screen.move(((x) * 5) - 3, ((y)* 7) )
        screen.text(cell.type)
      end
      
      screen.stroke()
    end
  end
  
  -- clock management
  if tab.count(clockTable)>0 then
    if clockManager == nil then
      clockManager = clock.run(process_clock)
    end
  else
    if clockManager ~= nil then
      clock.cancel(clockManager)
      clockManager = nil
    end
  end
    
  
  -- bottom Information
  screen.level(mode == 0 and 4 or 15)
  screen.move(0, 43)
  
  local cell = router[currentPosY][currentPosX]
  
  screen.text(ops[cell.type].title)
  
  if ops[cell.type].display then
    ops[cell.type].display()
  end
  
  
  screen.level(15)
  if mode==0 then 
    screen.move(25, 64)
    screen.text("save")
    screen.text_center_rotate (120, 60, ">", 270)
    screen.text_center_rotate (122, 60, ">", 90)
    screen.move(80, 64)
    screen.text("<< >>")
  end
  
  if ops[cell.type].editExit then
    screen.move(0, 64)
    if mode == 0 then
      screen.text("edit")
    else
      screen.text("exit")  
    end
  end
end



function redraw()
  screen.clear()
  draw_grid()
  screen.update()
end

function key(n,z)
  -- level = 3 + z * 12
  -- print("key: "..n..":"..z)
  
  local cell = router[currentPosY][currentPosX]
  
  if mode==0 and n==3 and z==0 then
    screen.move(25, 64)
    screen.text("saving..")
    local jsonEnc = json.encode(router)
    local f = io.open(filepath, "w+")
    io.output(f)
    io.write(jsonEnc)
    io.close(f)
    screen.text("saved") 
  end
  
  if mode == 1 and ops[cell.type].key and n==3 then
    ops[cell.type].key(n,z)
  end
  

  
  if ops[cell.type].editExit then
     if n==2 and z==0 then
          mode = mode==0 and 1 or 0
      end  
  end
  
  redraw()
  
end

function enc(n,d)

  if mode == 0 then
    if n == 2 then
      currentPosX = (((currentPosX + d) -1)% bounds_x ) +1
    end
    
    if n == 3 then
      currentPosY = (((currentPosY + d) -1) % bounds_y) +1
    end
    
    if n == 1 then
      local cell = router[currentPosY][currentPosX]
      local op_index =  tab.key(OPS_LIST, cell.type or ".")
      --print(op_index)
      
       op_index = (((op_index + d) -1) % tab.count(OPS_LIST)) +1
      -- print(op_index)
       router[currentPosY][currentPosX].type = OPS_LIST[op_index]
       
       --print(router[currentPosY][currentPosX].type)
      
    end
    
  else
    
    local cell = router[currentPosY][currentPosX]
    
    if ops[cell.type].enc then
      ops[cell.type].enc(n,d)
    end
  
  end
  
  
  redraw()

end

function process_clock()
  while true do
    -- print('CC')
    clock.sync(1/24)
    for i=1, tab.count(clockTable) do
      local x = clockTable[i][1]
      local y = clockTable[i][2]
      if x + 1 < bounds_x then
        processLoops = 0
        process_cell(x+1, y, "L", {0xf8}, "nornClock", 0)
      end
      if y + 1 < bounds_y then
        processLoops = 0
        process_cell(x, y+1, "T", {0xf8}, "nornClock", 0)
      end
    end
  end
end
