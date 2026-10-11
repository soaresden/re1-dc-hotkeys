-- interactive driver: polls the CMD_FILE file (default cmd.txt)
local CMD = os.getenv('CMD_FILE') or 'cmd.txt'
return { step = function(n, a)
  if n == 800 and os.getenv('MOVIE_PATCH') == '1' then   -- FR addresses: skip the intro movies
    a.w32(0x8005bc98, 0x24020002); a.w32(0x8005bc9c, 0x03e00008); a.w32(0x8005bca0, 0)
    a.w32(0x80037760, 0x03e00008); a.w32(0x80037764, 0)
    a.L('patched movies')
  end
  if n % 5 == 0 then
    local f = io.open(CMD,'r')
    if f then
      local cmds = f:read('*a'); f:close(); os.remove(CMD)
      for line in cmds:gmatch('[^\n]+') do
        local op, arg1, arg2 = line:match('(%S+)%s*(%S*)%s*(%S*)')
        if op == 'press' then a.press(a.B[arg1], tonumber(arg2) or 8)
        elseif op == 'shot' then a.shot(arg1)
        elseif op == 'vram' then a.vram(arg1)
        elseif op == 'status' then a.L('F'..n..' '..a.status())
        elseif op == 'save' then a.save(arg1)
        elseif op == 'load' then a.load(arg1)
        elseif op == 'w8' then a.w8(tonumber(arg1), tonumber(arg2))
        elseif op == 'w32' then a.w32(tonumber(arg1), tonumber(arg2))
        elseif op == 'r8' then a.L(string.format('R8 %s = %02x', arg1, a.r8(tonumber(arg1))))
        elseif op == 'dump' then local f2=io.open(arg1,'wb'); local mem=PCSX.getMemPtr(); f2:write(require('ffi').string(mem, 0x200000)); f2:close(); a.L('DUMPED '..arg1)
        elseif op == 'lua' then local fn, err = loadstring(cmds:match('lua%s+(.*)$')); if fn then local ok, e2 = pcall(fn, a, n); a.L('LUA '..tostring(ok)..' '..tostring(e2)) else a.L('LUAERR '..tostring(err)) end; break
        elseif op == 'quit' then a.quit()
        end
      end
      a.L('CMDDONE F'..n)
    end
  end
end }
