require("cord")
require("storm")
LCD = require("lcd")
sh = require("stormsh")

blue_count = 0

storm.io.set_mode(storm.io.INPUT, storm.io.D3)

cport = 49152

csock = storm.net.udpsocket(
  cport, function(payload, from, port) end)

local svc_manifest = {id="HW-Defined-SW",
                      publishToChannel={ s="sendMessage"},
                      subscribeToChannel={ s="subscribe"}}

local channel_subscribers = {}


local msg = storm.mp.pack(svc_manifest)
storm.os.invokePeriodically(5*storm.os.SECOND, function()
                            storm.net.sendto(csock, msg, "ff02::1", 1525)
end)

local server_port = 1525
local services = {}
local devices = {}

function server_handler(payload, from, port)
  local message = storm.mp.unpack(payload)
  if message.id == nil then
     print("Malformed message")
     return
  end
  devices[message.id] = {ip=from, 
                         port=port, 
                         last_ping=storm.os.now(storm.os.SHIFT_0)}
  for k,v in pairs(message) do
     if k ~= "id" then
        if services[k] == nil then
           local d = {}
           d[message.id] = devices[message.id]
           services[k] = {s=v.s, desc=v.desc, devices=d}
        else
           if services[k].devices[message.id] == nil then
              services[k].devices[message.id] = devices[message.id]
           end
        end
     end
  end
  print(string.format("discovered %s ip: %s port %d", message.id, from, port))
  print("------------------")
  print("Available services")
  for k,v in pairs(services) do
     print("service: ", k)
     print("devices:")
     for k,v in pairs(v.devices) do
        print(k)
     end
  end
  print("------------------")
end
server_sock = storm.net.udpsocket(server_port, server_handler)

local service_port = 1526
function service_handler(payload, from, port)
   local message = storm.mp.unpack(payload)
   print(message)
   if #message ~= 2 then
      print("Malformed message")
      response = {1, "Error: Malformed Message, should be length 2"}
   else
     local action = message[1]
     print("Received action", action)
     if action == 'publishToChannel' then
        local channel = message[2][1]
        local subscribers = channel_subscribers[channel]
        if subscribers then
          for subscriber, ip in pairs(subscribers) do
             print(ip)
             local msg = storm.mp.pack(message[2])
             storm.net.sendto(service_sock, msg, ip, 1526)
          end
        end
        response = {0, "Success"}
     elseif action == 'subscribeToChannel' then
        local channel = message[2][1]
        local entry = channel_subscribers[channel]
        if not entry then
           entry = {}
           channel_subscribers[channel] = entry
        end
        entry[from] = from
        response = {0, "Success"}
     else
        print("Malformed request")
        response = {2, "Error: Unknown action"}
     end
   end
   resp = storm.mp.pack(response)
   storm.net.sendto(service_sock, resp, from, service_port)
end

service_sock = storm.net.udpsocket(1526, service_handler)

storm.os.invokePeriodically(storm.os.SECOND * 5, function ()
  local channel = 'advertisements'
  local subscribers = channel_subscribers[channel]
  if subscribers then
    for subscriber, ip in pairs(subscribers) do
      print(subscriber)
       local msg = storm.mp.pack({channel, services})
       storm.net.sendto(service_sock, msg, ip, 1526)
    end
  end
end)

pub_sub_server_ip = storm.os.getipaddrstring()
-- cord.new(function()
  -- lcd = LCD:new(storm.i2c.EXT, 0x7c, storm.i2c.EXT, 0xc4)
  -- lcd:init(2, 1)
  -- lcd:setBackColor(0, 0, 0)
  -- movement = false
  -- blue_count = 0
  -- red_count = 0
  -- storm.io.watch_all(storm.io.RISING, storm.io.D3, function()
  --   blue_count = 255
  -- end)
  -- subscribe = storm.mp.pack({"subscribeToChannel", "motion_sensor_one"})
  -- channel_subscribers['motion_sensor_one'] = {'fe80::212:6d02:0:302b'}
  -- storm.net.sendto(csock, subscribe, 'fe80::212:6d02:0:302b', 1526)
  -- service_sock = storm.net.udpsocket(1527, function(payload, from, port)
  --   message = storm.mp.unpack(payload)
  --   if from == pub_sub_server_ip and message[0] == "motion_sensor_one" then
  --     print("Got message from motion sensor")
  --     -- red_count = 255
  --   end
  -- end)
  -- while true do
  --   if blue_count > 0 then
  --     blue_count = blue_count - 1
  --   end
  --   -- if red_count > 0 then
  --   --   red_count = red_count - 1
  --   -- end
  --   lcd:setBackColor(red_count, 0, blue_count)
  --   cord.await(storm.os.invokeLater, storm.os.MILLISECOND * 10)
  -- end 
-- end)

sh.start()
cord.enter_loop()
