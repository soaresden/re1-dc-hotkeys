-- cold boot with watchpoints over code believed dead (DEAD_RANGES="a:b,...")
-- presses START / CROSS regularly to go through the movies, the title, the
-- character select and the intro cutscene, then plays a little (inventory,
-- walking). Logs every hit.
local steps = {}
local function at(f, fn) steps[f] = fn end
at(2, function(a, n)
  PCSX.settings.emulator.Debug.Debug = true
  WATCH = {}
  for r in os.getenv('DEAD_RANGES'):gmatch('[^,]+') do
    local lo, hi = r:match('(%x+):(%x+)'); lo = tonumber(lo, 16); hi = tonumber(hi, 16)
    for _, kind in ipairs({'Exec', 'Write', 'Read'}) do
      WATCH[#WATCH + 1] = PCSX.addBreakpoint(lo, kind, hi - lo, 'dead', function()
        local rg = PCSX.getRegisters()
        a.L(string.format('DEADHIT %s pc=%08x ra=%08x range=%08x F%d', kind, rg.pc, rg.GPR.n.ra, lo, FR)) end)
    end
  end
  a.L('watch on')
end)
local LAST = tonumber(os.getenv('HK_LAST') or '20000')
return { step = function(n, a)
  FR = n
  if steps[n] then steps[n](a, n) end
  if n > 600 and n < 14000 and n % 150 == 0 then a.press(n % 300 == 0 and a.B.START or a.B.CROSS, 6) end
  if n == 14500 then a.press(a.B.START, 6) end            -- inventory
  if n == 14700 then a.press(a.B.RIGHT, 6) end
  if n == 14800 then a.press(a.B.CROSS, 6) end
  if n == 14900 then a.press(a.B.TRIANGLE, 6) end
  if n == 15000 then a.press(a.B.START, 6) end
  if n == 15300 then a.press(a.B.UP, 120) end              -- walk
  if n == 15500 then a.press(a.B.LEFT, 60) end
  if n % 2000 == 0 then a.L(string.format('F%d c3000=%08x cab00=%04x', n, a.r32(0x800c3000), a.r16(0x800cab00))) a.shot('w' .. n) end
  if n == LAST then a.quit() end
end }
