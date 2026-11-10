local path=assert(os.getenv('MIXBUS_NATIVE_TEST_SESSION'))
assert(create_session(path,'NativeControlsTest',48000))
local tracks=Session:new_audio_track(1,2,ARDOUR.RouteGroup(),3,'Native Link Test',1,ARDOUR.TrackMode.Normal,true)
local r={};for route in tracks:iter() do r[#r+1]=route end
assert(#r==3)
local group=Session:new_route_group('Selected Pair')
group:set_select(true);group:add(r[1]);group:add(r[2])
Session:selection():clear_stripables()
for i=1,20 do
 Session:selection():select_next_stripable(true,true)
 if r[1]:is_selected() and r[2]:is_selected() then break end
end
assert(r[1]:is_selected() and r[2]:is_selected() and not r[3]:is_selected(),'selection fixture')
local use=PBD.GroupControlDisposition.UseGroup
local no=PBD.GroupControlDisposition.NoGroup
local checks,updates=0,0
local function close(a,b) return math.abs(a-b)<1e-5*math.max(1,math.abs(a),math.abs(b)) end
local function check(a,b,c,name)
 if a:isnil() or b:isnil() then return end
 local untouched=not c:isnil() and c:get_value() or nil
 for step=1,5 do
  local value=a:lower()+(a:upper()-a:lower())*(step/6)
  a:set_value(value,use)
  assert(close(a:get_value(),b:get_value()),name..' did not follow: '..a:get_value()..' / '..b:get_value())
  if untouched then assert(c:get_value()==untouched,name..' changed unselected channel') end
  updates=updates+1
 end
 checks=checks+1
 print('PASS',name)
end
local kinds=ARDOUR.WellKnownCtrl
for _,name in ipairs({'EQ_BandGain','EQ_BandFreq','EQ_BandQ','EQ_BandShape'}) do
 for band=0,3 do
  check(r[1]:mapped_control(kinds[name],band),r[2]:mapped_control(kinds[name],band),r[3]:mapped_control(kinds[name],band),name..' '..band)
 end
end
for _,name in ipairs({'EQ_Enable','HPF_Enable','HPF_Freq','HPF_Slope','LPF_Enable','LPF_Freq','LPF_Slope','Comp_Enable','Comp_Threshold','Comp_Makeup','Comp_Ratio','Comp_Attack','Comp_Release','Comp_KeyFilterFreq','Comp_Mix','Comp_Lookahead','Comp_FastAttack','Gate_Enable','Gate_Threshold','Gate_Attack','Gate_Hold','Gate_Release','Gate_Depth','Gate_Hysteresis','Gate_Ratio','Gate_KeyFilterFreq','Gate_KeyFilterEnable','Gate_Lookahead','Gate_FastAttack','DeEss_Enable','DeEss_Threshold','DeEss_Attack','DeEss_EssDepth','DeEss_EssFreq','DeEss_HiDepth','DeEss_HiFreq','Denoise_Enable','Denoise_Threshold','Denoise_DepthLow','Denoise_DepthHigh','TapeDrive_Drive'}) do
 if kinds[name] then check(r[1]:mapped_control(kinds[name],0),r[2]:mapped_control(kinds[name],0),r[3]:mapped_control(kinds[name],0),name) end
end
for bus=0,11 do
 check(r[1]:send_level_controllable(bus),r[2]:send_level_controllable(bus),r[3]:send_level_controllable(bus),'Send gain '..bus)
 check(r[1]:send_enable_controllable(bus),r[2]:send_enable_controllable(bus),r[3]:send_enable_controllable(bus),'Send enable '..bus)
end
check(r[1]:pan_azimuth_control(),r[2]:pan_azimuth_control(),r[3]:pan_azimuth_control(),'Pan position')
check(r[1]:trim_control(),r[2]:trim_control(),r[3]:trim_control(),'Trim')
-- Match plugin identity/occurrence even if processor positions differ.
local function add_plugin(route,uri)
 local proc=ARDOUR.LuaAPI.new_plugin(Session,uri,ARDOUR.PluginType.LV2,'')
 assert(not proc:isnil(),'missing test plugin '..uri)
 assert(route:add_processor_by_index(proc,-1,nil,true)==0,'cannot insert test plugin')
 return proc
end
local unrelated=add_plugin(r[2],'urn:ardour:a-comp')
local plugins={}
for i=1,3 do plugins[i]=add_plugin(r[i],'urn:ardour:a-eq') end
local param=Evoral.Parameter(ARDOUR.AutomationType.PluginAutomation,0,3)
local pc={}
for i=1,3 do pc[i]=plugins[i]:to_automatable():automation_control(param,false) end
check(pc[1],pc[2],pc[3],'Plugin identity with different processor positions')
-- Reverb parameters use the same identity/port mapping as EQ inserts.
local reverbs={}
for i=1,3 do reverbs[i]=add_plugin(r[i],'urn:ardour:a-reverb') end
for port=4,8 do
 local rp=Evoral.Parameter(ARDOUR.AutomationType.PluginAutomation,0,port)
 check(reverbs[1]:to_automatable():automation_control(rp,false),reverbs[2]:to_automatable():automation_control(rp,false),reverbs[3]:to_automatable():automation_control(rp,false),'ACE Reverb port '..port)
end
reverbs=nil;collectgarbage('collect')
local second={}
for i=1,2 do second[i]=add_plugin(r[i],'urn:ardour:a-eq') end
local sa=second[1]:to_automatable():automation_control(param,false)
local sb=second[2]:to_automatable():automation_control(param,false)
local first_value=pc[2]:get_value()
sa:set_value(3.0,use)
assert(close(sb:get_value(),3.0),'second plugin occurrence did not follow')
assert(pc[2]:get_value()==first_value,'wrong occurrence of plugin changed')
print('PASS repeated plugin occurrence matching')
local original_config=ARDOUR.config():get_implicit_selection_op_groups()
ARDOUR.config():set_implicit_selection_op_groups(false)
sa:set_value(4.0,use)
assert(close(sb:get_value(),3.0),'quick-group preference ignored')
ARDOUR.config():set_implicit_selection_op_groups(original_config)
print('PASS quick-group preference disables native link')
plugins=nil;pc=nil;second=nil;sa=nil;sb=nil;unrelated=nil;collectgarbage('collect')
local a=r[1]:mapped_control(kinds.EQ_BandGain,0)
local b=r[2]:mapped_control(kinds.EQ_BandGain,0)
a:set_value(.5,use)
a:set_value(.6,no)
assert(close(b:get_value(),.5),'NoGroup override ignored')
a:set_value(.65,use);assert(close(b:get_value(),.65),'link after override')
b:set_automation_state(ARDOUR.AutoState.Play)
a:set_value(.7,use);assert(close(b:get_value(),.65),'automated target changed')
b:set_automation_state(ARDOUR.AutoState.Off)
Session:selection():clear_stripables()
a:set_value(.8,use);assert(close(b:get_value(),.65),'deselection ignored')
print('PASS NoGroup override, target automation, deselection')
for _,route in ipairs(r) do group:remove(route) end
tracks=nil;r=nil;group=nil;a=nil;b=nil;collectgarbage('collect')
close_session()
print('ALL TESTS PASSED:',checks,'controls;',updates,'synchronous updates; clean teardown')
io.stdout:flush()
