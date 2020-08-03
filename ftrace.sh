#!/bin/bash

set -e

# Runs ftrace periodically and log the results to disk.

periodSecs=${periodSecs:=10}              # Run every 10 seconds.
logDir=${logDir:=/hostvar/debugvm/ftrace} # Where recorded output will go.
tracer=${tracer:=function} # function, function_graph
hostdev=${hostdev:=/hostdev}
console=${hostdev}/console

echo "Running periodic ftrace" | tee ${console}

while true; do
  startSecs=$(date '+%s')
  ts=$(date '+%Y-%m-%dT%H:%M:%SZ')
  out="${logDir}/ftrace_${ts}.dat"

  echo "Starting trace at ${ts} to ${out}" | tee ${console}

  set -x
  trace-cmd record \
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
done