local M = dofile("mock.lua")
local src = io.open("../rr_logger.lua"):read("a")
src = src:gsub('OUT_DIR             = "[^"]*"', 'OUT_DIR = "' .. (os.getenv('PWD') or '.') .. '/out/"')
os.execute("rm -rf out && mkdir -p out")
assert(load(src, "@../rr_logger.lua"))()
local P = 0x02024284
-- title screen: no party
M.run(100)
-- game loaded: Pikachu lv5 slot1
M.w8(0x02024029, 1)
M.mon(P, 0x12345679, 0xABCD1234, "Sparky", 25, 23, {1, 84}, 5, 20, 20, 0xBFFFFFFF) -- hidden bit set, holds item 23
M.run(100)
-- walk to route 1
M.w8(M.SB1+4, 3) M.w8(M.SB1+5, 19) M.w8(0x02036DFC+0x14, 0x65) M.run(40)
-- wild battle vs Bulbasaur
local E = 0x0202402C
M.mon(E, 0x1111, 0x2222, "BULBASAUR", 1, 999, {33}, 3, 15, 15) -- item id beyond table -> "#999"
M.w32(0x02022B4C, 0x4) M.w8(0x02023E8A, 0) M.w8(0x030030F0+0x439, 2) M.run(20)
M.w16(0x02023D98, 84) M.w16(E+0x56, 7) M.run(12)  -- thundershock
M.w16(0x02023D98+2, 33) M.w16(P+0x56, 16) M.run(12)
M.w8(0x02023E8A, 7) M.run(12) -- caught
M.w8(0x02024029, 2) M.mon(P+100, 0x1111, 0xABCD1234, "BULBASAUR", 1, 0, {33}, 3, 7, 15) M.run(12)
M.w8(0x030030F0+0x439, 0) M.run(40)
-- level up + move learn + evolution + badge + money
M.w8(P+0x54, 6) M.w16(P+0x2C+4, 39) M.run(40)
M.w16(P+0x20, 26) M.run(40)
M.w8(M.SB1+0xEE0+0x104, 1) M.w32(M.SB1+0x290, 3500 ~ 0xDEADBEEF) M.run(40)
-- trainer battle, lose
M.mon(E, 0x3333, 0x4444, "X", 4, 0, {1}, 10, 30, 30)
M.w32(0x02022B4C, 0x8) M.w16(0x020386AE, 102) M.w8(0x02023E8A, 0) M.w8(0x030030F0+0x439, 2) M.run(20)
M.w16(P+0x56, 0) M.w8(0x02023E8A, 2) M.run(12)
M.w8(0x030030F0+0x439, 0) M.run(40)
-- vanilla-encrypted mon in slot 3 (fallback path)
M.w8(0x02024029, 3) M.mon(P+200, 0x87654321, 0x0F0F0F0F, "Venu", 3, 0, {1,2}, 32, 90, 90) M.encryptMon(P+200) M.run(200)
print("---- snapshot ----")
print(io.open("out/rr_snapshot.json"):read("a"))
print("---- tables ----")
print(io.open("out/rr_rom_tables.json"):read("a"))
