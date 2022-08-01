
fade(0) -- Reveal the level

delta() -- Reset the delta clock. Clock Starts ticking now. Use to keep track of
        -- how long the player spent in the level

-- Accessing Lua globals is slightly slower. Load values into local slots for
-- faster access.
local entpos = entpos
local entag = entag
local entslot = entslot
local entspr = entspr
local ecolt1 = ecolt1
local ecole = ecole
local tile = tile
local scroll = scroll
local clear = clear
local rline = rline


-- NOTE:
-- This program uses the engine's entag() function to tag each type of entity
-- with an integer id. We could wrap engine entities with proper lua objects,
-- but that'd be slower. Instead, we use the integer tag as a key into a
-- function lookup table, containing update callbacks.
local dead_tag = 0
local bs_cannon_tag = 1000

local shake_ints = { -9, 7, -6, 5, -4, 3, -3, 2, -1, 1, 0 }
local shake_index = 0
local player_dead = false


-- Player's ship: ----------

-- The player's ship is 32x32 pixels, so it uses four 16x16 entities
local ship_e_1 = ent()
local ship_e_2 = ent()
local ship_e_3 = ent()
local ship_e_4 = ent()

enthb(ship_e_1, -11, -12, 9, 11)

entag(entspr(ship_e_1, 1), 1)
entag(entspr(ship_e_2, 2), 1)
entag(entspr(ship_e_3, 3), 1)
entag(entspr(ship_e_4, 5), 1)
entanim(ship_e_3, 3, 2, 2)
entanim(ship_e_4, 5, 2, 2)


function effect(x, y, start, len, rate)
   local e = ent()
   entpos(e, x, y)
   entspr(e, start)
   entanim(e, start, len, rate)
   del(e, 1) -- Delete entity after animation finishes
end


function boom(sx, sy, off)
   local x_off = math.random()
   local y_off = math.random()
   if x_off > 0.5 then
      x_off = (x_off - 0.5) * -1
   end
   if y_off > 0.5 then
      y_off = (y_off - 0.5) * -1
   end
   x_off = x_off * off
   y_off = y_off * off
   effect(sx + 16 + x_off, sy + 16 + y_off, 18, 6, 2)
end


function clamp(v, min, max)
   if v < min then
      return min
   elseif v > max then
      return max
   end
   return v
end

local speed = 1
function ship_move(x_dif, y_dif)
   local cx, cy = entpos(ship_e_1)

   local spd = speed
   if btn(1) then
      spd = spd / 2
   end

   local x = cx + x_dif * spd
   local y = cy + y_dif * spd

   x = clamp(x, 2, 208)
   y = clamp(y, 2, 138)

   entpos(ship_e_1, x, y)
   entpos(ship_e_2, x + 16, y)
   entpos(ship_e_3, x, y + 16)
   entpos(ship_e_4, x + 16, y + 16)
end


local s_bullets = {} -- ship bullets
local e_bullets = {} -- enemy bullets
local reload = 1
local ammo = 2


function standard_gun()
   local x, y = entpos(ship_e_1)

   if ammo == 0 then
      return
   end

   reload = 7
   ammo = ammo - 1

   local e = ent()
   entpos(e, x + 8, y)
   entspr(e, 7)
   entag(e, 2)
   enthb(e, 3, 0, 9, 12)
   entspd(e, 0, -9)

   if shake_index > 9 or shake_index == 0 then
      shake_index = 9
   end

   table.insert(s_bullets, e)
end

local gun = standard_gun


-- Note: lookup array of functions for bullet update. If a bullet entity is
-- tagged with zero, the program removes it from the bullet array.
local bullet_update_tab = {
   function(b)
      local x, y = entpos(b)
      local t = entag(b)
      if y < -8 then
         entag(b, 0)
      end
      local col = ecolt1(b, bs_cannon_tag)
      if col then
         entag(b, 0)
         local hp = entslot(col, 1)
         if hp > 0 then
            hp = hp - 1
            entslot(col, 1, hp)
            entslot(col, 2, 5)
         end
         shake_index = 8
      end
   end,
}

