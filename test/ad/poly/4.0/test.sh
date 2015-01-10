#!/bin/bash
#
# File     : gyre.sh
# Purpose  : GYRE testing script

. test_support

# Settings

EXEC=./gyre_ad

IN_FILE=gyre_ad.in
OUT_FILE=gyre_ad.txt

LABEL="polytrope model (n_poly=4.0)"

ABSERR=1E-6
FIELDS=1-2,5

# Do the tests

run_gyre $EXEC $IN_FILE "$LABEL"
if [ $? -ne 0 ]; then
    exit 1;
fi

check_output $ABSERR $FIELDS $OUT_FILE '' abs
if [ $? -ne 0 ]; then
    exit 1;
fi

# Clean up output files

rm -f $OUT_FILE

# Finish

echo " ...succeeded"