
local app = {
   name = "HyperWing",

   tilesets = {
      "overlay/overlay.bmp",
      "tiles/tilesheet.bmp",
      "tiles/boss1.bmp",
      "tiles/boss1_form2.bmp"
   },

   spritesheets = {
      "sprites/spritesheet.bmp",
   },

   audio = {
   },

   scripts = {
      "main.lua",
      "boss1.lua",
      "restart.lua",
   },

   misc = {

   }
}

return app
