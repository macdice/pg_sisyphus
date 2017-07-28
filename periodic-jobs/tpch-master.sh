#!/bin/sh
#
# A cron-job to test master periodically.

set -e

JOB_NAME=tpch-master

SISYPHUS=$HOME/projects/pg_sisyphus
SISYPHUS_DATA=$HOME/sisyphus
SOURCE=$SISYPHUS_DATA/repos/$JOB_NAME/postgresql
LOGS=$SISYPHUS_DATA/logs/$JOB_NAME
INSTALL=$SISYPHUS_DATA/install/$JOB_NAME
SISYPHUS_CLUSTERS=$SISYPHUS_DATA/clusters
PATH=$INSTALL/bin:$PATH

export SISYPHUS_CLUSTERS
export PATH

mkdir -p $LOGS
RUN_ID="` date "+%Y-%m-%d" `"

(
  # first, get an up-to-date PostgreSQL installation
  cd $SOURCE
  git pull
  ./configure --prefix=$INSTALL --enable-debug --enable-depend CC="ccache cc"
  make clean && make && make install && make check
) > $LOGS/$RUN_ID.build.log 2>&1

for scale in 0.01 ; do
  (
    # make sure we have a tpch cluster for the current catversion
    cd $SISYPHUS
    PGDATA="` ./cluster-recipes/make-tpch-cluster.sh tpch-master-$scale $scale `"

    # start the cluster and run the test driver
    pg_ctl -D "$PGDATA" start
    ./test-drivers/tpch.sh
    pg_ctl -D "$PGDATA" stop

  ) > $LOGS/$RUN_ID.scale-$scale.log 2>&1
done

gzip -f $LOGS/$RUN_ID.*.log
