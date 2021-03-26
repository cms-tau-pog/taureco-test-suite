#!/usr/bin/env bash

python $TS_DIR/test/compare_nanoAOD.py --input-dev $TS_DIR/projects/$TS_PROJECT_NAME/test/run2-nanoAOD_dev.root \
    --input-ref $TS_DIR/projects/$TS_PROJECT_NAME/test/run2-nanoAOD_ref.root -q \
    pt \
    eta \
    phi \
    mass \
    decayMode \
    chargedIso \
    neutralIso \
    photonsOutsideSignalCone \
    puCorr \
    rawIso \
    rawAntiEle2018 \
    idAntiMu:1:Loose \
    idAntiMu:2:Tight \
    rawDeepTau2017v2p1VSjet \
    rawDeepTau2017v2p1VSe \
    rawDeepTau2017v2p1VSmu
