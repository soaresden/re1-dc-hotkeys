-- deterministic hotkey test scenario
local STATE = os.getenv('HK_STATE') or 'hk_dining.sstate'
local SCEN = os.getenv('HK_SCEN') or 'equip'
HITS = {hook=0, call=0, pad=0, sync=0, load=0}
local bps = {}
local base = 0
local function st(a, n, tag)
  a.L(string.format('%s F%d pc=%08x ra=%08x fc04=%08x 8680=%04x 8682=%04x menu=%02x st=%02x/%02x/%02x eq=%02x wpn=%02x inv=%02x%02x %02x%02x %02x%02x hk=%02x%02x%02x%02x b90eb=%02x hits h=%d c=%d p=%d s=%d l=%d x=%d t0=%d t1=%d',
    tag, n, PCSX.getRegisters().pc, PCSX.getRegisters().GPR.n.ra, a.r32(0x800cfc04), a.r16(0x800c8680), a.r16(0x800c8682), a.r8(0x800c845b), a.r8(0x800c51a8), a.r8(0x800c51a9), a.r8(0x800c51aa),
    a.r8(0x800c8689), a.r8(0x800c5126), a.r8(0x800c8784), a.r8(0x800c8785), a.r8(0x800c8786), a.r8(0x800c8787), a.r8(0x800c8788), a.r8(0x800c8789),
    a.r8(HKT), a.r8(HKT+1), a.r8(HKT+2), a.r8(HKT+3), a.r8(0x800b90eb),
    HITS.hook, HITS.call, HITS.pad, HITS.sync, HITS.load, a.r16(0x800c5158), a.r16(0x801fec24), a.r16(0x801feca4)))
end
local steps = {}
local function at(f, fn) steps[f] = fn end

