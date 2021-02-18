#!/usr/bin/env bash

python $TS_DIR/test/compare_miniAOD.py --input-dev $TS_DIR/projects/$TS_PROJECT_NAME/test/run2-miniAOD_dev.root \
    --input-ref $TS_DIR/projects/$TS_PROJECT_NAME/test/run2-miniAOD_ref.root -q \
    pt \
    eta \
    phi \
    mass \
    mt \
    decayMode \
    id:chargedIsoPtSum \
    id:neutralIsoPtSum \
    id:neutralIsoPtSumWeight \
    id:footprintCorrection \
    id:photonPtSumOutsideSignalCone \
    id:puCorrPtSum \
    id:chargedIsoPtSumdR03 \
    id:footprintCorrectiondR03 \
    id:neutralIsoPtSumWeightdR03 \
    id:neutralIsoPtSumdR03 \
    id:photonPtSumOutsideSignalConedR03 \
    id:byCombinedIsolationDeltaBetaCorrRaw3Hits \
    id:againstElectronMVA6Raw \
    id:againstMuonLoose3 \
    id:againstMuonTight3 \
    id:byDeepTau2017v2p1VSjetraw \
    id:byDeepTau2017v2p1VSeraw \
    id:byDeepTau2017v2p1VSmuraw
