#!/bin/bash

### cpumemlog.sh
### ----------------------------------------------------------------------------

NAME=$(basename $0)

usage()
{
    cat <<EOF
  NAME
    $NAME - Monitor CPU and RAM usage for a given process (and its children)

  SYNOPSIS
    $NAME pid [string] [-t=1]

  DESCRIPTION
    pid
      ID of a process that will be monitored; must be the FIRST argument

    string
      A string to be added to the output file name to help distinguishing
      several output files; if used it must be the SECOND argument of a call

    -t=x, --time=x
      Collect information in time intervals equal to x; this is passed to the
      sleep command so check its documentation on the format of x; default is
      10 seconds.
    
    -o=<path>, --out=<path>
      Specify filename of output file. Defaults to cpumemlog_<pid>[_string].txt

    -h, --help
      Print this output

  EXAMPLE
    Monitor process with process ID 123 and put this script into background
    to be able to work further in this terminal:

      $NAME 123 &

    ... and add a string JOB to the output:

      $NAME 123 JOB &

    ... and collect information every 2 seconds:

      $NAME 123 JOB -t=2 &

  AUTHOR
    Gregor Gorjanc <gregor dot gorjanc at gmail dot com>

  WEB
    http://github.com/gregorgorjanc/cpumemlog

EOF
}

## Defaults
TIME=10

## Get options
for OPTION in $@; do
  case "$OPTION" in
    -h | --help )
      usage
      exit 0
      ;;
    -t=* | --time=*)
      TIME=$(echo $OPTION | sed -e "s/--time=//" -e "s/-t=//")
      ;;
    -o=* | --out=*)
      FOUT=$(echo $OPTION | sed -e "s/--out=//" -e "s/-o=//")
      ;;
  esac
done

## Collect PID and STRING
if [ "$1" == "" ]; then
  echo "Missing PID!"
  usage
  exit 1
else
  PID=$1
fi

if [ "$2" == "" ]; then
  STR="${PID}"
else
  STR="${PID}_${2}"
fi

if [ -z $FOUT ]; then
  FOUT=cpumemlog_${STR}.txt
fi

rm -f $FOUT
echo "DATE TIME PID PCPU PMEM RSS VSZ ETIME COMMAND" >> $FOUT

printOut()
{
  local PID
  PID=$1

  ## Print everything except the header
  ## echo `date +"%Y-%m-%d %H:%M:%S"` `aps -p $PID -o pid= -o pcpu= -o pmem= -o rss= -o vsz= -o time= -o comm= --no-headers -w -w` >> $FOUT
  ## BSD always prints the header
  echo `date +"%Y-%m-%d %H:%M:%S"` `ps -p $PID -o pid= -o pcpu= -o pmem= -o rss= -o vsz= -o time= -o comm= -w -w | tail -n 1` >> $FOUT

  ## Any children?
  PIDC=$(pgrep -P $PID)
  for child in $PIDC; do
    printOut $child
  done
}

DO="yes"
while [ "$DO" == "yes" ]; do
  ## Is process running?
  WC=$(ps u -p $PID | wc -l | awk '{ print $1 }')
  if [ "$WC" != "1" ]; then
    printOut $PID
    sleep $TIME
  else
    DO="no"
  fi
done

echo -e "\n$0 for $STR finnished\n"

###----------------------------------------------------------------------------
### cpumemlog.sh ends here
