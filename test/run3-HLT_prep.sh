#!/usr/bin/env bash

cmsDriver.py run3-HLT_input  --conditions auto:run3_mc_GRun -n 1000 --step=NONE --mc --eventcontent RAWSIM --filein /store/mc/Run3Winter20DRPremixMiniAOD/VBFHToTauTau_M125_TuneCUETP8M1_14TeV_powheg_pythia8/GEN-SIM-RAW/110X_mcRun3_2021_realistic_v6-v1/20000/02B68B17-0C3C-0642-B7B2-7BE916547C8B.root --fileout file:run3-HLT_input.root
