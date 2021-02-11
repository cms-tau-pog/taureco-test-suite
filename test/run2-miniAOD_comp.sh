#!/usr/bin/env bash

python $TS_DIR/test/compare_miniAOD.py --input-dev $TS_DIR/projects/$TS_PROJECT_NAME/test/run2-miniAOD_dev.root \
    --input-ref $TS_DIR/projects/$TS_PROJECT_NAME/test/run2-miniAOD_ref.root -q \
    id:byDeepTau2017v2p1VSjetraw \
    id:byDeepTau2017v2p1VSeraw \
    id:byDeepTau2017v2p1VSmuraw \
    id:chargedIsoPtSum \
    id:neutralIsoPtSum \
    id:byCombinedIsolationDeltaBetaCorrRaw3Hits
