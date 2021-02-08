#!/usr/bin/env bash

#Use 'function _ts_<FUNCTION>() {}' for internal functions.

function _ts_env_dev {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi
    cd $TS_DIR/projects/$TS_PROJECT_NAME/dev/$TS_CMSSW_BUILD/src
    cmsenv
}

function _ts_env_ref {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi
    cd $TS_DIR/projects/$TS_PROJECT_NAME/ref/$TS_CMSSW_BUILD/src
    cmsenv
}

function _ts_setup_cmssw {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    for SUBFOLDER in dev ref; do
        if [ -d projects/$TS_PROJECT_NAME/$SUBFOLDER/$TS_CMSSW_BUILD ]; then
            logwarn "$TS_CMSSW_BUILD already exists in projects/$TS_PROJECT_NAME/$SUBFOLDER . Skipping it."
        else
            cd $TS_DIR/projects/$TS_PROJECT_NAME/$SUBFOLDER
            cmsrel $TS_CMSSW_BUILD
            if [[ $? -ne 0 ]]; then
                logerror "CMSSW build $TS_CMSSW_BUILD is not available!"
                cd $TS_DIR
                return 1
            fi
        fi
    done
    _ts_env_dev
}

function _ts_save_metadata() {
    ts_active_project quiet; PROJECTOK=$?; if [[ $PROJECTOK -ne 0 ]]; then return $PROJECTOK; fi

    (echo "export TS_CMSSW_BUILD=$TS_CMSSW_BUILD" &&
    echo "export TS_CMSSW_PACKAGES='$TS_CMSSW_PACKAGES'" &&
    echo "export TS_CMSSW_REMOTE=$TS_CMSSW_REMOTE" &&
    echo "export TS_CMSSW_BRANCH=$TS_CMSSW_BRANCH" &&
    echo "export TS_BACKPORT_BASE=$TS_BACKPORT_BASE") > $TS_DIR/projects/$TS_PROJECT_NAME/project_metadata.sh
}
