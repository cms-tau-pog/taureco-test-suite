#!/usr/bin/env bash

## Detect if the script is being sourced
#mklement0 https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
([[ -n $ZSH_EVAL_CONTEXT && $ZSH_EVAL_CONTEXT =~ :file$ ]] ||
[[ -n $KSH_VERSION && $(cd "$(dirname -- "$0")" &&
printf '%s' "${PWD%/}/")$(basename -- "$0") != "${.sh.file}" ]] ||
[[ -n $BASH_VERSION ]] && (return 0 2>/dev/null)) && export sourced=1 || export sourced=0

if [[ $sourced == 0 ]]; then
    echo "This is a function library, not a script. Source me!"
    exit 1
fi

if [[ -z $1 ]]; then
    echo "Source me with project name (existing or new)!"
    return 1
fi
export TS_PROJECT_NAME=$1

cd $(dirname "${BASH_SOURCE[0]}")
export TS_DIR=$PWD

#Load functions
source utils/helper_functions.sh
source utils/user_ts_functions.sh
source utils/internal_ts_functions.sh

#Make sure that projects directory exists
[ ! -d projects ] && mkdir projects

#Check whether project exists. If not, create it.
if [ -d projects/$TS_PROJECT_NAME ]; then
    source projects/$TS_PROJECT_NAME/project_metadata.sh
    cd projects/$TS_PROJECT_NAME/dev/$TS_CMSSW_BUILD/src
    cmsenv
    #workaround for checking that cmsenv works and build is not deprecated. (because it always returns 0)
    if [[ $TS_CMSSW_BUILD =~ 20[0-9][0-9]-[0-1][0-9]-[0-3][0-9]-[0-2][0-9]00 ]]; then
        ls /cvmfs/cms-ib.cern.ch/week*/*/cms/cmssw*/$CMSSW_BUILD > /dev/null
        if [[ $? -ne 0 ]]; then
            logerror "Setting up CMSSW failed. Your current build is probably outdated (check above). If this is the case, you may want to run ts_checkout_new_cmssw_build in order to check out a new build and transfer your local developments."
        fi
    fi

    #check remote and branch
    git remote | grep "^$TS_CMSSW_REMOTE$" > /dev/null
    if [[ $? -ne 0 ]]; then
        logwarn "Project remote is not registered in git of current setup!"
    fi
    git branch | grep "^* $TS_CMSSW_BRANCH$" > /dev/null
    if [[ $? -ne 0 ]]; then
       	logwarn "The branch currently checked out differs from the project branch!"
    fi
else
    read -p "$TS_PROJECT_NAME does not exist. Do you want to create it? [Y/y]" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        loginfo "Creating new project $TS_PROJECT_NAME ..."
        mkdir projects/$TS_PROJECT_NAME
        mkdir projects/$TS_PROJECT_NAME/dev
        mkdir projects/$TS_PROJECT_NAME/ref
        mkdir projects/$TS_PROJECT_NAME/log

        export TS_CMSSW_BUILD=CMSSW_11_3_X_$(date -d "yesterday" +"%Y-%m-%d")-2300
        read -p "Please enter custom CMSSW build if required (default=${TS_CMSSW_BUILD}):" -r
        if [[ ! -z $REPLY ]]; then
            export TS_CMSSW_BUILD=$REPLY
        fi
        _ts_setup_cmssw
        if [[ $? -ne 0 ]]; then
            logwarn "Aborting project creation..."
            cd $TS_DIR
            rm -rf $TS_DIR/projects/$TS_PROJECT_NAME
            unset TS_PROJECT_NAME
            return 1
        fi

        read -p "Please enter packages to be added (<SUBSYSTEM1/PACKAGE1> <SUBSYSTEM2/PACKAGE2> ...):" -r
        TS_CMSSW_PACKAGES_TEMP=$REPLY
        read -p "Please enter owner of remote fork to be used (default=cms-tau-pog):" -r
        if [[ -z $REPLY ]]; then
            export TS_CMSSW_REMOTE="cms-tau-pog"
        else
            export TS_CMSSW_REMOTE=$REPLY
        fi
        read -p "Please enter branch to be used:" -r
        export TS_CMSSW_BRANCH=$REPLY

        loginfo "Setting up local code packages..."
        git cms-init
        export TS_CMSSW_PACKAGES=""
        for PACKAGE in $TS_CMSSW_PACKAGES_TEMP; do
            git cms-addpkg $PACKAGE
            if [[ $? -eq 0 ]]; then
                export TS_CMSSW_PACKAGES="$TS_CMSSW_PACKAGES $PACKAGE"
            else
                logwarn "CMSSW package $PACKAGE could not be added. Removed it from list. Run 'add_package <SUBSYSTEM/PACKAGE> to try again."
            fi
        done
        git remote add $TS_CMSSW_REMOTE git@github.com:${TS_CMSSW_REMOTE}/cmssw.git
        logattn "Fetching contents from remote. Credentials required!"
        git fetch $TS_CMSSW_REMOTE
        if [[ $? -eq 0 ]]; then
            git checkout --track $TS_CMSSW_REMOTE/$TS_CMSSW_BRANCH
            if [[ $? -ne 0 ]]; then
                logerror "Branch $TS_CMSSW_BRANCH not available on ${TS_CMSSW_REMOTE}! Use ts_set_branch to switch to a different branch."
                export TS_CMSSW_BRANCH=INVALID
            fi
        else
            logerror "Remote fork $TS_CMSSW_REMOTE is not available! Use ts_set_remote to switch to a different remote."
            export TS_CMSSW_REMOTE=INVALID
            export TS_CMSSW_BRANCH=INVALID
        fi

        _ts_save_metadata
    else
        return 0
    fi
fi

loginfo Following functions are provided: $( grep -E  '^function ts_.*{' $TS_DIR/utils/user_ts_functions.sh | sed "s@function \(\w\+\).*@\1@" | tr "\n" " " )
