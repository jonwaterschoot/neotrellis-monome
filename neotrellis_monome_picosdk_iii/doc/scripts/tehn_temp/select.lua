scripts = {
  'intervals.lua',
  'mp.lua',
  'wake.lua'
}

grid_led_all(0)
for i=1,#scripts do grid_led(i,1,15) end
grid_refresh()

event_grid = function(x,y,z)
  if z==1 and y==1 then
    if scripts[x] then
      print("loading: "..scripts[x])
      grid_led(x,1,4)
      grid_refresh()
      require(scripts[x])
    end
  end
end

