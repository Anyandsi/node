#!/usr/bin/env bash
#
# Integration test for de-multiplexing using villas node.
#
# Author: Andrii Podriez <andrey5577990@gmail.com>
# SPDX-FileCopyrightText: 2014-2023 Institute for Automation of Complex Power Systems, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0

set -e

DIR=$(mktemp -d)
pushd ${DIR}

function finish {
    popd
    rm -rf ${DIR}
}
trap finish EXIT

NODES='
        "sig_1": {
            "type": "signal",

            "signal": "counter",
            "values": 3,
            "offset": 100.0,
            "rate": 10.0,
            "limit": 5
        },
        "sig_2": {
            "type": "signal",

            "signal": "counter",
            "values": 3,
            "offset": 200.0,
            "rate": 200.0,
            "limit": 5
        },
        "file_1": {
            "type": "file",
            "uri": "output.dat"
        }'

cat > config.json <<EOF
{
    "idle_stop": true,
    "nodes": {
${NODES}
    },
    "paths": [
        {
            "in": "sig_1",
            "out": "file_1.data[0-2]"
        },
        {
            "in": "sig_2",
            "out": "file_1.data[3-5]"
        }
    ]
}
EOF

villas node config.json

test $(grep -v '^#' output.dat | wc -l) -eq 10

test "$(grep -v '^#' output.dat | tail -1 | \
        awk '{ printf "%d %d %d %d %d %d", $2, $3, $4, $5, $6, $7 }')" \
     = "104 104 104 204 204 204"

cat > gap.json <<EOF
{
    "idle_stop": true,
    "nodes": {
${NODES}
    },
    "paths": [
        {
            "in": "sig_1",
            "out": "file_1.data[0-2]"
        },
        {
            "in": "sig_2",
            "out": "file_1.data[5-7]"
        }
    ]
}
EOF

villas node gap.json &> gap.log

grep -q "Slots 3, 4 of node" gap.log

while read -r OUT MSG; do

cat > invalid.json <<EOF
{
    "idle_stop": true,
    "nodes": {
${NODES}
    },
    "paths": [
        {
            "in": "sig_1",
            "out": "file_1.data[0-2]"
        },
        {
            "in": "sig_2",
            "out": "${OUT}"
        }
    ]
}
EOF

! villas node invalid.json 2> error.log

grep -q "${MSG}" error.log

done <<EOF
file_1.data[2-4] The slices of a destination node must be disjoint
file_1 Every node must only be used by a single path as destination
EOF
