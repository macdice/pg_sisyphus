#!/bin/sh
#
# Run TPCH with a range of different numbers of workers and amounts of memory.

set -e

if [[ "$SISYPHUS_PGPORT" == "" ]] ; then
  SISYPHUS_PGPORT=25432
fi
PGPORT=$SISYPHUS_PGPORT

# Does this version of PostgreSQL support parallel query?  It's useful to be
# able to test ancient versions with the same driver.
if psql -p $PGPORT tpch -tc "SELECT * FROM pg_settings WHERE name = 'max_parallel_workers_per_gather'" | grep 'max' ; then
  WORKERS="0 1 2 3 4 5 6 7 8"
else
  WORKERS="0"
fi

echo "@uname"
uname -a

echo "@pg_config"
psql -p $PGPORT tpch -c 'SELECT * FROM pg_config'

for query in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 ; do

  # run the query once so that data is in cache
  echo "@warmup"
  psql -p $PGPORT tpch -f benchmarks/tpch/postgresql-queries/1.sql

  # run with a bunch of workmem sizes and worker counts
  for work_mem in 64MB 128MB 256MB 512MB 1GB ; do
    for workers in $WORKERS ; do
      echo "@run query=$query work_mem=$work_mem workers=$workers"
      psql -p $PGPORT tpch <<EOF
\set ECHO ALL
\timing on
SET work_mem = '$work_mem';
SET max_parallel_workers_per_gather = '$workers';
\i benchmarks/tpch/postgresql-queries/$query.explain-analyze.sql
EOF
    done
  done
done
