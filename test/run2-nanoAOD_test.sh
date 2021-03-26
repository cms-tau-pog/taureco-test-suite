#!/usr/bin/env bash

cmsDriver.py run2-nanoAOD_$1  --conditions auto:run2_mc -n 50 --era Run2_2016 --eventcontent NANOAODSIM --runUnscheduled  -s NANO --datatier NANOAODSIM --pileup AVE_35_BX_25ns --filein  file:run2-nanoAOD_input.root  --fileout file:run2-nanoAOD_${1}.root
