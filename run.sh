#!/bin/bash

set -e

function truncate_logs() {
  # Get the total number of bytes in the logs.
  local total=$(du -b ${logs}/dump_*.tgz | awk '{x += $1} END{print x}')
  # Don't truncate if we are under the limit.
  if [[ ${total} -le ${bytesMax} ]]; then
    return
  fi

  echo "$(date '+%Y-%m-%dT%H:%M:%SZ') Cleaning logs"
  # Go through the logs (in alphabetical order), deleting the oldest until
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

function output() {
  # Yes, this uses global variables: $f, $c to pass values.
  local d=$(date '+%Y-%m-%dT%H:%M:%SZ') # VMs are in UTC.
  echo "_BEGIN_ ${d} ${f}" | tee -a "${console}"
  echo "${c}"              | tee -a "${console}"
  echo "_END___ ${d} ${f}" | tee -a "${console}"
  echo "${c}"              > "${logs}/cur/${f}"

  if [[ ${useJournal} = 'y' ]]; then
    echo ${c} | systemd-cat -p notice -t "gke[${f}]"
  fi
}

oneShot=${oneShot:=n} # "y" runs the collector once.
# empty (disabled), irqs, scheduling, or full (see hook.sh)
ftraceMode=${ftraceMode:=""}
maxFtraces=${maxFtraces:=0}
intervalSecs=${intervalSecs:=60}
journalSocket=${journalSocket:=/run/systemd/journal/stdout}
hostdev=${hostdev:=/hostdev}
console=${hostdev}/console
logs=${logs:=/logs}
recordSysctl=${recordSysctl:=n} # "y" records sysctl settings.
reduceKernelHungTimeout=${recordSysctl:=n} # "y" reduces the hung task timeout to 20s

if [[ -z ${bytesMax} ]]; then
  bytesMax=$(( 250 * 1000 * 1000 )) # Maximum size of logs to keep around.
fi

if [[ -n "$ftraceMode" ]]; then
  source /hook.sh
fi

files="
  /proc/interrupts
  /proc/loadavg
  /proc/meminfo
  /proc/net/netstat
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

if [[ "${reduceKernelHungTimeout}" = "y" ]]; then
  sysctl -w kernel.hung_task_timeout_secs=20
fi

while true; do
  rm -f ${logs}/cur/*
  date '+%Y-%m-%dT%H:%M:%SZ' > "${logs}/cur/date.txt"

  # /proc
  for f in ${files}; do
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
  f=netstat
  c=$(netstat -s || true)
  output

  # tc
  f=tc
  c=$(tc -s qdisc show || true)
  output

  # top
  f=top
  c=$(top -b -n1)
  output

  # In each net ns
  for pid in $(lsns | grep \ net | awk '{print $4}'); do
    # netstat -s
    f=netstat_${pid}
    c=$(nsenter --net -t ${pid} netstat -s)
    output

    if [[ "${recordSysctl}" = "y" ]]; then
      # Record sysctl settings. these are not output to console/journal to
      # reduce spam.
      f=sysctl_${pid}
      c=$(nsenter --net -t ${pid} sysctl -a)
      echo "${c}" > "${logs}/cur/${f}"
    fi
  done

  # ethtool for every interface
  for iface in $(ip link | awk '/^[0-9]+: / {print $2}' | sed 's/:$//' | sed 's/@.*$//'); do
    f=ethtool_${iface}
    c=$(ethtool -S ${iface})
    output
  done

  # Ping kubelet for liveness
  f=kubelet_ping
  set +e
  if ! c=$(curl -m "5" -f -s -S http://127.0.0.1:10248/healthz 2>&1); then
    if [[ -n "$ftraceMode" ]]; then
      do_ftrace "${ftraceMode}" "${maxFtraces}"
    fi
  fi
  set -e
  output

  tar -czf "${logs}/dump_$(cat /${logs}/cur/date.txt).tgz" -C ${logs}/cur .

  truncate_logs

  if [[ ${oneShot} = 'y' ]]; then
    break
  fi

  sleep "${intervalSecs}"
done