local enemy_bullet_update_tab = {
   function(b) -- regular bullet
      local x, y = entpos(b)
      if y > 170 or x < -10 or x > 250 then
         entag(b, 0)
      end

      if ecole(b, ship_e_1) then
         entag(b, 0)
         player_dead = true
      end
   end,
   function(b) -- laser incubator
      local x, y = entpos(b)
      if ecole(b, ship_e_1) then
         entag(b, 0)
         player_dead = true
      end
      local tm = entslot(b, 1)
      tm = tm + 1
      if tm == 8 then
         entag(b, 6) -- laser downwards
         local parent_dir = entslot(b, 2)
         if parent_dir == 0 then
            entspd(b, 0, 10)
         elseif parent_dir < 100 then
            entspd(b, 0, 9)
         else
            entspd(b, 0, 9)
         end
         entspr(b, 13)
         enthb(b, -5, 0, 6, 16)
         entanim(b, 13, 2, 4)
      else
         entslot(b, 1, tm)
      end
   end,
   function(b) -- laser (downwards)
      local _, y = entpos(b)
      if y > 170 then
         entag(b, 0)
      end
      if ecole(b, ship_e_1) then
         entag(b, 0)
         player_dead = true
      end
   end
}


-- Boss: ----------

local bs_x = 48
local bs_y = 161 -- offscreen

local boss = nil
local bs_dir_y = false
local bs_dir_x = false

local bs_cnt = 0
local bs_cnt2 = 0
local bs_cnt3 = 0


local bs_destroyed_cannons = 0


function enemy_laser_begin(x, y, rot, spd)
   local e = ent()
   entpos(e, x, y)
   entspr(e, 8)
   entslots(e, 2)
   entslot(e, 1, 0)
   entslot(e, 2, rot)
   local dx = 0
   local dy = 1 -- downwards
   dx, dy = rotv(dx, dy, rot)
   dx = dx * spd
   dy = dy * spd
   entspd(e, dx, dy)
   entz(e, 1)
   entag(e, 5)
   enthb(e, -5, -5, 6, 6)

   table.insert(e_bullets, e)
end


function enemy_bullet(x, y, rot, speed)
   local e = ent()
   entpos(e, x, y)
   entspr(e, 8)
   entag(e, 4)
   enthb(e, -5, -5, 6, 6)
   local sx, sy = entpos(ship_e_1)
   sx = sx + 16
   sy = sy + 16
   local dx, dy = dirv(x, y, sx, sy)
   if rot ~= 0 then
      dx, dy = rotv(dx, dy, rot)
   end
   dx = dx * speed
   dy = dy * speed
   entspd(e, dx, dy)
   entanim(e, 8, 2, 4)
   entz(e, 1)

   table.insert(e_bullets, e)
end


function bs_cannon(x, y, r)
   local e = ent()
   entag(e, bs_cannon_tag)
   enthb(e, 4, 4, 10, 10)
   entslots(e, 2)
   entslot(e, 1, 8) -- cannon health
   entslot(e, 2, 0)
   local t_cnt = 0

   local tx = x / 8
   local ty = y / 8
   local reload = r

   return function()
      local rx = bs_x + x
      local ry = bs_y + y
      entpos(e, rx, ry)

      local htm = entslot(e, 2)
      local hp = entslot(e, 1)
      if hp == 0 then
         if entag(e) > 0 then
            bs_destroyed_cannons = bs_destroyed_cannons + 1
            for i = 0, 4 do
               clear() -- sleep a few frames
            end
            effect(rx - 4, ry - 4, 18, 6, 2)
            shake_index = 2
            entag(e, dead_tag)
            tile(1, x / 8, y / 8, 4)
            tile(1, x / 8, y / 8 - 1, 5)
            return
         end
      else
         if reload > 0 then
            reload = reload - 1
         else
            enemy_bullet(rx - 4, ry - 4, 0, 4.5)
            if bs_destroyed_cannons > 2 then
               reload = 14
            elseif bs_destroyed_cannons > 1 then
               reload = 40
            else
               reload = 100
            end
         end
         if htm > 0 then
            htm = htm - 1
            entslot(e, 2, htm)
            tile(1, tx, ty, 6)
            tile(1, tx, ty - 1, 7)
            if htm == 0 then
               t_cnt = 20
            end
         else
            t_cnt = t_cnt + 1
            if t_cnt > 16 then
               t_cnt = 0
               local sx, _ = entpos(ship_e_1)
               sx = sx + 16
               if rx < sx - 24 then
                  tile(1, tx, ty, 1)
               elseif rx > sx + 24 then
                  tile(1, tx, ty, 2)
               else
                  tile(1, tx, ty, 3)
               end
               tile(1, tx, ty - 1, 8)
            end
         end
      end
   end
