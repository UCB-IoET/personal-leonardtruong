from twisted.internet.protocol import DatagramProtocol
from twisted.internet import reactor, task

import msgpack
import socket


class PubSubService(DatagramProtocol):
    def __init__(self, *args, **kwargs):
        self.channels = {}
        self.stable = {
            'id': 'pub_sub',
            'subscribeToChannel': {'s': 'sendString'},
            'publishToChannel': {'s': 'sendMixedVec'}
        }

    def sendError(self, msg, addr):
        print(msg)
        self.transport.write(msgpack.packb({'error': msg}), addr)

    def datagramReceived(self, data, addr):
        try:
            cmd = msgpack.unpackb(data)
        except:
            self.sendError('invalid msgpack', addr)
            return

        if len(cmd) != 2:
            self.sendError('wrong number of arguments', addr)
            return

        cmd[0] = cmd[0].decode(encoding='utf-8')
        print("receieved {0} from {1}".format(cmd, addr))
        if cmd[0] not in {'subscribeToChannel', 'publishToChannel'}:
            self.sendError('method {0} not advertised'.format(cmd[0]), addr)

        if cmd[0] == 'subscribeToChannel':
            self.add_subscriber(cmd[1], addr)
        elif cmd[0] == 'publishToChannel':
            self.publish_mssage(*cmd[1])

    def add_subscriber(self, channel, addr):
        if channel not in self.channels:
            self.channels[channel] = []
        self.channels[channel].append(addr)

    def publish_message(self, channel, msg):
        if channel not in self.channels:
            # Don't publish to non existing channel
            # TODO: Should there be a message?
            return
        for subscriber in self.channels[channel]:
            self.transport.write(
                msgpack.packb({'channel': channel, 'message': msg}),
                subscriber)

service = PubSubService()
sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
print('ADVERTISING', service.stable)


def dobcast():
    try:
        sock.sendto(msgpack.packb(service.stable), ('ff02::1', 1525))
    except Exception as e:
        print('error durring broadcasting', e)


reactor.listenUDP(1526, service, interface='::')

bcast = task.LoopingCall(dobcast)
bcast.start(10)

reactor.run()
