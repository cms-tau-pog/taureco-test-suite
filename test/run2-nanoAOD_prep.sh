#!/usr/bin/env bash

source $TS_DIR/test/ibeos_env.sh

dasgoclient --limit 0 --query 'file dataset=/RelValTTbar_13/CMSSW_10_6_0-106X_mcRun2_asymptotic_v3-v1/GEN-SIM site=T2_CH_CERN' | ibeos-lfn-sort > run2-nanoAOD_prep_dasquery.log  2>&1

cmsDriver.py run2-nanoAOD_prepinput  --conditions auto:run2_mc --pileup_input das:/RelValMinBias_13/CMSSW_10_6_0-106X_mcRun2_asymptotic_v3-v1/GEN-SIM -n 50 --era Run2_2016 --eventcontent RECOSIM -s DIGI:pdigi_valid,L1,DIGI2RAW,HLT:@relval2016,RAW2DIGI,L1Reco,RECO,RECOSIM --datatier GEN-SIM-RECO --pileup AVE_35_BX_25ns --filein filelist:run2-nanoAOD_prep_dasquery.log --fileout file:run2-nanoAOD_prepinput.root 

cmsDriver.py run2-nanoAOD_input  --conditions auto:run2_mc -n 50 --era Run2_2016 --eventcontent MINIAODSIM --runUnscheduled  -s PAT --datatier MINIAODSIM --pileup AVE_35_BX_25ns --filein  file:run2-nanoAOD_prepinput.root  --fileout file:run2-nanoAOD_input.root