HKT = tonumber(os.getenv('HK_TABLE') or '', 16) or tonumber(os.getenv('HK_PICK'), 16)
at(10, function(a, n) a.load(STATE) end)
at(12, function(a, n)
  if (os.getenv('HK_INJECT') or '') ~= '' then
    local f = io.open(os.getenv('HK_INJECT'), 'rb'); local data = f:read('*a'); f:close()
    local base = tonumber(os.getenv('HK_BASE') or '8000f800', 16)
    for i = 1, #data do a.w8(base + i - 1, data:byte(i)) end
    a.w32(tonumber(os.getenv('HK_SITE_HOOK'), 16), tonumber(os.getenv('HK_JAL'), 16))
    a.w32(tonumber(os.getenv('HK_SITE_GRID'), 16), tonumber(os.getenv('HK_DRAWJAL'), 16))
    a.w32(tonumber(os.getenv('HK_SITE_FRAME'), 16), tonumber(os.getenv('HK_FRAMEJAL'), 16))
    a.L('INJECTED '..#data)
  end
end)
at(40, function(a, n)
  PCSX.settings.emulator.Debug.Debug = true
  bps[1] = PCSX.addBreakpoint(tonumber(os.getenv('HK_HOOK'),16), 'Exec', 4, 'hook', function() HITS.hook = HITS.hook + 1 end)
  bps[2] = PCSX.addBreakpoint(tonumber(os.getenv('HK_SITE_HOOK'), 16), 'Exec', 4, 'call', function() HITS.call = HITS.call + 1 end)
  bps[3] = PCSX.addBreakpoint(0x8003b864, 'Exec', 4, 'pad', function() HITS.pad = HITS.pad + 1 end)
  bps[4] = PCSX.addBreakpoint(0x80054e74, 'Exec', 4, 'sync', function() HITS.sync = HITS.sync + 1 end)
  bps[6] = PCSX.addBreakpoint(0x80057ca0, 'Exec', 4, 'heal', function() HITS.heal = (HITS.heal or 0) + 1 end)
  bps[5] = PCSX.addBreakpoint(0x800249c0, 'Exec', 4, 'load', function() HITS.load = HITS.load + 1 end)
  a.L('BP ok')
end)
if SCEN == 'equip' then
  at(60, function(a, n) st(a, n, 'PRE') a.press(a.B.L2, 40) end)
  at(66, function(a, n) a.press(a.B.UP, 6) end)
  at(130, function(a, n) a.press(a.B.L2, 40) end)
  at(136, function(a, n) a.press(a.B.RIGHT, 6) end)   -- shotgun: not owned -> nothing
  at(200, function(a, n) a.press(a.B.L2, 40) end)
  at(206, function(a, n) a.press(a.B.LEFT, 6) end)    -- knife
  at(280, function(a, n) a.press(a.B.UP, 30) end)     -- walk (no L2) should move
  at(330, function(a, n) a.shot('after') end)
end
if SCEN == 'menueq' then
  at(60, function(a, n) st(a, n, 'PRE') a.press(a.B.START, 6) end)
  at(140, function(a, n) a.press(a.B.RIGHT, 6) a.shot('m1') end)
  at(170, function(a, n) a.press(a.B.CROSS, 6) a.shot('m2') end)
  at(200, function(a, n) a.shot('m3') a.press(a.B.CROSS, 6) end)
  at(240, function(a, n) a.shot('m4') a.press(a.B.CROSS, 6) end)
  at(290, function(a, n) a.shot('m5') a.press(a.B.START, 6) end)
  at(400, function(a, n) a.shot('m6') end)
end
if SCEN == 'tasks' then
  local function dumpt(a, n, tag)
    for sl=0,2 do local o=0x801fec24+sl*0x80
      a.L(string.format('%s F%d slot%d status=%d wait=%d entry=%08x thr=%08x', tag, n, sl, a.r16(o), a.r16(o+2), a.r32(o+4), a.r32(o+8))) end
    a.L(string.format('%s cur=%08x', tag, a.r32(0x800cfbec)))
  end
  at(60, function(a, n) dumpt(a, n, 'GAME') a.press(a.B.START, 6) end)
  at(150, function(a, n) dumpt(a, n, 'MENU') end)
end
if SCEN == 'fire' then
  at(60, function(a, n) st(a, n, 'PRE') a.press(a.B.L2, 30) end)
  at(66, function(a, n) a.press(a.B.UP, 6) end)
  at(150, function(a, n) a.shot('equipped') a.press(a.B.R1, 90) end)
  at(185, function(a, n) a.shot('aim') a.press(a.B.CROSS, 6) end)
  at(192, function(a, n) a.shot('fire') end)
  at(260, function(a, n) st(a, n, 'POST') end)
  at(262, function(a, n) a.press(a.B.L2, 30) end)
  at(268, function(a, n) a.press(a.B.LEFT, 6) end)
  at(360, function(a, n) a.shot('knife') a.press(a.B.R1, 60) end)
  at(390, function(a, n) a.shot('knifeaim') end)
end
if SCEN == 'assign' then
  at(60, function(a, n) st(a, n, 'PRE') a.press(a.B.START, 6) end)
  at(140, function(a, n) a.press(a.B.RIGHT, 6) end)
  at(180, function(a, n) st(a, n, 'CURSOR') a.press(a.B.L2, 30) end)
  at(186, function(a, n) a.press(a.B.DOWN, 6) end)
  at(215, function(a, n) st(a, n, 'ASSIGNED') a.shot('menu') end)
  at(230, function(a, n) a.press(a.B.START, 6) end)
  at(380, function(a, n) st(a, n, 'BACK') a.press(a.B.L2, 30) end)
  at(386, function(a, n) a.press(a.B.DOWN, 6) end)
  at(470, function(a, n) st(a, n, 'FINAL') end)
end
if SCEN == 'cursor' then
  local ffi = require('ffi')
  local function dump(a, name) local f=io.open(os.getenv('HARNESS_OUT_DIR')..'/'..name..'.bin','wb'); f:write(ffi.string(PCSX.getMemPtr(), 0x200000)); f:close(); a.L('DUMP '..name) end
  at(60, function(a, n) a.press(a.B.START, 6) end)
  at(140, function(a, n) dump(a, 'c0') a.shot('c0') a.press(a.B.RIGHT, 6) end)
  at(170, function(a, n) dump(a, 'c1') a.shot('c1') a.press(a.B.DOWN, 6) end)
  at(200, function(a, n) dump(a, 'c3') a.shot('c3') a.press(a.B.LEFT, 6) end)
  at(230, function(a, n) dump(a, 'c2') a.shot('c2') a.press(a.B.DOWN, 6) end)
  at(260, function(a, n) dump(a, 'c4') a.shot('c4') a.press(a.B.SQUARE, 6) end)
  at(290, function(a, n) dump(a, 'sq') a.shot('sq') end)
end
if SCEN == 'submenu' then
  local ffi = require('ffi')
  local function dump(a, name) local f=io.open(os.getenv('HARNESS_OUT_DIR')..'/'..name..'.bin','wb'); f:write(ffi.string(PCSX.getMemPtr(), 0x200000)); f:close(); a.L('DUMP '..name) end
  at(60, function(a, n) a.press(a.B.START, 6) end)
  at(140, function(a, n) a.press(a.B.RIGHT, 6) end)
  at(170, function(a, n) dump(a, 'top1') a.press(a.B.CROSS, 6) end)
  at(200, function(a, n) dump(a, 'sub1') a.shot('sub1') a.press(a.B.DOWN, 6) end)
  at(220, function(a, n) dump(a, 'sub2') a.press(a.B.TRIANGLE, 6) end)
  at(250, function(a, n) dump(a, 'top2') a.shot('top2') a.press(a.B.LEFT, 6) end)
  at(270, function(a, n) dump(a, 'top3') a.press(a.B.UP, 6) end)
  at(300, function(a, n) dump(a, 'panel') a.shot('panel') end)
end
if SCEN == 'quick' then
  local function hp(a, v) a.w8(0x800c51ac, v % 256) a.w8(0x800c51ad, math.floor(v / 256)) end
  local function info(a, n, tag) a.L(string.format('%s F%d eq=%02x wpn=%02x hp=%d inv=%02x%02x %02x%02x %02x%02x %02x%02x pick=%02x cur=%02x menu90f0=%02x t0=%d t1=%d', tag, n,
      a.r8(0x800c8689), a.r8(0x800c5126), a.r16(0x800c51ac), a.r8(0x800c8784), a.r8(0x800c8785), a.r8(0x800c8786), a.r8(0x800c8787), a.r8(0x800c8788), a.r8(0x800c8789), a.r8(0x800c878a), a.r8(0x800c878b),
      a.r8(tonumber(os.getenv('HK_PICK'),16)), a.r8(0x800b90f3), a.r8(0x800b90f0), a.r16(0x801fec24), a.r16(0x801feca4))) end
  at(60, function(a, n) info(a, n, 'START') a.press(a.B.L2, 30) end)
  at(66, function(a, n) a.press(a.B.DOWN, 6) end)
  at(150, function(a, n) info(a, n, 'EQUIP_DOWN') hp(a, 40) end)
  at(160, function(a, n) info(a, n, 'HURT') a.press(a.B.L2, 30) end)
  at(166, function(a, n) a.press(a.B.LEFT, 6) end)
  at(210, function(a, n) info(a, n, 'HEAL_LEFT') a.press(a.B.START, 6) end)
  at(300, function(a, n) info(a, n, 'MENU') a.shot('arrows') a.press(a.B.SQUARE, 6) end)
  at(330, function(a, n) info(a, n, 'PICKED') a.shot('picked') a.press(a.B.RIGHT, 6) end)
  at(360, function(a, n) a.press(a.B.SQUARE, 6) end)
  at(390, function(a, n) info(a, n, 'SWAPPED') a.shot('swapped') a.press(a.B.START, 6) end)
  at(520, function(a, n) info(a, n, 'BACK') a.press(a.B.L2, 30) end)
  at(526, function(a, n) a.press(a.B.DOWN, 6) end)
  at(620, function(a, n) info(a, n, 'FINAL') a.shot('final') end)
end
if SCEN == 'draw' then
  local Z = tonumber(os.getenv('HK_ZADDR'), 16)
  at(45, function(a, n) DRAWBP = PCSX.addBreakpoint(tonumber(os.getenv('HK_DRAW'),16), 'Exec', 4, 'draw', function() HITS.draw = (HITS.draw or 0) + 1 end) end)
  at(60, function(a, n) a.press(a.B.START, 6) end)
  at(200, function(a, n) a.press(a.B.SQUARE, 6) end)
  at(230, function(a, n) a.shot('picked') end)
  local zs = {3}
  at(50, function(a, n) a.w32(tonumber(os.getenv('HK_PREADDR'),16), tonumber(os.getenv('HK_PREVAL') or '1')) end)
  for k, z in ipairs(zs) do
    at(140 + k*20, function(a, n)
      local fr = a.r8(0x800c3010); local od = 0x800c88a0 + fr*20
      a.L(string.format('Z%d F%d draws=%d pkt=%08x od=%08x ot=%08x zoff=%d', z, n, HITS.draw or 0, a.r32(0x800b7978), a.r32(od), a.r32(od+4), a.r32(od+8)))
      a.w32(Z, z) end)
    at(150 + k*20, function(a, n) a.shot('z'..z) end)
  end
end
if SCEN == 'edge' then
  local function info(a, n, tag) a.L(string.format('%s F%d eq=%02x wpn=%02x hp=%d inv=%02x%02x %02x%02x %02x%02x %02x%02x pick=%02x t0=%d t1=%d', tag, n,
      a.r8(0x800c8689), a.r8(0x800c5126), a.r16(0x800c51ac), a.r8(0x800c8784), a.r8(0x800c8785), a.r8(0x800c8786), a.r8(0x800c8787), a.r8(0x800c8788), a.r8(0x800c8789), a.r8(0x800c878a), a.r8(0x800c878b),
      a.r8(tonumber(os.getenv('HK_PICK'),16)), a.r16(0x801fec24), a.r16(0x801feca4))) end
  at(60, function(a, n) info(a, n, 'FULLHP') a.press(a.B.L2, 30) end)
  at(66, function(a, n) a.press(a.B.LEFT, 6) end)
  at(120, function(a, n) info(a, n, 'AFTER_HEAL_FULL') a.press(a.B.L2, 30) end)
  at(126, function(a, n) a.press(a.B.RIGHT, 6) end)
  at(170, function(a, n) info(a, n, 'AFTER_EMPTY') a.press(a.B.START, 6) end)
  at(250, function(a, n) a.press(a.B.SQUARE, 6) end)
  at(275, function(a, n) info(a, n, 'PICK') a.press(a.B.SQUARE, 6) end)
  at(300, function(a, n) info(a, n, 'CANCEL') a.press(a.B.SQUARE, 6) end)
  at(325, function(a, n) info(a, n, 'PICK2') a.press(a.B.START, 6) end)
  at(440, function(a, n) info(a, n, 'EXITED') end)
end
if SCEN == 'stripes' then
  -- VRAM before / after a quick-slot weapon swap (L2 + down)
  at(56, function(a, n) a.vram('v_before') a.dump('r_before') a.shot('before') end)
  at(60, function(a, n) st(a, n, 'PRE') a.press(a.B.L2, 30) end)
  at(66, function(a, n) a.press(a.B.DOWN, 6) end)
  at(200, function(a, n) st(a, n, 'POST') a.vram('v_after') a.dump('r_after') a.shot('after') end)
end
if SCEN == 'dbg' then
  local FH = tonumber(os.getenv('HK_FRAMEHOOK'), 16); local HD = tonumber(os.getenv('HK_HUD'), 16)
  C = {fh=0, hd=0}
  at(14, function(a, n)
    PCSX.settings.emulator.Debug.Debug = true
    B1 = PCSX.addBreakpoint(FH, 'Exec', 4, 'fh', function() C.fh = C.fh + 1 end)
    B2 = PCSX.addBreakpoint(HD, 'Exec', 4, 'hd', function() C.hd = C.hd + 1 end)
  end)
  for k = 20, 160, 10 do at(k, function(a, n) a.L(string.format('D F%d fh=%d hd=%d t0=%04x t1=%04x e0=%08x cab00=%04x jal=%08x', n, C.fh, C.hd, a.r16(0x801fec24), a.r16(0x801feca4), a.r32(0x801fec28), a.r16(0x800cab00), a.r32(0x80032740))) end) end
  at(100, function(a, n) a.press(a.B.L2, 10) end)
end
if SCEN == 'door' then
  at(60, function(a, n) a.press(a.B.UP, 50) end)
  at(112, function(a, n) a.press(a.B.CROSS, 6) end)
  for k = 0, 14 do at(120 + k*25, function(a, n) a.shot(string.format('d%02d', k)) a.L(string.format('DOOR F%d c845b=%02x cab00=%04x c3000=%08x t0=%04x e0=%08x', n, a.r8(0x800c845b), a.r16(0x800cab00), a.r32(0x800c3000), a.r16(0x801fec24), a.r32(0x801fec28))) end) end
end
if SCEN == 'otlog' then
  FR = 0
  OTC = {}
  at(30, function(a, n)
    PCSX.settings.emulator.Debug.Debug = true
    B1 = PCSX.addBreakpoint(0x80066dac, 'Exec', 4, 'ot', function()
      local r = PCSX.getRegisters(); local k = string.format('%08x', r.GPR.n.a1)
      OTC[k] = (OTC[k] or 0) + 1 end)
    B2 = PCSX.addBreakpoint(tonumber(os.getenv('HK_FRAMEHOOK'), 16), 'Exec', 4, 'fh', function()
      local parts = {} for k, v in pairs(OTC) do parts[#parts+1] = k..'x'..v end OTC = {}
      a.L(string.format('FH vs=%d frame=%d pkt=%08x c301c=%d ot: %s', FR, a.r8(0x800c3010), a.r32(0x800b7978), a.r8(0x800c301c), table.concat(parts, ' '))) end)
  end)
end
if SCEN == 'dbg2' then
  C = {tile=0, link=0}
  at(14, function(a, n)
    PCSX.settings.emulator.Debug.Debug = true
    B1 = PCSX.addBreakpoint(tonumber(os.getenv('HK_PUTTILE'), 16), 'Exec', 4, 'pt', function()
      C.tile = C.tile + 1
      if C.tile % 20 == 1 then local r = PCSX.getRegisters()
        a.L(string.format('TILE #%d F%d pkt=%08x s4=%08x frame=%d od0=%08x od1=%08x', C.tile, n, a.r32(0x800b7978), r.GPR.n.s4, a.r8(0x800c3010), a.r32(r.GPR.n.s4), a.r32(r.GPR.n.s4+4))) end
    end)
  end)
  at(100, function(a, n) a.vram('v100') a.shot('s100') end)
  at(101, function(a, n) a.vram('v101') a.shot('s101') end)
  at(102, function(a, n) a.vram('v102') end)
end
if SCEN == 'hp' then
  local function hp(a, v) a.w8(0x800c51ac, v % 256) a.w8(0x800c51ad, math.floor(v / 256)) end
  local vals = {96, 60, 40, 15}
  for k, v in ipairs(vals) do
    at(60 + k*20, function(a, n) hp(a, v) end)
    at(70 + k*20, function(a, n) a.shot('hp'..v) end)
  end
  at(160, function(a, n) a.press(a.B.L2, 40) end)
  at(190, function(a, n) a.shot('l2') end)
  at(230, function(a, n) a.shot('l2after') end)
end
if SCEN == 'feat' then
  -- new features: HUD, L2 overlay, quick turn
  local function info(a, n, tag) a.L(string.format('%s F%d ang=%04x st=%02x/%02x hp=%d eq=%02x', tag, n,
      a.r16(0x800c5198), a.r8(0x800c51a9), a.r8(0x800c51aa), a.r16(0x800c51ac), a.r8(0x800c8689))) end
  at(70, function(a, n) info(a, n, 'START') a.shot('hud') a.press(a.B.L2, 40) end)
  at(100, function(a, n) a.shot('overlay') end)
  at(120, function(a, n) a.press(a.B.L2, 30) end)
  at(124, function(a, n) a.press(a.B.DOWN, 6) end)
  at(220, function(a, n) info(a, n, 'EQUIP') a.shot('hud_eq') a.press(a.B.L2, 40) end)
  at(240, function(a, n) a.shot('overlay_eq') end)
  at(270, function(a, n) info(a, n, 'PRETURN') a.press(a.B.SQUARE, 20) a.press(a.B.DOWN, 20) end)
  for k = 271, 286 do at(k, function(a, n) info(a, n, 'T') end) end
  at(300, function(a, n) info(a, n, 'TURNED') a.shot('turned') end)
  at(330, function(a, n) info(a, n, 'AFTER') a.shot('after') end)
end
if SCEN == 'padmap' then
  local seq = {'SQUARE','DOWN','UP','LEFT','RIGHT','CROSS','R1','TRIANGLE','CIRCLE','L1','R2','L2'}
  for k, b in ipairs(seq) do
    at(50 + k*20, function(a, n) a.press(a.B[b], 8) end)
    at(54 + k*20, function(a, n) a.L(string.format('PAD %s raw=%08x new=%08x map=%04x mapnew=%04x', b, a.r32(0x800cfc04), a.r32(0x800cfc08), a.r16(0x800c8680), a.r16(0x800c8682))) end)
  end
end
if SCEN == 'turn' then
  local function snap(a, tag) local t = {} for i = 0, 0x1ff, 2 do t[i] = a.r16(0x800c5124 + i) end SNAP[tag] = t end
  SNAP = {}
  at(58, function(a, n) snap(a, 'a') a.press(a.B.RIGHT, 20) end)
  at(100, function(a, n) snap(a, 'b') a.press(a.B.RIGHT, 20) end)
  at(140, function(a, n) snap(a, 'c')
    for i = 0, 0x1ff, 2 do local x, y, z = SNAP.a[i], SNAP.b[i], SNAP.c[i]
      if x ~= y or y ~= z then a.L(string.format('OFF +%03x %04x %04x %04x', i, x, y, z)) end end end)
end
if SCEN == 'menuvram' then
  at(58, function(a, n) a.press(a.B.START, 6) end)
  at(160, function(a, n) a.vram('v_menu') a.dump('r_menu') a.shot('menu') a.press(a.B.START, 6) end)
  at(300, function(a, n) a.vram('v_back') a.dump('r_back') a.shot('back') end)
end
if SCEN == 'fire2' then
  -- quick-slot Beretta (slot 2), aim, fire: ammo must drop, sound bank loaded
  local function info(a, n, tag) a.L(string.format('%s F%d eq=%02x wpn=%02x ammo=%d vab=%02x vh=%08x', tag, n,
      a.r8(0x800c8689), a.r8(0x800c5126), a.r8(0x800c8787), a.r8(0x800cf9e9), a.r32(0x800f5400))) end
  at(58, function(a, n) info(a, n, 'START') end)
  at(60, function(a, n) a.press(a.B.L2, 30) end)
  at(66, function(a, n) a.press(a.B.DOWN, 6) end)
  at(180, function(a, n) info(a, n, 'EQUIPPED') a.shot('equipped') a.press(a.B.R1, 90) end)
  at(215, function(a, n) a.shot('aim') a.press(a.B.CROSS, 6) end)
  at(222, function(a, n) a.shot('fire') end)
  at(290, function(a, n) info(a, n, 'FIRED') a.shot('after') end)
end
if SCEN == 'cdlog' then
  -- log every CD sector DMA (dest, caller) around a quick-slot swap
  local cnt = 0
  at(50, function(a, n)
    PCSX.settings.emulator.Debug.Debug = true
    CDBP = PCSX.addBreakpoint(0x8007a5a0, 'Exec', 4, 'cd', function()
      local r = PCSX.getRegisters()
      cnt = cnt + 1
      if cnt < 400 then a.L(string.format('CD #%d dest=%08x len=%08x ra=%08x', cnt, r.GPR.n.a0, r.GPR.n.a1, r.GPR.n.ra)) end
    end)
    STK = PCSX.addBreakpoint(0x80014b1c, 'Exec', 4, 'ld', function()
      local r = PCSX.getRegisters()
      a.L(string.format('LOADFILE a0=%08x a1=%08x ra=%08x', r.GPR.n.a0, r.GPR.n.a1, r.GPR.n.ra))
    end)
  end)
  at(60, function(a, n) a.L('PRESS') a.press(a.B.L2, 30) end)
  at(66, function(a, n) a.press(a.B.DOWN, 6) end)
end
if SCEN == 'wbp' then
  -- who writes into the room background buffer during a quick-slot swap?
  local seen = {}
  at(58, function(a, n)
    PCSX.settings.emulator.Debug.Debug = true
    WBP = PCSX.addBreakpoint(tonumber(os.getenv('WBP_ADDR') or '801d10ec', 16), 'Write', 4, 'bg', function()
      local r = PCSX.getRegisters()
      local k = string.format('%08x/%08x', r.pc, r.GPR.n.ra)
      if not seen[k] then seen[k] = true a.L('WRITE pc='..k..string.format(' F%d', n)) end
    end)
  end)
  at(60, function(a, n) a.press(a.B.L2, 30) end)
  at(66, function(a, n) a.press(a.B.DOWN, 6) end)
end
local LAST = tonumber(os.getenv('HK_LAST') or '340')
return { step = function(n, a)
  FR = n
  if steps[n] then steps[n](a, n) end
  if n >= 55 and n <= LAST and (n % 2 == 0) then st(a, n, 'S') end
  if n == LAST then a.quit() end
end }
