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
export PROJECT_NAME=$1

cd $(dirname "${BASH_SOURCE[0]}")
export TESTSUITEDIR=$PWD

#Load functions
source utils/helper_functions.sh
source utils/user_ts_functions.sh
source utils/internal_ts_functions.sh

#Make sure that projects directory exists
[ ! -d projects ] && mkdir projects

#Check whether project exists. If not, create it.
if [ -d projects/$PROJECT_NAME ]; then
    source projects/$PROJECT_NAME/project_metadata.sh
    cd projects/$PROJECT_NAME/dev/$CMSSW_BUILD/src
    cmsenv
    #workaround for checking that cmsenv works and build is not deprecated. (because it always returns 0)
    if [[ $CMSSW_BUILD =~ 20[0-9][0-9]-[0-1][0-9]-[0-3][0-9]-[0-2][0-9]00 ]]; then
        ls /cvmfs/cms-ib.cern.ch/week*/*/cms/cmssw*/$CMSSW_BUILD > /dev/null
        if [[ $? -ne 0 ]]; then
            logerror "Setting up CMSSW failed. Your current build is probably outdated (check above). If this is the case, you may want to run ts_checkout_new_cmssw_build in order to check out a new build and transfer your local developments."
        fi
    fi

    #check remote and branch
    git remote | grep "^$CMSSW_REMOTE$" > /dev/null
    if [[ $? -ne 0 ]]; then
        logwarn "Project remote is not registered in git of current setup!"
    fi
    git branch | grep "^* $CMSSW_BRANCH$" > /dev/null
    if [[ $? -ne 0 ]]; then
       	logwarn "The branch currently checked out differs from the project branch!"
    fi
else
    read -p "$PROJECT_NAME does not exist. Do you want to create it? [Y/y]" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        loginfo "Creating new project $PROJECT_NAME ..."
        mkdir projects/$PROJECT_NAME
        mkdir projects/$PROJECT_NAME/dev
        mkdir projects/$PROJECT_NAME/ref
        mkdir projects/$PROJECT_NAME/log

        export CMSSW_BUILD=CMSSW_11_3_X_$(date -d "yesterday" +"%Y-%m-%d")-2300
        read -p "Please enter custom CMSSW build if required (default=${CMSSW_BUILD}):" -r
        if [[ ! -z $REPLY ]]; then
            export CMSSW_BUILD=$REPLY
        fi
        _ts_setup_cmssw
        if [[ $? -ne 0 ]]; then
            logwarn "Aborting project creation..."
            cd $TESTSUITEDIR
            rm -rf $TESTSUITEDIR/projects/$PROJECT_NAME
            unset PROJECT_NAME
            return 1
        fi

        read -p "Please enter packages to be added (<SUBSYSTEM1/PACKAGE1> <SUBSYSTEM2/PACKAGE2> ...):" -r
        CMSSW_PACKAGES_TEMP=$REPLY
        read -p "Please enter owner of remote fork to be used (default=cms-tau-pog):" -r
        if [[ -z $REPLY ]]; then
            export CMSSW_REMOTE="cms-tau-pog"
        else
            export CMSSW_REMOTE=$REPLY
        fi
        read -p "Please enter branch to be used:" -r
        export CMSSW_BRANCH=$REPLY

        loginfo "Setting up local code packages..."
        git cms-init
        export CMSSW_PACKAGES=""
        for PACKAGE in $CMSSW_PACKAGES_TEMP; do
            git cms-addpkg $PACKAGE
            if [[ $? -eq 0 ]]; then
                export CMSSW_PACKAGES="$CMSSW_PACKAGES $PACKAGE"
            else
                logerror "CMSSW package $PACKAGE could not be added. Removed it from list. Run 'add_package <SUBSYSTEM/PACKAGE> to try again."
            fi
        done
        git remote add $CMSSW_REMOTE git@github.com:${CMSSW_REMOTE}/cmssw.git
        loginfo "Fetching contents from remote. Credentials required!"
        git fetch $CMSSW_REMOTE
        if [[ $? -eq 0 ]]; then
            git checkout --track $CMSSW_REMOTE/$CMSSW_BRANCH
            if [[ $? -ne 0 ]]; then
                logerror "Branch $CMSSW_BRANCH not available on ${CMSSW_REMOTE}! Use ts_set_branch to switch to a different branch."
                export CMSSW_BRANCH=INVALID
            fi
        else
            logerror "Remote fork $CMSSW_REMOTE is not available! Use ts_set_remote to switch to a different remote."
            export CMSSW_REMOTE=INVALID
            export CMSSW_BRANCH=INVALID
        fi

        _ts_save_metadata
    else
        return 0
    fi
fi

loginfo Following functions are provided: $( grep -E  '^function ts_.*{' $TESTSUITEDIR/utils/user_ts_functions.sh | sed "s@function \(\w\+\).*@\1@" | tr "\n" " " )
