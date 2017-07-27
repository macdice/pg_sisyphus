#!/bin/sh
#
# Build the files for a given scale in a directory called data-scale-X,
# unless it already exists.

set -e

SCALE=$1

if [[ "$SCALE" == "" ]] ; then
  SCALE=1
fi

OUTPUT_DIR="data-scale-$SCALE"

if [[ ! -e $OUTPUT_DIR ]] ; then
  rm -fr $OUTPUT_DIR $OUTPUT_DIR.tmp
  rm -f build/*.tbl
  mkdir $OUTPUT_DIR.tmp
  ( cd build && ./dbgen -s $SCALE )
  mv build/*.tbl $OUTPUT_DIR.tmp/
  mv $OUTPUT_DIR.tmp $OUTPUT_DIR
fi

