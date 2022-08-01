--[[

main.lua

In this script, we take the opportunity to set up the game's level data. No need
to keep the variables associated with level setup in memory, so we'll just set
everything up in this context, then begin running the game logic in a fresh
context with the next_script function.

--]]



fade(1)

for x = 0, 30 do
   for y = 0, 20 do
      tile(0, x, y, 1)
   end
end

clear()
display()

txtr(0, "overlay/overlay.bmp")
txtr(1, "tiles/boss1.bmp")
txtr(2, "tiles/tilesheet.bmp")
txtr(4, "sprites/spritesheet.bmp")


next_script("boss1.lua")


function draw_img(layer, x, y, w, h, t)
   for yy = 0, h - 1 do
      for xx = 0, w - 1 do
         tile(layer, x + xx, y + yy, t)
         t = t + 1
      end
   end
end


for i = 0, 32 do
   for j = 0, 32 do
      tile(3, i, j, 1)
   end
end


draw_img(1, 0, 0, 16, 8, 16) -- boss graphics
scroll(1, 0, 161) -- screen height 160, scroll boss tiles offscreen


draw_img(2, 1, 1, 14, 4, 2)
draw_img(2, 31, 1, 14, 4, 2)

draw_img(2, 8, 24, 14, 4, 2)
draw_img(2, 14, 42, 14, 4, 2)

function small_cloud(x, y)
   draw_img(3, x, y, 6, 2, 58)
end

small_cloud(2, 2)
small_cloud(12, 12)
small_cloud(4, 24)
small_cloud(22, 18)


print("HYPER WING", 10, 5)

print("ready?", 10, 7)

while true do
   if btn(0) then
      for x = 0, 30 do
         for y = 0, 20 do
            tile(0, x, y, 1)
         end
      end
      clear()
      display()
      break
   end
   clear()
   display()
end
