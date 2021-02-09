#!/usr/bin/env bash

curl -L -s -o $CMSSW_BASE/ibeos_cache.txt https://raw.githubusercontent.com/cms-sw/cms-sw.github.io/master/das_queries/ibeos.txt

IBEOS_BASE=$CMSSW_RELEASE_BASE/src/Utilities/General/ibeos
if [ -d $CMSSW_BASE/src/Utilities/General/ibeos ]; then
    IBEOS_BASE=$CMSSW_BASE/src/Utilities/General/ibeos
fi
PATH=${IBEOS_BASE}:$PATH
CMS_PATH=/cvmfs/cms-ib.cern.ch
CMSSW_USE_IBEOS=true
