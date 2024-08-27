#!/bin/bash

# Function to get current date-time stamp
get_date_time() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Define logging functions
log_info() {
    echo "$(get_date_time) INFO: $1"
}

log_error() {
    echo "$(get_date_time) ERROR: $1"
}

numProcessors=1
if [ $# -ne 0 ]
then
    if ! [[ "$1" =~ ^[0-9]+$ ]]
    then
        log_error "The number of processors must be an integer."
        exit 1
    fi
    numProcessors=$1
fi

referenceTime_CFD=1200
referenceTime_DSMC=1380
referenceTime_PICDSMC=310

speedupFactor=1.0
if [[ $numProcessors -eq 2 || $numProcessors -eq 3 ]]
then
    speedupFactor=1.5
elif [ "$numProcessors" -ge 4 ]; then
    speedupFactor=2.0
fi

# Function to display progress bar
display_bar() {
    local barWidth=20 progress=$1; shift
    local percent=$(( progress*barWidth/100 ))
    printf -v arrows "%*s" "$percent" ""; arrows=${arrows// />};
    printf "\r\e[K[%-*s] %3d%% %s" "$barWidth" "$arrows" "$progress" "$*"; 
}
progressRate=100 # Adjust this for faster or slower progress rate

# Function to simulate progress bar based on the sleep time
progress_bar() {
    local sleepTime=$1
    local increment=$((100 / progressRate))
    for ((i=increment; i<=100; i+=increment))
    do
        display_bar "$i" "$2"
        sleep "$sleepTime"
    done
}

module_handler() {
    local referenceTime=$1
    local commandBase=$2
    local logFileBase=$3
    local messageBase=$4
    for action in install resync
    do
        local sleepPeriod
        sleepPeriod=$(bc -l <<< "$referenceTime/$speedupFactor/$progressRate")
        progress_bar "$sleepPeriod" "$action $messageBase" &
        local currentDateTime
        currentDateTime=$(date '+%Y%m%d%H%M%S')
        ./build/"$action-$commandBase".sh "$numProcessors" > "$logFileBase-$action-$currentDateTime" 2>&1 
        local exit_status=$?
        wait %2
        if [ -n "$(jobs -p)" ]
        then
          disown
          pkill -P $$  > /dev/null 2>&1
        fi
        display_bar "100" "$action $messageBase"
        if [ "$exit_status" -eq 0 ]; then
            log_info "$action $messageBase SUCCESS with exit status: $exit_status"
        else
            log_error "$action $messageBase FAILED with exit status: $exit_status. Check $logFileBase-$action-$currentDateTime"
        fi
    done
}

install_and_sync_modules() {
    module_handler "$referenceTime_CFD" "CFD" "logCFD" "CFD module"
    wait -n
    module_handler "$referenceTime_DSMC" "DSMC" "logDSMC" "DSMC module"
    wait -n
    module_handler "$referenceTime_PICDSMC" "hybridPICDSMC" "logHybridPICDSMC" "hybrid PIC-DSMC module"
}

install_and_sync_modules
