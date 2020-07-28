#!/bin/bash

# Performs an ftrace
# Arguments:
#   ftraceMode (empty to disable, irqs, scheduling, or full)
#   maximumTraces
function do_ftrace() {
  local ftraceMode="${1}"
  local maximumTraces="${2}"

  if [[ -z "${ftraceMode}" ]]; then
    return
  fi

  local outDir="/tmp/fdumps"
  nsenter -t 1 -m -u -i -n -p mkdir -p "${outDir}"

  local attemptsRemainingFile="/tmp/ftrace_attempts_left.txt"
  if [[ ! -f "${attemptsRemainingFile}" ]]; then
    echo "${maximumTraces}" > "${attemptsRemainingFile}"
  fi

  local attemptsRemaining
  attemptsRemaining=$(cat "${attemptsRemainingFile}")
  if [[ "${attemptsRemaining}" -eq 0 ]]; then
    return
  fi

  attemptsRemaining=$((attemptsRemaining-1))
  echo "${attemptsRemaining}" > "${attemptsRemainingFile}"

  d=$(date '+%Y-%m-%dT%H:%M:%SZ')
  f="do_ftrace_${ftraceMode}"

  echo "_BEGIN_ $d $f"  | tee -a "${console}"

  if [[ "${ftraceMode}" = "irqs" ]]; then
    nsenter -t 1 -m -u -i -n -p \
    trace-cmd record \
      -e "napi:napi_poll" \
      -e "net:napi_gro_receive_entry" \
      -e "net:napi_gro_receive_exit" \
      -e "irq:irq_handler_entry" \
      -e "irq:irq_handler_exit" \
      -e "irq:softirq_entry" \
      -e "irq:softirq_exit" \
      -e "irq:softirq_raise" \
      -o "${outDir}/${ftraceMode}_${d}.dat" \
      sleep 10
  elif [[ "${ftraceMode}" = "scheduling" ]]; then
      nsenter -t 1 -m -u -i -n -p \
      trace-cmd record \
      -e "sched:sched_wakeup" \
      -e "sched:sched_wakeup_new" \
      -e "sched:sched_switch" \
      -e "sched:sched_migrate_task" \
      -e "sched:sched_wait_task" \
      -e "sched:sched_process_wait" \
      -e "sched:sched_stat_runtime" \
      -o "${outDir}/${ftraceMode}_${d}.dat" \
      sleep 10
  elif [[ "${ftraceMode}" = "full" ]]; then
      nsenter -t 1 -m -u -i -n -p \
      trace-cmd record \
      -e "net" \
      -e "sock" \
      -e "tcp" \
      -e "syscalls" \
      -o "${outDir}/${ftraceMode}_${d}.dat" \
      sleep 10
  fi

  echo "_END___ $d $f"  | tee -a "${console}"
}
