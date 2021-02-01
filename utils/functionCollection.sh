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
