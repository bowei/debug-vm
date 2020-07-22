#!/bin/bash

set -e

oneShot=${oneShot:=n}
intervalSecs=${intervalSecs:=60}
journalSocket=${journalSocket:=/run/systemd/journal/stdout}
hostdev=${hostdev:=/hostdev}

files="
  /proc/interrupts
  /proc/loadavg
  /proc/meminfo
  /proc/net/softnet_stat
  /proc/slabinfo
  /proc/softirqs
  /proc/stat
  /proc/vmstat
  "

useJournal=n
if [[ -e ${journalSocket} ]]; then
  useJournal=y
fi

if [[  "$1" = '-oneShot' ]]; then
  oneShot=y
fi

while true; do
  # /proc
  for f in ${files}; do
    d=$(date '+%Y-%m-%dT%H:%M:%S')
    c=$(cat ${f} || true)
    echo "_BEGIN_ $d $f" | tee -a "${hostdev}"/console
    echo "${c}"          | tee -a "${hostdev}"/console
    echo "_END___ $d $f" | tee -a "${hostdev}"/console

    if [[ ${useJournal} = 'y' ]]; then
      echo ${c} | systemd-cat -p notice -t "gke[$f]"
    fi
  done

  # netstat
  d=$(date '+%Y-%m-%dT%H:%M:%S')
  f=netstat
  c=$(netstat -s || true)
  echo "_BEGIN_ $d $f"  | tee -a "${hostdev}"/console
  echo "${c}"           | tee -a "${hostdev}"/console
  echo "_END___ $d $f"  | tee -a "${hostdev}"/console
  if [[ ${useJournal} = 'y' ]]; then
    echo ${c} | systemd-cat -p notice -t "gke[$f]"
  fi

  if [[ ${oneShot} = 'y' ]]; then
    break
  fi

  sleep "${intervalSecs}"
done
