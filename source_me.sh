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
source utils/functionCollection.sh

###############################################################
#Function Definitions
#Use 'function ts_<FUNCTION> {}' for user functions and 'function _ts_<FUNCTION>() {}' for internal functions in order to satisfy pattern matching in last line of this script.

function ts_active_project {
    if [[ -z $PROJECT_NAME ]]; then
        logerror "No project selected. Please run 'source source_me.sh <PROJECT>' again!"
        return 1
    elif [[ $1 != "quiet" ]]; then
        loginfo "You are currently working on project $PROJECT_NAME"
    fi
}

function ts_delete {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    read -p "Do you really want to delete project $PROJECT_NAME from this test suite? [Y/y]" -n 1 -r
    echo
    loginfo "Removing project $PROJECT_NAME ..."
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        cd $TESTSUITEDIR
        rm -rf $TESTSUITEDIR/projects/$PROJECT_NAME
        unset PROJECT_NAME
    fi
}

function ts_project_data {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    loginfo "Project: $PROJECT_NAME"
    loginfo "CMSSW build: $CMSSW_BUILD"
    loginfo "CMSSW packages: $CMSSW_PACKAGES"
    if [[ $CMSSW_REMOTE == "INVALID" ]]; then
        logerrormsg "Project remote: $CMSSW_REMOTE"
    else
        loginfo "Project remote: $CMSSW_REMOTE"
    fi
    if [[ $CMSSW_BRANCH == "INVALID" ]]; then
        logerrormsg "Project branch: $CMSSW_BRANCH"
    else
        loginfo "Project branch: $CMSSW_BRANCH"
    fi
}

function ts_add_package {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    cd $TESTSUITEDIR/projects/$PROJECT_NAME/dev/$CMSSW_BUILD/src
    git cms-addpkg $1
    RETURNCODE=$?
    if [[ $RETURNCODE -eq 0 ]]; then
        export CMSSW_PACKAGES="$CMSSW_PACKAGES $1"
        _ts_save_metadata
    else
        logerror "Package $1 could not be installed."
    fi
    cd -
    return $RETURNCODE
}

function ts_checkout_new_cmssw_build {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    #set up new cmssw build
    OLD_CMSSW_BUILD=$CMSSW_BUILD
    read -p "Please enter custom CMSSW build if required:" -r
    if [[ -z $REPLY ]]; then
        export CMSSW_BUILD=CMSSW_11_1_X_$(date -d "yesterday" +"%Y-%m-%d")-2300
    else
        export CMSSW_BUILD=$REPLY
    fi
    _ts_setup_cmssw
    if [[ $? -ne 0 ]]; then
        export CMSSW_BUILD=$OLD_CMSSW_BUILD
        unset OLD_CMSSW_BUILD
        return 1
    fi
    _ts_save_metadata

    #set up git and packages
    git cms-init
    for PACKAGE in $CMSSW_PACKAGES; do
        git cms-addpkg $PACKAGE
    done

    #copy local changes from old build
    cd $TESTSUITEDIR/projects/$PROJECT_NAME/dev/$OLD_CMSSW_BUILD/src
    cmsenv
    git diff > .ts_transfer_to_${CMSSW_BUILD}.diff
    cd $TESTSUITEDIR/projects/$PROJECT_NAME/dev/$CMSSW_BUILD/src
    cmsenv
    git apply $TESTSUITEDIR/projects/$PROJECT_NAME/dev/$OLD_CMSSW_BUILD/src/.ts_transfer_to_${CMSSW_BUILD}.diff
    unset OLD_CMSSW_BUILD
}

function ts_new_proxy {
    voms-proxy-init -rfc -voms cms
}

function ts_check_proxy {
    voms-proxy-info
    if [[ $? -eq 0 ]]; then
        TIMELEFT=$(voms-proxy-info | grep -E 'timeleft' | sed "s@timeleft  : @@")
        if [[ $TIMELEFT == "00:00:00" ]]; then
            ts_new_proxy
        fi
    else
        ts_new_proxy
    fi
}