end

local bs_wpn_1 = bs_cannon(8, 8, 40)
local bs_wpn_2 = bs_cannon(24, 16, 80)
local bs_wpn_3 = bs_cannon(96, 16, 60)
local bs_wpn_4 = bs_cannon(112, 8, 100)


local bs_center = nil
local bs_hp = 45


function bs_mv(rate)
   if bs_dir_y then
      bs_y = bs_y + 0.1
   else
      bs_y = bs_y - 0.1
   end
   if bs_y > 15 or bs_y < 5 then
      bs_dir_y = not bs_dir_y
   end
   local speed = 0.5
   if bs_x < 15 or bs_x > 103 then
      speed = 0.20
   end
   speed = speed * rate
   if bs_dir_x then
      bs_x = bs_x - speed
   else
      bs_x = bs_x + speed
   end
   if bs_x < 10 or bs_x > 108 then
      bs_dir_x = not bs_dir_x
   end
end


local bs_dead = false
function bs_wait_after_death()
   bs_cnt = bs_cnt + 1
   fade(1 - bs_cnt / 40, 0xffffff)
   if bs_cnt > 40 then
      bs_dead = true
   end
end


function bs_die()
   bs_cnt = bs_cnt + 1
   local ox = (bs_x + 64) - 8
   local oy = (bs_y + 40) - 8

   bs_cnt2 = bs_cnt2 + 1
   if bs_cnt2 == 4 then
      bs_cnt2 = 0
      boom(ox, oy, 96)
   end

   if bs_cnt == 2 or bs_cnt == 6 or bs_cnt == 12 then
      boom(ox, oy, 64)
      boom(ox, oy, 64)
      shake_index = 2
   elseif bs_cnt == 9 or bs_cnt == 15 or bs_cnt == 20 then
      boom(ox, oy, 128)
      boom(ox, oy, 128)
      boom(ox, oy, 128)
      shake_index = 2
   end

   if bs_cnt > 24 then
      fade(1, 0xffffff)
      bs_x = 0
      bs_y = 170 -- offscreen
      boss = bs_wait_after_death
      bs_cnt = 0
   end
end


local bs_dmg_cnt = 0
function bs_ch_center()
   if bs_dmg_cnt > 0 then
      bs_dmg_cnt = bs_dmg_cnt - 1
      if bs_dmg_cnt == 0 then
         local t = 160
         for y = 0, 3 do
            for x = 0, 3 do
               tile(1, 6 + x, 3 + y, t)
               t = t + 1
            end
         end
      end
   end
   entpos(bs_center, bs_x, bs_y)
   local col = ecolt1(bs_center, 2)
   if col then
      entag(col, dead_tag)
      shake_index = 8
      local t = 176
      for y = 0, 3 do
         for x = 0, 3 do
            tile(1, 6 + x, 3 + y, t)
            t = t + 1
         end
      end
      bs_dmg_cnt = 4
      if bs_hp > 0 then
         bs_hp = bs_hp - 1
      end
      if bs_hp == 0 then
         bs_cnt = 0
         bs_cnt2 = 0
         for i = 0, 6 do
            clear() -- sleep a few frames
         end
         boss = bs_die
      end
   end
