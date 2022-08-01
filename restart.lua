
for _, e in ipairs(ents()) do
   del(e)
end

-- just in case...
scroll(0, 0, 0)
scroll(1, 0, 0)
scroll(2, 0, 0)
scroll(3, 0, 0)

next_script("main.lua")
