import socket
import msgpack

ip = '2001:470:4956:2:212:6d02::3012'
port = 1526

sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)


channels = ['motion_sensor_one'] #, 'advertisements']
for channel in channels:
    data = ['subscribeToChannel', [channel]]

    print("subscribing")
    sock.sendto(msgpack.packb(data), (ip, port))
    print("subscribed")

from twisted.internet.protocol import DatagramProtocol
from twisted.internet import reactor
import time


screens = ['2001:470:4956:2:212:6d02::302b']
disp2 = ['2001:470:4956:2:212:6d02::3016']

services = []
import datetime


class Listener(DatagramProtocol):
    def datagramReceived(self, data, addr):
        msg = msgpack.unpackb(data)
        print("{} -- Got message: {}\n From: {}".format(datetime.datetime.now(), msg, addr))
        if msg[0] == 'motion_sensor_one':
            # sock.sendto(msgpack.packb(['setInt', [7]]), (sound_ip, port))
            # sock.sendto(msgpack.packb(["setDisp", ["INTRUDER"]]),
            #             (disp2, port))

            for i in range(10):
                for screen in screens:
                    sock.sendto(msgpack.packb(["setScreenBG", [255, 0, 0]]),
                                (screen, port))
                    sock.sendto(msgpack.packb(["setString", ['Intruder!!!!']]),
                                (screen, port))
                time.sleep(.2)
                for screen in screens:
                    sock.sendto(msgpack.packb(["setScreenBG", [0, 0, 0]]),
                                (screen, port))

                time.sleep(.2)
            for screen in screens:
                sock.sendto(msgpack.packb(["setString", ['            ']]),
                            (screen, port))
            for screen in screens:
                sock.sendto(msgpack.packb(["setScreenBG", [0, 0, 0]]),
                            (screen, port))

            # sock.sendto(msgpack.packb(['setInt', [13]]), (sound_ip, port))
        elif msg[0] == 'advertisements':
            services = msg
            print(services)

l = Listener()
reactor.listenUDP(1526, l, interface='::')
reactor.run()
