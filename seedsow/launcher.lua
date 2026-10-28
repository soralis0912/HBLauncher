-- HBLauncher for Seedsow (Lua port)
--
-- An applet launcher that runs inside the Seedsow Lua editor. Like the upstream
-- HBLauncher, it shows installed applets as a list of cards -- a monogram tile,
-- the app name and a one-line description -- and launches the selected one in
-- the running session.
--
-- App metadata follows a lightweight manifest, read from magic comments near
-- the top of each program's source (mirrors upstream's app.json name/desc):
--     -- @name: My Program
--     -- @desc: What it does
-- Programs without them fall back to their source filename.
--
-- This is the Seedsow port of HBLauncher's menu. The SmileBASIC port lives in
-- ../smilebasic. The Seedsow Lua editor embeds this file as a submodule and a
-- fresh build publishes it to slot 4 (see seedsow-lua-editor editor/build.py).
--
-- Program interface: the editor runs this chunk with (engine, editor) and uses
-- its returned function as the per-frame update. API used: screen, label(id,x,
-- y,size,value[,color]), rect, read, slot, held/pressed (A B X Y L R Up Down
-- Left Right), openEditor.
--
-- Controls: Up/Down select, A launch, X refresh. The editor reserves B to stop
-- a running program and return to the editor, so a launched applet (and the
-- menu) exits with B; press Y in the editor to re-run the menu.

local engine, editor = ...

-- Note: in this engine rect layers always draw ABOVE text, so text is never
-- placed over a rect. Rects are used only in the gaps (rule, row separators,
-- the left selection bar); the "icon" is a text monogram.
local BG     = '0xff0c1422'   -- screen
local SEP    = '0xff22324a'   -- row separators
local ACCENT = '0xff3f7bd6'   -- rule + selection bar + monogram
local DIM    = '0xff93a6c0'   -- secondary text
local NAME   = '0xffeef3fb'   -- app name
local HOT    = '0xff9fc6ff'   -- selected app name

local VISIBLE  = 6
local CARD_TOP = 126
local CARD_H   = 84
local function cardY(i) return CARD_TOP + (i - 1) * CARD_H end

local sel, top, entries, mode, sub, note = 1, 0, {}, 'menu', nil, ''

local function code_name(slot) return string.format('sscode%03d.lua', slot) end
local function ref_name(slot)  return string.format('ssslot%03d.ref', slot) end

local function clampsel()
  if sel > #entries then sel = #entries end
  if sel < 1 then sel = 1 end
  if sel < top + 1 then top = sel - 1 end
  if sel > top + VISIBLE then top = sel - VISIBLE end
  if top < 0 then top = 0 end
end

-- Read @name / @desc from the first lines of a program (its "manifest").
local function parse_meta(src)
  local name, desc, n = nil, nil, 0
  for line in src:gmatch('[^\n]+') do
    n = n + 1; if n > 60 then break end
    local k, v = line:match('^%s*%-%-+%s*@(%w+)%s*[:=]%s*(.-)%s*$')
    if k == 'name' and not name then name = v
    elseif k == 'desc' and not desc then desc = v end
  end
  return name, desc
end

local function initials(name)
  local a, b = name:match('(%w)%w*[%s/_-]+(%w)')
  if a and b then return (a .. b):upper() end
  return name:sub(1, 2):upper()
end

-- Scan the user slots on both load-menu pages; skip editor slots and self.
local function scan()
  entries = {}
  for slot = 4, 24 do
    if not (slot >= 13 and slot <= 15) and slot ~= (editor.slot or 4) then
      local ref = editor.read(ref_name(slot))
      local file = ref and ref:match('^([^\r\n]+)')
      local src = file and editor.read(code_name(slot))
      if file and src then
        local nm, ds = parse_meta(src)
        entries[#entries + 1] = { slot = slot, file = file, name = nm or file, desc = ds or '' }
      end
    end
  end
  clampsel()
end

local function hide_row(i)
  editor.rect('sep' .. i, 40, 900, 1, 1, SEP)
  for _, p in ipairs({ 'm', 'n', 'd', 's' }) do editor.label(p .. i, 40, 900, 2, '') end
end

local function draw()
  editor.screen(BG)
  editor.label('title', 40, 24, 40, 'HBLauncher', NAME)
  editor.rect('rule', 40, 86, 1200, 2, ACCENT)
  editor.label('hint', 40, 94, 20, 'Up/Down select     A launch     X refresh     B editor', DIM)

  if #entries == 0 then
    editor.label('empty', 40, 200, 24, 'No programs installed. Save + publish one from the editor.', DIM)
    for i = 1, VISIBLE do hide_row(i) end
    editor.rect('cursor', 40, 900, 1, 1, ACCENT)
  else
    -- Selection bar sits left of the text on the selected (always-visible) row.
    editor.rect('cursor', 30, cardY(sel - top) + 4, 6, 68, ACCENT)
    for i = 1, VISIBLE do
      local e = entries[top + i]
      if e then
        local y = cardY(i)
        editor.label('m' .. i, 48, y + 6, 32, initials(e.name), ACCENT)      -- monogram "icon"
        editor.label('n' .. i, 120, y + 8, 26, e.name, (top + i == sel) and HOT or NAME)
        editor.label('d' .. i, 120, y + 44, 18, e.desc ~= '' and e.desc or ('runs ' .. e.file), DIM)
        editor.label('s' .. i, 1090, y + 22, 20, 'slot ' .. e.slot, DIM)
        editor.rect('sep' .. i, 40, y + 78, 1200, 1, SEP)                    -- separator in the gap
      else
        hide_row(i)
      end
    end
  end
  editor.label('foot', 40, 650, 18,
    string.format('%d app%s     showing %d-%d', #entries, #entries == 1 and '' or 's',
      #entries == 0 and 0 or (top + 1), math.min(top + VISIBLE, #entries)), DIM)
end

local function launch_inproc(entry)
  local src = editor.read(code_name(entry.slot))
  if not src then note = 'Slot ' .. entry.slot .. ' has no source'; draw(); return end
  local fn, why = loadstring(src, '@slot' .. entry.slot)
  if not fn then note = 'Load failed: ' .. tostring(why); draw(); return end
  local env = setmetatable({ e = engine, engine = engine, editor = editor, print = editor.print },
    { __index = _G })
  env._G = _G
  setfenv(fn, env)
  local ok, ret = pcall(fn, engine, editor)
  if not ok then note = 'Error: ' .. tostring(ret); draw(); return end
  if type(ret) == 'function' then sub = ret
  elseif type(ret) == 'table' and type(ret.update) == 'function' then sub = ret.update
  else sub = nil end
  mode = 'run'
end

scan()
draw()

return function(e, ed)
  if mode == 'run' then
    if sub then
      local ok, why = pcall(sub, e, ed)
      if not ok then mode, sub = 'menu', nil; scan(); draw() end
    end
    return
  end
  local moved = false
  if ed.pressed('Down') and sel < #entries then sel = sel + 1; clampsel(); moved = true end
  if ed.pressed('Up')   and sel > 1          then sel = sel - 1; clampsel(); moved = true end
  if ed.pressed('X')    then scan(); clampsel(); moved = true end    -- refresh
  if #entries > 0 and ed.pressed('A') then launch_inproc(entries[sel]); return end
  if moved then draw() end
end