end



function bs_spray()
   bs_mv(5)
   bs_cnt = bs_cnt + 1
   if bs_cnt == 150 then
      bs_cnt = 0
      bs_cnt2 = 0
      boss = bs_main2
   end

   bs_cnt2 = bs_cnt2 + 1
   if bs_cnt2 == 14 then
      bs_cnt2 = 0
      local ox = (bs_x + 64) - 8
      local oy = (bs_y + 40) - 8
      local rot = 50 * math.random()
      if rot > 25 then
         rot = 360 - ((rot - 25) / 2)
      end
      enemy_bullet(ox, oy, rot, 5)
      effect(ox, oy, 10, 3, 4)
   end

   bs_ch_center()
end



function bs_after_laser()

   bs_mv(0.25)

   bs_cnt = bs_cnt + 1
   if bs_cnt > 8 then
      bs_cnt = 0
      bs_cnt3 = bs_cnt3 + 1
      if bs_cnt3 == 2 then
         bs_cnt2 = 0
         bs_cnt3 = 0
         boss = bs_spray
      else
         boss = bs_main2
      end
   end

   bs_ch_center()
end



function bs_laser()
   bs_mv(3)

   local ox = (bs_x + 64) - 8
   local oy = (bs_y + 40) - 8

   if bs_cnt == 40 then
      enemy_laser_begin(ox, oy, 30, 1)
      effect(ox, oy, 10, 3, 4)
   end

   if bs_cnt == 80 then
      enemy_bullet(ox, oy, 0, 1)
      effect(ox, oy, 10, 3, 4)
   end

   bs_cnt = bs_cnt + 1
   if bs_cnt == 120 then
      bs_cnt = 0
      bs_cnt2 = 0
      enemy_laser_begin(ox, oy, 0, 5)
      enemy_laser_begin(ox, oy, 90, 9)
      enemy_laser_begin(ox, oy, 360 - 90, 9)
      boss = bs_after_laser
   end

   bs_ch_center()
end


function bs_main2()
   bs_mv(1.75)

   if bs_cnt2 == 1 and bs_cnt == 50 then
      local ox = (bs_x + 64) - 8
      local oy = (bs_y + 40) - 8
      enemy_laser_begin(ox, oy, 0, 3)
      effect(ox, oy, 10, 3, 4)
   end

   bs_cnt = bs_cnt + 1
   if bs_cnt > 90 then
      bs_cnt = 0
      bs_cnt2 = bs_cnt2 + 1
      local ox = (bs_x + 64) - 8
      local oy = (bs_y + 40) - 8
      enemy_bullet(ox, oy, 35, 2)
      enemy_bullet(ox, oy, 0, 2)
      enemy_bullet(ox, oy, 325, 2)
      effect(ox, oy, 10, 3, 4)
      if bs_cnt2 == 2 then
         boss = bs_laser
      end
   end

   bs_ch_center()
end


function bs_after_open()

   bs_cnt = bs_cnt + 1
   if bs_cnt > 40 then
      bs_cnt = 0
      boss = bs_main2
   end


   bs_ch_center()

end


function bs_open()
   bs_cnt = bs_cnt + 1
   if bs_cnt > 25 then
      bs_cnt = 0
      boss = bs_after_open
      shake_index = 1
      -- Swap the texture out from under the tiles. Not to worry, the tile ids
      -- will be preserved!
      txtr(1, "tiles/boss1_form2.bmp")

      bs_center = ent()
      enthb(bs_center, -48, -36, 18, 10)
      entag(bs_center, 500)
   end
end


function bs_main()
   bs_mv(1)
   bs_wpn_1()
   bs_wpn_2()
   bs_wpn_3()
   bs_wpn_4()

   if bs_destroyed_cannons > 3 then
      bs_cnt = 0
      boss = bs_open
   end
