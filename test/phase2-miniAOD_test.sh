#!/usr/bin/env bash

cmsDriver.py phase2-miniAOD_${1}  --conditions auto:phase2_realistic_T15 -n 50 --era Phase2C9 --eventcontent MINIAODSIM --runUnscheduled  --filein file:phase2-miniAOD_input.root -s PAT --datatier MINIAODSIM --geometry Extended2026D49 --fileout file:phase2-miniAOD_${1}.root
