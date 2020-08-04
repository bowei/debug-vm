#!/bin/bash

set -e

# Runs ftrace periodically and log the results to disk.

periodSecs=${periodSecs:=10} # Run every 10 seconds.
logDir=${logDir:=/hostvar/debugvm/ftrace} # Where recorded output will go.
tracer=${tracer:=function} # function, function_graph
hostdev=${hostdev:=/hostdev}
console=${hostdev}/console
if [[ -z "${bytesMax}" ]]; then
  bytesMax=$((2500 * 1000 * 1000)) # Keep 2.5 Gb of dumps by default
fi

function truncate() {
  # Get the total number of bytes in the logs.
  local total=$(du -b ${logs}/ftrace_*.dat | awk '{x += $1} END{print x}')
  # Don't truncate if we are under the limit.
  if [[ ${total} -le ${bytesMax} ]]; then
    return
  fi

  echo "$(date '+%Y-%m-%dT%H:%M:%SZ') Cleaning logs"
  # Go through the logs (in alphabetical order), deleting the oldest until
  for f in ${logs}/ftrace_*.dat; do
    local sz=$(du -b $f | awk  '{print $1}')
    rm ${f}
    echo "Removing ${f}"
    total=$(( ${total} - ${sz} ))
    if [[ ${total} -le ${bytesMax} ]]; then
      break
    fi
  done
}

## main()
echo "Running periodic ftrace" | tee ${console}

mkdir -p "${logDir}"

while true; do
  startSecs=$(date '+%s')
  ts=$(date '+%Y-%m-%dT%H:%M:%SZ')
  out="${logDir}/ftrace_${ts}.dat"

  echo "Starting trace at ${ts} to ${out}" | tee ${console}

  set -x
  /usr/bin/trace-cmd record \
    --date \
    -e "irq:softirq_entry" -f "vec==3||vec==2" \
    -e "irq:softirq_exit"  -f "vec==3||vec==2" \
    -e "irq:softirq_raise" -f "vec==3||vec==2" \
    -e "napi:napi_poll" \
    -e "net:napi_gro_receive_entry" \
    -l "refill_work" \
    -l "skb_recv_done" \
    -l "try_fill_recv" \
    -p "${tracer}" \
    -b "16384" \
    -o "${out}" \
    sleep 5
  set +x

  sleep 15

  nowSecs=$(date '+%s')
  deltaSecs=$(( ${periodSecs} - (${nowSecs} - ${startSecs}) ))
  if [[ "${deltaSecs}" -gt 0 ]]; then
    echo "Sleeping for ${deltaSecs}s" | tee ${console}
    sleep ${deltaSecs}
  else
    echo "Trace is longer than period (${deltaSecs}s)" | tee ${console}
  fi

  truncate
done