function ts_test_code_checks {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    scram b -j 20
    scram b code-format
    scram b code-checks
}

function ts_test_unit {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    scram b -j 20
    export CMS_PATH=/cvmfs/cms-ib.cern.ch/week0
    scram b runtests
}

function ts_test_matrix {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    ts_check_proxy
    scram b -j 20
    runTheMatrix.py -l limited -i all --ibeos
}

function ts_test_standard_sequence {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    ts_check_proxy
    ts_test_code_checks
    ts_test_unit
    ts_test_matrix
}

function _ts_setup_cmssw {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    for SUBFOLDER in dev ref; do
        if [ -d projects/$PROJECT_NAME/$SUBFOLDER/$CMSSW_BUILD ]; then
            logwarn "$CMSSW_BUILD already exists in projects/$PROJECT_NAME/$SUBFOLDER . Skipping it."
        else
            cd $TESTSUITEDIR/projects/$PROJECT_NAME/$SUBFOLDER
            cmsrel $CMSSW_BUILD
            if [[ $? -ne 0 ]]; then
                logerror "CMSSW build $CMSSW_BUILD is not available!"
                cd $TESTSUITEDIR
                return 1
            fi
        fi
    done
    cd $TESTSUITEDIR/projects/$PROJECT_NAME/dev/$CMSSW_BUILD/src
    cmsenv
}

function _ts_save_metadata() {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    (echo "export CMSSW_BUILD=$CMSSW_BUILD" &&
    echo "export CMSSW_PACKAGES='$CMSSW_PACKAGES'" &&
    echo "export CMSSW_REMOTE=$CMSSW_REMOTE" &&
    echo "export CMSSW_BRANCH=$CMSSW_BRANCH") > $TESTSUITEDIR/projects/$PROJECT_NAME/project_metadata.sh
}

###############################################################

#Make sure that projects directory exists
[ ! -d projects ] && mkdir projects

#Check whether project exists. If not, create it.
if [ -d projects/$PROJECT_NAME ]; then
    source projects/$PROJECT_NAME/project_metadata.sh
    cd projects/$PROJECT_NAME/dev/$CMSSW_BUILD/src
    cmsenv
    if [[ $? -ne 0 ]]; then
        #CURRENT CMSENV ALWAYS RETURNS 0 AND THIS MESSAGE WONT SHOW UP.
        logerror "Setting up CMSSW failed. Your current build might be outdated (check above). If this is the case, you may want to run ts_checkout_new_cmssw_build in order to check out a new build and transfer your local developments."
    fi

    #check remote and branch
    git remote | grep $CMSSW_REMOTE > /dev/null
    if [[ $? -ne 0 ]]; then
        logwarn "Project remote is not registered in git of current setup!"
    fi
    git branch | grep "* $CMSSW_BRANCH" > /dev/null
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

        read -p "Please enter custom CMSSW build if required:" -r
        if [[ -z $REPLY ]]; then
            export CMSSW_BUILD=CMSSW_11_1_X_$(date -d "yesterday" +"%Y-%m-%d")-2300
        else
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
            git checkout --track $CMSSW_BRANCH
            if [[ $? -ne 0 ]]; then
                logerror "Branch $CMSSW_BRANCH not available on ${CMSSW_REMOTE}! Use ts_set_branch to switch to a different branch."
                export CMSSW_BRANCH=INVALID
            fi
        else
            logerror "Remote fork $CMSSW_REMOTE is not available! Use ts_set_remote to switch to a different remote."
            export CMSSW_REMOTE=INVALID
        fi

        _ts_save_metadata
    else
        return 0
    fi
fi

loginfo Following functions are provided: $( grep -E  '^function ts_.*{' $TESTSUITEDIR/source_me.sh | sed "s@function \(\w\+\).*@\1@" | tr "\n" " " )
