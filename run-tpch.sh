#!/bin/sh
#
# Assume that PostgreSQL has been installed into PATH.
# Assume that 'make' has been run in benchmarks/tpch.

set -e

# Directory where we build database clusters.
CLUSTER_DIR="$PWD/clusters/tpch"
SHARED_BUFFERS="1GB"
PGPORT=25432

# Fish the curent catalog version number, so we can see if we can re-use an
# existing cluster with TPC-H loaded into it.
CATVERSION_H=` pg_config --includedir`/server/catalog/catversion.h
CATVERSION=` grep CATALOG_VERSION_NO $CATVERSION_H | cut -f2 `
PGDATA=$CLUSTER_DIR/$CATVERSION

# Initialize a new cluster and load the TPC-H data, unless we already have
# one with the right catversion.
if [[ ! -e $PGDATA ]] ; then
  initdb -D $PGDATA
  echo "shared_buffers = $SHARED_BUFFERS" >> $PGDATA/postgresql.conf
  echo "port = $PGPORT" >> $PGDATA/postgresql.conf
  echo "cluster_name = tpch" >> $PGDATA/postgresql.conf
  echo "max_wal_size = '4GB'" >> $PGDATA/postgresql.conf
  pg_ctl -D $PGDATA start
  sleep 2
  createdb -p $PGPORT tpch
  psql -p $PGPORT tpch <<EOF
BEGIN;
\i benchmarks/tpch/postgresql-schema/create-tables.sql
\copy customer from 'benchmarks/tpch/postgresql-data/customer.tbl' with (format csv, delimiter '|')
\copy lineitem from 'benchmarks/tpch/postgresql-data/lineitem.tbl' with (format csv, delimiter '|')
\copy nation from 'benchmarks/tpch/postgresql-data/nation.tbl' with (format csv, delimiter '|')
\copy orders from 'benchmarks/tpch/postgresql-data/orders.tbl' with (format csv, delimiter '|')
\copy part from 'benchmarks/tpch/postgresql-data/part.tbl' with (format csv, delimiter '|')
\copy partsupp from 'benchmarks/tpch/postgresql-data/partsupp.tbl' with (format csv, delimiter '|')
\copy region from 'benchmarks/tpch/postgresql-data/region.tbl' with (format csv, delimiter '|')
\copy supplier from 'benchmarks/tpch/postgresql-data/supplier.tbl' with (format csv, delimiter '|')
COMMIT;
\i benchmarks/tpch/postgresql-schema/alter-tables.sql
EOF
  pg_ctl -D $PGDATA stop
fi

