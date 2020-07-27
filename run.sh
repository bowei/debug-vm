#!/bin/bash

set -e

function truncate_logs() {
  local total=$(du -b ${logs}/dump_*.tgz | awk '{x += $1} END{print x}')
  echo TOTAL $total
  if [[ ${total} -le ${bytesMax} ]]; then
    return
  fi

  echo "$(date '+%Y-%m-%dT%H:%M:%SZ') Cleaning logs"
  for f in ${logs}/dump_*.tgz; do
    local sz=$(du -b $f | awk  '{print $1}')
    rm ${f}
    echo "Removing ${f}"
    total=$(( ${total} - ${sz} ))
    if [[ ${total} -le ${bytesMax} ]]; then
      break
    fi
  done
}

oneShot=${oneShot:=n}
intervalSecs=${intervalSecs:=60}
journalSocket=${journalSocket:=/run/systemd/journal/stdout}
hostdev=${hostdev:=/hostdev}
console=${hostdev}/console
logs=${logs:=/logs}
if [[ -z ${bytesMax} ]]; then
  bytesMax=$(( 250 * 1000 * 1000 )) # Maximum size of logs to keep around.
fi

files="
  /proc/interrupts
  /proc/loadavg
  /proc/meminfo
  /proc/net/netstat
  /proc/net/snmp
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

mkdir -p ${logs}
mkdir -p ${logs}/cur

while true; do
  rm -f ${logs}/cur/*
  date '+%Y-%m-%dT%H:%M:%SZ' > "${logs}/cur/date.txt"

  # /proc
  for f in ${files}; do
    d=$(date '+%Y-%m-%dT%H:%M:%S')
    c=$(cat ${f} || true)
    echo "_BEGIN_ $d $f" | tee -a "${console}"
    echo "${c}"          | tee -a "${console}"
    echo "_END___ $d $f" | tee -a "${console}"
    cp ${f} ${logs}/cur/$(echo $f | sed 's+/+_+g')

    if [[ ${useJournal} = 'y' ]]; then
      echo ${c} | systemd-cat -p notice -t "gke[$f]"
    fi
  done

  # netstat
  d=$(date '+%Y-%m-%dT%H:%M:%S')
  f=netstat
  c=$(netstat -s || true)
  echo "_BEGIN_ $d $f"  | tee -a "${console}"
  echo "${c}"           | tee -a "${console}"
  echo "_END___ $d $f"  | tee -a "${console}"
  echo "${c}"           > "${logs}/cur/${f}"

  if [[ ${useJournal} = 'y' ]]; then
    echo ${c} | systemd-cat -p notice -t "gke[$f]"
  fi

  # tc
  d=$(date '+%Y-%m-%dT%H:%M:%S')
  f=tc
  c=$(tc -s qdisc show || true)
  echo "_BEGIN_ $d $f"  | tee -a "${console}"
  echo "${c}"           | tee -a "${console}"
  echo "_END___ $d $f"  | tee -a "${console}"
  echo "${c}"           > "${logs}/cur/${f}"

  if [[ ${useJournal} = 'y' ]]; then
    echo ${c} | systemd-cat -p notice -t "gke[$f]"
  fi

  tar -czf "${logs}/dump_$(cat /${logs}/cur/date.txt).tgz" -C ${logs}/cur .

  truncate_logs

  if [[ ${oneShot} = 'y' ]]; then
    break
  fi

  sleep "${intervalSecs}"
done
