#!/usr/bin/env bash

#Use 'function _ts_<FUNCTION>() {}' for internal functions.

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
