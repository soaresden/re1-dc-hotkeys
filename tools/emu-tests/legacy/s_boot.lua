HITS={hook=0}
return { step = function(n, a)
  if n == 800 then
    a.w32(0x8005bc98, 0x24020002); a.w32(0x8005bc9c, 0x03e00008); a.w32(0x8005bca0, 0)
    a.w32(0x80037760, 0x03e00008); a.w32(0x80037764, 0)
    PCSX.settings.emulator.Debug.Debug = true
    BP = PCSX.addBreakpoint(0x8000f07c, 'Exec', 4, 'hook', function() HITS.hook = HITS.hook + 1 end)
  end
  if n % 300 == 0 then
    a.L(string.format('F%d pc=%08x call=%08x hk=%02x%02x%02x%02x start=%08x tail=%08x hookhits=%d', n, PCSX.getRegisters().pc, a.r32(0x80032084), a.r8(0x800ae840), a.r8(0x800ae841), a.r8(0x800ae842), a.r8(0x800ae843), a.r32(0x8000f000), a.r32(0x800af000), HITS.hook))
  end
  if n == 2400 then a.quit() end
end }
