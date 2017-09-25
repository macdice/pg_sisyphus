#!/bin/sh
#
# A recipe that creates a tpch cluster.  Expects PATH to contain an
# installation of PostgreSQL whose catversion we will inspect.  Expects to
# be run from the top of the pg_sisyphus tree.  Takes a scale argument.

set -e

if [ "$1" == "" ] ; then
  CLUSTER_NAME="tpch"
else
  CLUSTER_NAME="$1"
fi

if [ "$2" == "" ] ; then
  SCALE=0.01
else
  SCALE=$2
fi

PGPORT=25432

# Figure out where this cluster's PGDATA should be.
if [ "$SISYPHUS_CLUSTERS" == "" ] ; then
  SISYPHUS_CLUSTERS=clusters
fi
CLUSTER_DIR="$SISYPHUS_CLUSTERS/$CLUSTER_NAME"
CATVERSION_H=` pg_config --includedir`/server/catalog/catversion.h
CATVERSION=` grep CATALOG_VERSION_NO $CATVERSION_H | cut -f2 `
PGDATA=$CLUSTER_DIR/$CATVERSION

# Initialize a new cluster and load the TPC-H data, unless we already have
# one with the right catversion.
if [ ! -e $PGDATA ] ; then
  # Build the test data, if we don't already have it.
  ( cd benchmarks/tpch && ./make-data.sh $SCALE )
  # Init a new cluster.  Use a temporary name an move it into place on success.
  mkdir -p $CLUSTER_DIR
  rm -fr $PGDATA.tmp
  initdb -D $PGDATA.tmp
  echo "shared_buffers = '1GB'" >> $PGDATA.tmp/postgresql.conf
  echo "port = $PGPORT" >> $PGDATA.tmp/postgresql.conf
  echo "cluster_name = '$CLUSTER_NAME'" >> $PGDATA.tmp/postgresql.conf
  echo "max_wal_size = '4GB'" >> $PGDATA.tmp/postgresql.conf
  pg_ctl -w -D $PGDATA.tmp start
  createdb -p $PGPORT tpch
  psql -p $PGPORT tpch <<EOF
BEGIN;
\i benchmarks/tpch/postgresql-schema/create-tables.sql
\copy customer from 'benchmarks/tpch/data-scale-$SCALE/customer.tbl' with (format csv, delimiter '|')
\copy lineitem from 'benchmarks/tpch/data-scale-$SCALE/lineitem.tbl' with (format csv, delimiter '|')
\copy nation from 'benchmarks/tpch/data-scale-$SCALE/nation.tbl' with (format csv, delimiter '|')
\copy orders from 'benchmarks/tpch/data-scale-$SCALE/orders.tbl' with (format csv, delimiter '|')
\copy part from 'benchmarks/tpch/data-scale-$SCALE/part.tbl' with (format csv, delimiter '|')
\copy partsupp from 'benchmarks/tpch/data-scale-$SCALE/partsupp.tbl' with (format csv, delimiter '|')
\copy region from 'benchmarks/tpch/data-scale-$SCALE/region.tbl' with (format csv, delimiter '|')
\copy supplier from 'benchmarks/tpch/data-scale-$SCALE/supplier.tbl' with (format csv, delimiter '|')
COMMIT;
\i benchmarks/tpch/postgresql-schema/alter-tables.sql

-- The following indexes were recommended by Tomas Vondra
-- https://github.com/tvondra/pg_tpch/blob/master/dss/tpch-index.sql
-- I am not sure of their status.

-- indexes on the foreign keys
CREATE INDEX IDX_SUPPLIER_NATION_KEY ON SUPPLIER (S_NATIONKEY);
CREATE INDEX IDX_PARTSUPP_PARTKEY ON PARTSUPP (PS_PARTKEY);
CREATE INDEX IDX_PARTSUPP_SUPPKEY ON PARTSUPP (PS_SUPPKEY);
CREATE INDEX IDX_CUSTOMER_NATIONKEY ON CUSTOMER (C_NATIONKEY);
CREATE INDEX IDX_ORDERS_CUSTKEY ON ORDERS (O_CUSTKEY);
CREATE INDEX IDX_LINEITEM_ORDERKEY ON LINEITEM (L_ORDERKEY);
CREATE INDEX IDX_LINEITEM_PART_SUPP ON LINEITEM (L_PARTKEY,L_SUPPKEY);
CREATE INDEX IDX_NATION_REGIONKEY ON NATION (N_REGIONKEY);
-- aditional indexes
CREATE INDEX IDX_LINEITEM_SHIPDATE ON LINEITEM (L_SHIPDATE, L_DISCOUNT, L_QUANTITY);
CREATE INDEX IDX_ORDERS_ORDERDATE ON ORDERS (O_ORDERDATE);
ANALYZE;
EOF
  pg_ctl -D $PGDATA.tmp stop
  mv $PGDATA.tmp $PGDATA
fi

echo $PGDATA
