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
  mkdir -p "${outDir}"

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

  local bufferSize="16384"
  local traceTime="4"

  if [[ "${ftraceMode}" = "irqs" ]]; then
    trace-cmd record \
      -e "napi:napi_poll" \
      -e "net:napi_gro_receive_entry" \
      -e "net:napi_gro_receive_exit" \
      -e "irq:irq_handler_entry" \
      -e "irq:irq_handler_exit" \
      -e "irq:softirq_entry" \
      -e "irq:softirq_exit" \
      -e "irq:softirq_raise" \
      -b "${bufferSize}" \
      -o "${outDir}/${ftraceMode}_${d}.dat" \
      sleep "${traceTime}"
  elif [[ "${ftraceMode}" = "scheduling" ]]; then
      trace-cmd record \
      -e "sched:sched_wakeup" \
      -e "sched:sched_wakeup_new" \
      -e "sched:sched_switch" \
      -e "sched:sched_migrate_task" \
      -e "sched:sched_wait_task" \
      -e "sched:sched_process_wait" \
      -e "sched:sched_stat_runtime" \
      -b "${bufferSize}" \
      -o "${outDir}/${ftraceMode}_${d}.dat" \
      sleep "${traceTime}"
  elif [[ "${ftraceMode}" = "full" ]]; then
      trace-cmd record \
      -e "net" \
      -e "sock" \
      -e "tcp" \
      -e "syscalls" \
      -b "${bufferSize}" \
      -o "${outDir}/${ftraceMode}_${d}.dat" \
      sleep "${traceTime}"
  fi

  echo "_END___ $d $f"  | tee -a "${console}"
}

# Performs an sysrq dump
function do_sysrq_dump() {
  # enable sysrq
  echo "1" > /proc/sys/kernel/sysrq

  # do the sysrq t; will dump to dmesg
  echo "t" > /proc/sysrq-trigger
}
