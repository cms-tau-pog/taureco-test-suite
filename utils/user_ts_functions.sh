#!/usr/bin/env bash

#Use 'function ts_<FUNCTION> {}' for user functions.

function ts_active_project {
    if [[ -z $TS_PROJECT_NAME ]]; then
        logerror "No project selected. Please run 'source source_me.sh <PROJECT>' again!"
        return 1
    elif [[ $1 != "quiet" ]]; then
        loginfo "You are currently working on project $TS_PROJECT_NAME"
    fi
}

function ts_go_to_top {
    cd $TS_DIR
}

function ts_go_to_dev {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi
    cd $TS_DIR/projects/$TS_PROJECT_NAME/dev/$TS_CMSSW_BUILD/src
}

function ts_go_to_ref {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi
    cd $TS_DIR/projects/$TS_PROJECT_NAME/ref/$TS_CMSSW_BUILD/src
}

function ts_delete {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    read -p "Do you really want to delete project $TS_PROJECT_NAME from this test suite? [Y/y]" -n 1 -r
    echo
    loginfo "Removing project $TS_PROJECT_NAME ..."
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        cd $TS_DIR
        rm -rf $TS_DIR/projects/$TS_PROJECT_NAME
        unset TS_PROJECT_NAME
    fi
}

function ts_project_data {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    loginfo "Project: $TS_PROJECT_NAME"
    loginfo "CMSSW build: $TS_CMSSW_BUILD"
    loginfo "CMSSW packages: $TS_CMSSW_PACKAGES"
    if [[ $TS_CMSSW_REMOTE == "INVALID" ]]; then
        logerrormsg "Project remote: $TS_CMSSW_REMOTE"
    else
        loginfo "Project remote: $TS_CMSSW_REMOTE"
    fi
    if [[ $TS_CMSSW_BRANCH == "INVALID" ]]; then
        logerrormsg "Project branch: $TS_CMSSW_BRANCH"
    else
        loginfo "Project branch: $TS_CMSSW_BRANCH"
    fi
}

function ts_set_remote {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    if [[ -z $1 ]]; then
        logwarn "Call me with name of remote owner!"
        return 1
    fi

    _ts_env_dev
    git remote | grep $1 > /dev/null
    if [[ $? -ne 0 ]]; then
        git remote add $1 git@github.com:${1}/cmssw.git
    fi
    loginfo "Fetching contents from remote. Credentials required!"
    git fetch $TS_CMSSW_REMOTE
    if [[ $? -ne 0 ]]; then
        logerror "Remote fork $1 is not available! Use ts_set_remote to switch to a different remote."
        return 1
    fi
    export TS_CMSSW_REMOTE=$1
    _ts_save_metadata
}

function ts_set_branch {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    if [[ -z $1	]]; then
        logwarn "Call me with branch name!"
        return 1
    fi

    _ts_env_dev
    git	branch | grep $1 > /dev/null
    if [[ $? -eq 0 ]]; then
        git checkout $1
    else
        git checkout --track $TS_CMSSW_REMOTE/$1
        if [[ $? -ne 0 ]]; then
            logerror "Branch $1 not available on ${TS_CMSSW_REMOTE}! Use ts_set_branch to switch to a different branch."
            return 1
        fi
    fi
    export TS_CMSSW_BRANCH=$1
    _ts_save_metadata
}

function ts_add_package {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    cd $TS_DIR/projects/$TS_PROJECT_NAME/dev/$TS_CMSSW_BUILD/src
    git cms-addpkg $1
    RETURNCODE=$?
    if [[ $RETURNCODE -eq 0 ]]; then
        export TS_CMSSW_PACKAGES="$TS_CMSSW_PACKAGES $1"
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
    OLD_TS_CMSSW_BUILD=$TS_CMSSW_BUILD
    read -p "Please enter custom CMSSW build if required:" -r
    if [[ -z $REPLY ]]; then
        export TS_CMSSW_BUILD=CMSSW_11_1_X_$(date -d "yesterday" +"%Y-%m-%d")-2300
    else
        export TS_CMSSW_BUILD=$REPLY
    fi
    _ts_setup_cmssw
    if [[ $? -ne 0 ]]; then
        export TS_CMSSW_BUILD=$OLD_TS_CMSSW_BUILD
        unset OLD_TS_CMSSW_BUILD
        return 1
    fi
    _ts_save_metadata

    #set up git and packages
    git cms-init
    for PACKAGE in $TS_CMSSW_PACKAGES; do
        git cms-addpkg $PACKAGE
    done

    #copy local changes from old build
    cd $TS_DIR/projects/$TS_PROJECT_NAME/dev/$OLD_TS_CMSSW_BUILD/src
    cmsenv
    git diff > .ts_transfer_to_${TS_CMSSW_BUILD}.diff
    cd $TS_DIR/projects/$TS_PROJECT_NAME/dev/$TS_CMSSW_BUILD/src
    cmsenv
    git apply $TS_DIR/projects/$TS_PROJECT_NAME/dev/$OLD_TS_CMSSW_BUILD/src/.ts_transfer_to_${TS_CMSSW_BUILD}.diff
    unset OLD_TS_CMSSW_BUILD
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
    logandrun 'scram b runtests' $TS_DIR/projects/$TS_PROJECT_NAME/log/unit-tests_${LOGTAG}
    loginfo "Unit tests finished. Please check results in $TS_DIR/projects/$TS_PROJECT_NAME/log/unit-tests_${LOGTAG}.log"
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
    logandrun 'runTheMatrix.py -l limited -i all --ibeos' $TS_DIR/projects/$TS_PROJECT_NAME/log/matrix-tests_${LOGTAG}
    loginfo "Matrix tests finished. Please check results in $TS_DIR/projects/$TS_PROJECT_NAME/log/matrix-tests_${LOGTAG}.log"
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
    loginfo "Standard test sequence finished. Please check results in \n $TS_DIR/projects/$TS_PROJECT_NAME/log/unit-tests_${LOGTAG}.log \n $TS_DIR/projects/$TS_PROJECT_NAME/log/matrix-tests_${LOGTAG}.log"
}