end

boss = bs_main


-- Scene: ---------

local scn_cnt = 0
local scn_cnt2 = 0
local scn_cnt3 = false


local scene = nil

function scn_main()
   boss()
end


function scn_boss_easein()
   bs_y = bs_y + scn_cnt2
   scn_cnt2 = scn_cnt2 * 0.98

   scn_cnt = scn_cnt + 1
   if scn_cnt > 4 then
      scn_cnt = 0
      scn_cnt3 = not scn_cnt3
   end

   if bs_y > 10 then
      scene = scn_main
   end
end


function scn_warning()
   scn_cnt = scn_cnt + 1

   scn_cnt2 = scn_cnt2 + 1
   if scn_cnt2 > 15 then
      scn_cnt2 = 0
      if scn_cnt3 then
         for x = 0, 30 do
            tile(0, x, 4, 2)
            tile(0, x, 8, 2)
            tile(0, x, 5, 3)
            tile(0, x, 6, 3)
            tile(0, x, 7, 3)
         end
         print("WARNING: TARGET APPROACHING", 2, 6, 0x000020, 0xffa139)
      else
         for x = 0, 30 do
            tile(0, x, 6, 1)
            tile(0, x, 5, 1)
            tile(0, x, 4, 1)
            tile(0, x, 7, 1)
            tile(0, x, 8, 1)
         end
      end
      scn_cnt3 = not scn_cnt3
   end

   if scn_cnt > 150 then
      scn_cnt = 0
      scn_cnt2 = 1.5
      scn_cnt3 = false
      scene = scn_boss_easein
      bs_y = -60
      speed = 2.6
   end
end

function scn_ship_flyin()
   scn_cnt = scn_cnt + 1
   ship_move(0, -scn_cnt2)
   scn_cnt2 = scn_cnt2 * 0.90
   if scn_cnt > 25 then
      scn_cnt = 0
      scene = scn_warning
   end
end

scene = function()
   scn_cnt2 = 6
   scene = scn_ship_flyin
end


camera(120, 80)


-- Main loop: ---------


local last_score = 0
local score = 0

ship_move(120 - 16, 170)
speed = 0.8

local bkg_scroll = 0
local bkg_scroll1 = 0


while true do

   bkg_scroll = bkg_scroll - 4
   bkg_scroll1 = bkg_scroll1 - 2
   scroll(2, 0, bkg_scroll)
   scroll(3, 0, bkg_scroll1)
   scroll(1, -bs_x, -bs_y)

   scene()

   if btn(4) then
      if btn(6) then
         ship_move(-1.2, -1.2)
      elseif btn(7) then
         ship_move(-1.2, 1.2)
      else
         ship_move(-1.5, 0)
      end
   elseif btn(5) then
      if btn(6) then
         ship_move(1.2, -1.2)
      elseif btn(7) then
         ship_move(1.2, 1.2)
      else
         ship_move(1.5, 0)
      end
   elseif btn(6) then
      ship_move(0, -1.5)
   elseif btn(7) then
      ship_move(0, 1.5)
   end

   if reload > 0 then
      reload = reload - 1
   elseif btn(0) then
      gun()
   end

   if btnp(9) then
      print("EWRAM used: " .. tostring(collectgarbage("count") * 1024), 0, 19)
   end

   ship_move(0, 0)

   for i = #s_bullets, 1, -1 do
      local b = s_bullets[i]
      bullet_update_tab[1](b)
      if entag(b) == dead_tag then
         del(b)
         table.remove(s_bullets, i)
         ammo = ammo + 1
      end
   end

   for i = #e_bullets, 1, -1 do
      local b = e_bullets[i]
      if entag(b) == dead_tag then
         del(b)
         table.remove(e_bullets, i)
      else
         local i = entag(b) - 3 -- enemy bullets start at tag 4
         enemy_bullet_update_tab[i](b)
      end
   end

   if rline() < 160 then
      -- NOTE: lock the game to 30fps.
      clear()
   end
   clear()

   if score ~= last_score then
      print("sc:" .. score, 0, 0, 0x000010, 0xff4e39)
   end

   if shake_index > 0 then
      if shake_index == 11 then
         shake_index = 0
         camera(120, 80)
      else
         shake_index = shake_index + 1
         camera(120, 80 + shake_ints[shake_index])
      end
   end

   -- graphics updates here:

   display()

   last_score = score

   if player_dead or bs_dead then
      break
   end
