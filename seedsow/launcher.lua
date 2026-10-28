-- HBLauncher for Seedsow (Lua port)
--
-- An applet launcher that runs inside the Seedsow Lua editor. It lists the
-- programs installed in the game's save slots and launches the selected one in
-- the running session; the launched program takes over the screen until it
-- exits. (The game does not act on a slot jump issued from inside a running
-- program, so launching is in-process.)
--
-- This is the Seedsow port of HBLauncher's menu. The SmileBASIC port lives in
-- ../smilebasic. The Seedsow Lua editor embeds this file as a submodule and a
-- fresh build publishes it to slot 4 (see seedsow-lua-editor editor/build.py).
--
-- Program interface: the editor runs this chunk with (engine, editor) and uses
-- its returned function as the per-frame update. The editor API provides:
--   editor.screen(color) / editor.label(id,x,y,size,value) / editor.rect(...)
--   editor.held(name) / editor.pressed(name)  -- A B X Y L R Up Down Left Right
--   editor.read(name) / editor.slot / editor.openEditor()
--
-- Controls: Up/Down select, A launches the selected slot. The editor reserves
-- B to stop a running program and return to the editor, so a launched program
-- (and the menu itself) exits with B; press Y in the editor to re-run the menu.

local engine, editor = ...

local BG = '0xff101826'
local HILITE = '0xff2f6cff'
local TITLE = 'HBLauncher'

local sel, entries, mode, sub, note = 1, nil, 'menu', nil, ''

local function code_name(slot) return string.format('sscode%03d.lua', slot) end
local function ref_name(slot) return string.format('ssslot%03d.ref', slot) end

-- Scan the user slots on both load-menu pages. Editor slots (1-3, 13-15) are
-- skipped; this launcher's own slot is left off the list.
local function scan()
    entries = {}
    for slot = 4, 24 do
        local editor_slot = (slot >= 13 and slot <= 15)
        if not editor_slot and slot ~= (editor.slot or 4) then
            local ref = editor.read(ref_name(slot))
            local file = ref and ref:match('^([^\r\n]+)')
            if file and editor.read(code_name(slot)) then
                entries[#entries + 1] = { slot = slot, file = file }
            end
        end
    end
    if sel > #entries then sel = #entries end
    if sel < 1 then sel = 1 end
end

local function draw_menu()
    editor.screen(BG)
    -- A left accent bar marks the selection; it sits left of the text so it
    -- never covers it (the program-layer rect draws above the labels).
    if #entries > 0 then
        editor.rect('cursor', 24, 150 + (sel - 1) * 46 - 2, 10, 34, HILITE)
    end
    editor.label('title', 40, 36, 44, TITLE)
    editor.label('hint', 40, 92, 20, 'Up/Down select   A run   B editor (Y reopens)')
    if #entries == 0 then
        editor.label('empty', 40, 200, 24,
            'No programs installed. Save + publish one from the editor.')
    else
        for i, entry in ipairs(entries) do
            editor.label('e' .. i, 48, 150 + (i - 1) * 46, 24,
                string.format('%s %2d  %s', i == sel and '>' or ' ', entry.slot, entry.file))
        end
    end
    if note ~= '' then editor.label('note', 40, 660, 20, note) end
end

local function launch_inproc(entry)
    local src = editor.read(code_name(entry.slot))
    if not src then note = 'Slot ' .. entry.slot .. ' has no source'; draw_menu(); return end
    local fn, why = loadstring(src, '@slot' .. entry.slot)
    if not fn then note = 'Load failed: ' .. tostring(why); draw_menu(); return end
    local env = setmetatable({ e = engine, engine = engine, editor = editor,
        print = editor.print }, { __index = _G })
    env._G = _G
    setfenv(fn, env)
    local ok, ret = pcall(fn, engine, editor)
    if not ok then note = 'Error: ' .. tostring(ret); draw_menu(); return end
    if type(ret) == 'function' then sub = ret
    elseif type(ret) == 'table' and type(ret.update) == 'function' then sub = ret.update
    else sub = nil end
    mode, note = 'run', ''
end

scan()
draw_menu()

return function(e, ed)
    -- The editor reserves B to stop a running program and return to the editor,
    -- so a launched program exits with B; press Y there to re-run this menu.
    if mode == 'run' then
        if sub then
            local ok, why = pcall(sub, e, ed)
            if not ok then
                mode, sub, note = 'menu', nil, 'Program error: ' .. tostring(why)
                scan(); draw_menu()
            end
        end
        return
    end

    local moved = false
    if ed.pressed('Down') and sel < #entries then sel = sel + 1; moved = true end
    if ed.pressed('Up') and sel > 1 then sel = sel - 1; moved = true end
    if #entries > 0 and ed.pressed('A') then launch_inproc(entries[sel]); return end
    if moved then draw_menu() end
end