function ts_rebase_to_master {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    _ts_env_dev
    loginfo "Fetching contents from official master. Credentials required!"
    git fetch official-cmssw
    git rebase official-cmssw/master
}

function ts_backport {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    _ts_env_dev

    #Check alignment of git branch with TS remote and branch
    git branch -vv | grep "$TS_CMSSW_BRANCH.*$TS_CMSSW_REMOTE/$TS_CMSSW_BRANCH" > /dev/null
    if [[ $? -ne 0 ]]; then
        logwarn "Active branch and tracked remote are not aligned with project branch and remote. Please restore this! Aborting backport..."
        return 1
    }
    loginfo "Checking sync status of current project. Credentials required!"
    git fetch $TS_CMSSW_REMOTE
    git status | grep "Your branch is up to date with" > /dev/null
    if [[ $? -ne 0 ]]; then
        logwarn "Please synchronize your local repository with the remote first and try again! Aborting backport..."
        return 1
    fi
    #identify range of commits to backport and write it to logfile
    #BASE_COMMIT=$(git rev-list --max-count 1 --min-parents=2 $TS_CMSSW_BRANCH) #not good because merge commits may be present in dev
    LAST_COMMIT=$(git rev-list --max-count 1 $TS_CMSSW_BRANCH)
    for ENTRY in $(git rev-list --max-count 100 $TS_CMSSW_BRANCH); do
        if [[ $(git log -1 --format='%ae' $ENTRY) =~ 'cmsbuild' ]]; then
            BASE_COMMIT=$ENTRY
            break
        else
            echo $ENTRY
        fi
    done > $TS_DIR/projects/$TS_PROJECT_NAME/log/original_commits_of_backport_temp.txt

    read -p "Please enter CMSSW build to backport to:" -r
    echo

    cd $TS_DIR
    if [ -d projects/${TS_PROJECT_NAME}_backport_$REPLY ]; then
        logwarn "Backport project already exists! Aborting backport..."
        rm $TS_DIR/projects/$TS_PROJECT_NAME/log/original_commits_of_backport_temp.txt
        return 1
    fi

    export TS_CMSSW_BUILD=${REPLY}
    export TS_BACKPORT_BASE=$TS_PROJECT_NAME
    export TS_PROJECT_NAME=${TS_PROJECT_NAME}_backport_$TS_CMSSW_BUILD

    loginfo "Creating backport project $TS_PROJECT_NAME ..."
    mkdir projects/$TS_PROJECT_NAME
    mkdir projects/$TS_PROJECT_NAME/dev
    mkdir projects/$TS_PROJECT_NAME/ref
    mkdir projects/$TS_PROJECT_NAME/log
    mv $TS_DIR/projects/$TS_BACKPORT_BASE/log/original_commits_of_backport_temp.txt $TS_DIR/projects/$TS_PROJECT_NAME/log/original_commits_of_backport.txt
    _ts_setup_cmssw
    if [[ $? -ne 0 ]]; then
        logwarn "Aborting backport..."
        cd $TS_DIR
        rm -rf $TS_DIR/projects/$TS_PROJECT_NAME
        export TS_PROJECT_NAME=$TS_BACKPORT_BASE
        source $TS_DIR/projects/$TS_BACKPORT_BASE/project_metadata.sh
        return 1
    fi

    loginfo "Setting up local code packages..."
    git cms-init
    for PACKAGE in $TS_CMSSW_PACKAGES; do
        git cms-addpkg $PACKAGE
    done
    export TS_CMSSW_BRANCH=${TS_CMSSW_BUILD}_backport_$TS_CMSSW_BRANCH
    git checkout -b $TS_CMSSW_BRANCH

    _ts_save_metadata

    git remote add $TS_CMSSW_REMOTE git@github.com:${TS_CMSSW_REMOTE}/cmssw.git
    loginfo "Fetching contents from remote. Credentials required!"
    git fetch $TS_CMSSW_REMOTE
    loginfo "Start cherry-picking commits to be backported... List of commits is written to $TS_DIR/projects/$TS_PROJECT_NAME/log/original_commits_of_backport.txt"
    git cherry-pick ${BASE_COMMIT}..${LAST_COMMIT}
}
