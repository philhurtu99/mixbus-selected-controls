local path=assert(os.getenv('MIXBUS_NATIVE_GUI_SESSION'))
assert(create_session(path,'NativeGUIVerification',48000))
local tracks=Session:new_audio_track(1,2,ARDOUR.RouteGroup(),3,'Native Control',1,ARDOUR.TrackMode.Normal,true)
local r={};for route in tracks:iter() do r[#r+1]=route end
local group=Session:new_route_group('Selected Pair')
group:set_select(true);group:add(r[1]);group:add(r[2])
Session:selection():clear_stripables()
for i=1,20 do
 Session:selection():select_next_stripable(true,true)
 if r[1]:is_selected() and r[2]:is_selected() then break end
end
Session:save_state('NativeGUIVerification',false,false,false)
for _,route in ipairs(r) do group:remove(route) end
tracks=nil;r=nil;group=nil;collectgarbage('collect')
close_session()
print('GUI verification session created')
