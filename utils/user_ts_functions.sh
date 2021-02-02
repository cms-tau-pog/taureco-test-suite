#!/usr/bin/env bash

#Use 'function ts_<FUNCTION> {}' for user functions.

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
    if [[ $? -ne 0 ]]; then
        logerrormsg "Compilation failed!"
        return 1
    fi
    scram b code-format
    scram b code-checks
}

function ts_test_unit {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    LOGTAG=$1
    if [[ -z $LOGTAG ]]; then
        LOGTAG=$(date +%Y-%m-%d_%H-%M)
    fi

    scram b -j 20
    if [[ $? -ne 0 ]]; then
        logerrormsg "Compilation failed!"
        return 1
    fi
    export CMS_PATH=/cvmfs/cms-ib.cern.ch/week0
    logandrun 'scram b runtests' $TESTSUITEDIR/projects/$PROJECT_NAME/log/unit-tests_${LOGTAG}
    loginfo "Unit tests finished. Please check results in $TESTSUITEDIR/projects/$PROJECT_NAME/log/unit-tests_${LOGTAG}.log"
}

function ts_test_matrix {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    LOGTAG=$1
    if [[ -z $LOGTAG ]]; then
        LOGTAG=$(date +%Y-%m-%d_%H-%M)
    fi

    ts_check_proxy
    scram b -j 20
    if [[ $? -ne 0 ]]; then
        logerrormsg "Compilation failed!"
        return 1
    fi
    logandrun 'runTheMatrix.py -l limited -i all --ibeos' $TESTSUITEDIR/projects/$PROJECT_NAME/log/matrix-tests_${LOGTAG}
    loginfo "Matrix tests finished. Please check results in $TESTSUITEDIR/projects/$PROJECT_NAME/log/matrix-tests_${LOGTAG}.log"
}

function ts_test_standard_sequence {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    LOGTAG=$1
    if [[ -z $LOGTAG ]]; then
        LOGTAG=$(date +%Y-%m-%d_%H-%M)
    fi

    ts_check_proxy
    ts_test_code_checks
    ts_test_unit $LOGTAG
    ts_test_matrix $LOGTAG
    loginfo "Standard test sequence finished. Please check results in \n $TESTSUITEDIR/projects/$PROJECT_NAME/log/unit-tests_${LOGTAG}.log \n $TESTSUITEDIR/projects/$PROJECT_NAME/log/matrix-tests_${LOGTAG}.log"
}