end


if player_dead then
   for x = 0, 5 do
      clear()
   end
   local cnt = 0
   local sx, sy = entpos(ship_e_1)
   del(ship_e_1)
   del(ship_e_2)
   del(ship_e_3)
   del(ship_e_4)
   shake_index = 1

   local boom = function(range) boom(sx, sy, range) end

   while cnt < 80 do
      if cnt == 2 or cnt == 6 or cnt == 8 then
         boom(32)
         boom(32)
      end
      if cnt == 7 or cnt == 12 then
         boom(84)
         boom(84)
         boom(84)
      end
      if cnt == 40 then
         print("you died", 11, 8)
      end
      if shake_index > 0 then
         if shake_index == 11 then
            shake_index = 0
            camera(120, 80)
         else
            shake_index = shake_index + 1
            camera(120, 80 + shake_ints[shake_index])
         end
      end
      cnt = cnt + 1
      bkg_scroll = bkg_scroll - 4
      bkg_scroll1 = bkg_scroll1 - 2
      scroll(2, 0, bkg_scroll)
      scroll(3, 0, bkg_scroll1)
      scroll(1, -bs_x, -bs_y)
      clear()
      clear()
      display()
   end
   while cnt < 120 do
      cnt = cnt + 1
      fade((cnt - 80) / 40.0)
      bkg_scroll = bkg_scroll - 4
      bkg_scroll1 = bkg_scroll1 - 2
      scroll(2, 0, bkg_scroll)
      scroll(3, 0, bkg_scroll1)
      scroll(1, -bs_x, -bs_y)
      clear()
      clear()
      display()
   end

   print("press any button to reset...", 1, 11)
   while true do
      if btnp(0) or btnp(1) or btnp(8) or btnp(9) or btnp(10) or btnp(11) then
         break
      end
      clear()
      display()
   end
elseif bs_dead then
   local cnt = 0
   while true do
      cnt = cnt + 1
      if cnt < 80 then
         local sx, sy = entpos(ship_e_1)
         local dx = 0
         local dy = 0
         if sx > 120 - 16 then
            dx = -1
         elseif sx < 120 - 18 then
            dx = 1
         end
         if sy > 120 then
            dy = -1
         elseif sy < 117 then
            dy = 1
         end
         speed = 1
         ship_move(dx, dy)
      elseif cnt > 100 and cnt < 160 then
         local cx, cy = entpos(ship_e_1)

         local x = cx
         local y = cy - 3

         entpos(ship_e_1, x, y)
         entpos(ship_e_2, x + 16, y)
         entpos(ship_e_3, x, y + 16)
         entpos(ship_e_4, x + 16, y + 16)
      elseif cnt == 180 then
         print("Thanks for playing!", 6, 8)
      elseif cnt == 190 then
         -- NOTE: delta() overflows if not called for half an hour, but we're
         -- fine here.
         local micros = delta()
         local seconds = micros / 1000000
         local str = "Time: " .. math.floor(seconds) .. " seconds"
         print(str, (30 - string.len(str)) / 2, 10)
      end

      if cnt > 180 then
         if btnp(0) or btnp(1) then
            break
         end
      end

      bkg_scroll = bkg_scroll - 4
      bkg_scroll1 = bkg_scroll1 - 2
      scroll(2, 0, bkg_scroll)
      scroll(3, 0, bkg_scroll1)
      scroll(1, -bs_x, -bs_y)
      clear()
      clear()
      display()
   end
end


next_script("restart.lua")
