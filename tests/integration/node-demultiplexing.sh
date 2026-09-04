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
    local RC=$?

    if [ -f output.dat ]; then
        echo "### samples written to the destination node:"
        cat output.dat
    fi

    popd

    if [ ${RC} -eq 0 ]; then
        rm -rf ${DIR}
    else
        echo "### failed, working directory left at ${DIR}"
    fi
}
trap finish EXIT

function nodes {
    cat <<EOF
        "sig_1": {
            "type": "signal",

            "signal": "counter",
            "values": 3,
            "offset": 100.0,
            "rate": $1,
            "limit": 5
        },
        "sig_2": {
            "type": "signal",

            "signal": "counter",
            "values": 3,
            "offset": 200.0,
            "rate": $2,
            "limit": 5
        },
        "file_1": {
            "type": "file",
            "uri": "output.dat"
        }
EOF
}

NODES=$(nodes 200.0 200.0)

function check_stamps {
    grep -v '^#' output.dat | awk -F'[.()]' '
        { if ($3 != NR - 1) { print "sequence " $3 " on line " NR; exit 1 }
          if ($1 < sec || ($1 == sec && $2 < nsec)) { print "time went backwards on line " NR; exit 1 }
          sec = $1; nsec = $2 }'
}

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


check_stamps


NODES_MIXED=$(nodes 10.0 20.0)

cat > gap.json <<EOF
{
    "idle_stop": true,
    "nodes": {
${NODES_MIXED}
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

rm -f output.dat

villas node gap.json &> gap.log

grep -q "Slots 3, 4 of node" gap.log

test $(grep -v '^#' output.dat | wc -l) -eq 10

test "$(grep -v '^#' output.dat | tail -1 | \
        awk '{ printf "%d %d %d %s %s %d %d %d", $2, $3, $4, $5, $6, $7, $8, $9 }')" \
     = "104 104 104 nan nan 204 204 204"

check_stamps

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
