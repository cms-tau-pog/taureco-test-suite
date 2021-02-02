# colored output for viewing logs
LESS=-R
function loginfo {
    echo -e "\e[46m[INFO]\e[0m" $( date +"%y-%m-%d %R" ): $@ #| tee -a $( pwd )/output/log/logandrun/event.log
}
function logwarn {
    echo -e "\e[45m[WARN]\e[0m" $( date +"%y-%m-%d %R" ): $@ #| tee -a $( pwd )/output/log/logandrun/event.log
}
function logerrormsg {
    echo -e "\e[41m[ERROR]\e[0m" $( date +"%y-%m-%d %R" ): $@ #| tee -a $( pwd )/output/log/logandrun/event.log
}
function logerror {
    logerrormsg $@
    return 1
}

# run with logfiles
function logandrun() { #first argument=command; second argument=logfilename
    # check if this is the top level logandrun script, so multiple notifications can be supressed
    if [[ -z $LOGANDRUN_TOPLEVELSET ]]; then
        export LOGANDRUN_TOPLEVELSET=1
        LOGANDRUN_IS_TOP_LEVEL=1
    fi
    # set the name of the logfile based on the command
    logfile=${2}.log
    # print the startmessage and log it
    echo -e "\e[43m[RUN]\e[0m" $( date +"%y-%m-%d %R" ): $1 | tee -a $( pwd )/output/log/logandrun/event.log | tee -a $logfile
    # evaluate the current date in seconds as the start date
    start=`date +%s`
    #######
    # execute the command and log it
    (
    $1 2>&1 |  tee -a $logfile
    )
    # capture the return code ( without  pipefail this would be the exit code of tee )
    return_code=$?
    end=`date +%s`
    # evaluate the end data
    # if the there was no error...
    if [[ $return_code == 0 ]]; then
        # print the message and log it
        echo -e "\e[42m[COMPLETE]\e[0m" $( date +"%y-%m-%d %R" ): $1 "     \e[104m{$((end-start))s}\e[0m" | tee -a $( pwd )/output/log/logandrun/event.log | tee -a $logfile
    else
        # print a message with the return code
        logerrormsg Error Code $return_code  $1 "     \e[104m{$((end-start))s}\e[0m"  | tee -a $( pwd )/output/log/logandrun/event.log | tee -a $logfile
    fi
    if [[ $LOGANDRUN_IS_TOP_LEVEL==1 ]]; then
        unset LOGANDRUN_TOPLEVELSET
        unset LOGANDRUN_IS_TOP_LEVEL
    fi
    return $return_code
}
