-- Mock mGBA environment to exercise rr_logger.lua logic
local ENC = {}
ENC[" "]=0; for i=0,9 do ENC[tostring(i)]=0xA1+i end
for i=0,25 do ENC[string.char(65+i)]=0xBB+i; ENC[string.char(97+i)]=0xD5+i end
ENC["?"]=0xAC; ENC["-"]=0xAE; ENC["'"]=0xB4; ENC["."]=0xAD
local function enc(s, len) local t={} for i=1,#s do t[i]=string.char(ENC[s:sub(i,i)]) end
  local r=table.concat(t); if len then r=r..string.rep("\255", len-#r) end return r end

local ROMSIZE = 0x400000
local rom = {} -- sparse patches: offset -> string
local function put(off, s) rom[#rom+1]={off=off,s=s} end
-- species names @0x123457 (odd alignment on purpose), stride 11
local sp = {"??????","Bulbasaur","Ivysaur","Venusaur","Charmander"}
local spT = {} for i,n in ipairs(sp) do spT[i]=enc(n,11) end
for i=#sp,25 do spT[i+1]=enc("Mon"..i,11) end
spT[26]=enc("Pikachu",11); spT[27]=enc("Raichu",11)
put(0x123457, table.concat(spT))
-- moves stride 13
put(0x200001, enc("-",13)..enc("Pound",13)..enc("Karate Chop",13)..enc("Double Slap",13)..string.rep(enc("Tackle",13),80)..enc("Thunder Shock",13))
-- abilities stride 17
put(0x210000, enc("-------",17)..enc("Stench",17)..enc("Drizzle",17)..string.rep(enc("Filler",17),5)..enc("Static",17))
-- items stride 44
local function item(n) return enc(n,14)..string.rep("\0",30) end
put(0x220000, item("????????")..item("Master Ball")..item("Ultra Ball")..string.rep(item("Junk"),20)..item("Oran Berry"))
-- base stats stride 28 (also a decoy Bulbasaur pattern earlier)
put(0x0FFFF0, string.char(45,49,49,45,65,65,12,3))
local function bs(h,a,d,s,sa,sd,t1,t2,ab1,ab2,hid)
  local b={h,a,d,s,sa,sd,t1,t2} for i=9,28 do b[i]=0 end b[0x17]=ab1 b[0x18]=ab2 b[0x1B]=hid
  local o={} for i=1,28 do o[i]=string.char(b[i]) end return table.concat(o) end
local bsT={string.rep("\0",28), bs(45,49,49,45,65,65,12,3,65,0,34), bs(60,62,63,60,80,80,12,3,65,0,34)}
for i=4,25 do bsT[i]=string.rep("\0",28) end
bsT[26]=bs(35,55,40,90,50,50,13,13,9,0,31) -- Pikachu (id 25): Static / Lightning Rod hidden
bsT[27]=bs(60,90,55,110,90,80,13,13,9,0,31)
put(0x300000, table.concat(bsT))
table.sort(rom, function(a,b) return a.off<b.off end)
local function romByte(off)
  for _,p in ipairs(rom) do if off>=p.off and off<p.off+#p.s then return p.s:byte(off-p.off+1) end end
  return 0x11
end

local ram = {}
local function w8(a,v) ram[a]=v&0xFF end
local function w16(a,v) w8(a,v) w8(a+1,v>>8) end
local function w32(a,v) w16(a,v&0xFFFF) w16(a+2,(v>>16)&0xFFFF) end
local function wstr(a,s) for i=1,#s do w8(a+i-1,s:byte(i)) end end
local function rd8(a)
  if a>=0x08000000 then return romByte(a-0x08000000) end
  return ram[a] or 0
end

emu = {}
function emu.read8(self,a) return rd8(a) end
function emu.read16(self,a) return rd8(a)|(rd8(a+1)<<8) end
function emu.read32(self,a) return emu.read16(self,a)|(emu.read16(self,a+2)<<16) end
function emu.readRange(self,a,n)
  if a>=0x08000000 then
    local off=a-0x08000000; local out={}
    -- fast path using patches
    local base = string.rep("\17", n)
    local buf = {base}
    local res = base
    for _,p in ipairs(rom) do
      local s0, e0 = p.off, p.off+#p.s-1
      local s1, e1 = math.max(s0,off), math.min(e0,off+n-1)
      if s1<=e1 then
        res = res:sub(1, s1-off) .. p.s:sub(s1-s0+1, e1-s0+1) .. res:sub(e1-off+2)
      end
    end
    return res
  end
  local t={} for i=0,n-1 do t[i+1]=string.char(rd8(a+i)) end return table.concat(t)
end
function emu.romSize() return ROMSIZE end
function emu.getGameTitle() return "POKEMON FIRE" end
function emu.getGameCode() return "AGB-BPRE" end
console = { log=function(_,s) print(s) end, error=function(_,s) print("ERR "..s) end }
local cbs = {}
callbacks = { add=function(_,n,f) cbs[n]=f return #cbs+1 end, remove=function() end }

-- Build a CFRU plain mon
local function mon(addr, pid, otid, nick, species, item, moves, level, hp, maxhp, ivword)
  for i=0,99 do w8(addr+i,0) end
  w32(addr,pid) w32(addr+4,otid) wstr(addr+8, enc(nick,10)) w8(addr+0x13, 2)
  w16(addr+0x20,species) w16(addr+0x22,item) w32(addr+0x24,1000)
  for i=1,4 do w16(addr+0x2C+(i-1)*2, moves[i] or 0) w8(addr+0x34+i-1, 20) end
  w32(addr+0x48, ivword or 0x3FFFFFFF)
  w8(addr+0x54,level) w16(addr+0x56,hp) w16(addr+0x58,maxhp)
end
local function encryptMon(addr)  -- convert plain at addr to vanilla encryption, order per pid
  local pid = emu:read32(addr); local otid = emu:read32(addr+4); local key = pid ~ otid
  local data = emu:readRange(addr+0x20, 48)
  local sub = {G=data:sub(1,12),A=data:sub(13,24),E=data:sub(25,36),M=data:sub(37,48)}
  local ORD={"GAEM","GAME","GEAM","GEMA","GMAE","GMEA","AGEM","AGME","AEGM","AEMG","AMGE","AMEG","EGAM","EGMA","EAGM","EAMG","EMGA","EMAG","MGAE","MGEA","MAGE","MAEG","MEGA","MEAG"}
  local o = ORD[pid%24+1]; local out = ""
  for i=1,4 do out = out .. sub[o:sub(i,i)] end
  local sum=0
  for i=0,23 do sum = sum + string.unpack("<I2", data, i*2+1) end
  w16(addr+0x1C, sum & 0xFFFF)
  for i=0,11 do w32(addr+0x20+i*4, (string.unpack("<I4", out, i*4+1) ~ key) & 0xFFFFFFFF) end
end

-- save blocks
local SB1, SB2 = 0x0202552C, 0x02024588
w32(0x03005008, SB1) w32(0x0300500C, SB2)
wstr(SB2, enc("THINH",8)) w16(SB2+0x0E, 3) w8(SB2+0x10, 12) w8(SB2+0x11, 5)
w32(SB2+0xF20, 0xDEADBEEF) w32(SB1+0x290, 3000 ~ 0xDEADBEEF)
w8(SB1+4, 3) w8(SB1+5, 0) w8(0x02036DFC+0x14, 0x58)

return { cbs=cbs, w8=w8, w16=w16, w32=w32, mon=mon, encryptMon=encryptMon, SB1=SB1, SB2=SB2,
  run=function(n) for i=1,n do cbs.frame() end end }
