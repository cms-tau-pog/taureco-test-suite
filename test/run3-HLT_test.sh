#!/usr/bin/env bash

#prepare HLT user config
CURRENTDIR=$PWD
cd $CMSSW_BASE/src
if [ ! -d HLTrigger/Configuration ]; then
    git cms-addpkg HLTrigger/Configuration
fi
if [ ! -f HLTrigger/Configuration/python/HLT_User_cff.py ]; then
    hltGetConfiguration /dev/CMSSW_11_2_0/GRun --path HLTriggerFirstPath,HLT_DoubleMediumChargedIsoPFTauHPS35_Trk1_eta2p1_Reg_v4,HLTriggerFinalPath,HLTAnalyzerEndpath --unprescale --cff > HLTrigger/Configuration/python/HLT_User_cff.py
    scram b -j 12
fi
cd $CURRENTDIR

cmsDriver.py run3-HLT_${1} --customise=RecoTauTag/HLTProducers/deepTauAtHLT.update --step=HLT:User --mc --conditions auto:run3_mc_GRun --era=Run2_2018 -n 1000 --filein file:run3-HLT_input.root --process TEST --fileout run3-HLT_${1}.root
