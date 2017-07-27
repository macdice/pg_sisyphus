# A makefile to build TPCH dbgen on a modern Linux, FreeBSD or macOS system,
# and convert its DDL and test queries into a format that PostgreSQL can run.
#
# The end result should be two directories:
#
# postgresql-queries: versions of the TPC-H queries suitable for PostgreSQL
# postgresql-schema:  versions of the DDL suitable for PostgreSQL
# data-scale-X:       data files for scale X gigabytes

# The TPC-H dbgen tool is available from many locations.  This one happens to
# be the top search result on Google today.  Let's use a specific commit so as
# to avoid picking up unintended changes later.  It'd be nice to be able to
# use # http://tpc.org/tpch/spec/tpch_2_14_3.tgz but it seems to have
# disappeared from the interwebs.
TPCH_DBGEN_GITHUB_USER=electrum
TPCH_DBGEN_GITHUB_REPO=tpch-dbgen
TPCH_DBGEN_GITHUB_COMMIT=5eab24aa876b56d2620c18f0a5a38c6348db37e7
TPCH_DBGEN_GITHUB_ZIP=https://github.com/$(TPCH_DBGEN_GITHUB_USER)/$(TPCH_DBGEN_GITHUB_REPO)/archive/$(TPCH_DBGEN_GITHUB_COMMIT).zip

# Approximate number of gigabytes of data to create.
TPCH_SCALE?=1

all: postgresql-queries postgresql-schema data-scale-$(TPCH_SCALE)

postgresql-schema: build
	# patch up the DDL
	rm -fr $@.tmp
	mkdir $@.tmp
	cp build/dss.ddl $@.tmp/create-tables.sql
	sed 's/CONNECT TO TPCD;//;\
	     s/TPCD\.//;\
	     s/COMMIT WORK;//;\
	     s/PARTSUPP;$$/PARTSUPP (PS_PARTKEY,PS_SUPPKEY);/;\
	     s/references \([A-Z]\)\([A-Z]*\);$$/references \1\2 (\1_\1\2KEY);/; \
	     s/O_ORDERSKEY/O_ORDERKEY/;\
	     s/C_CUSTOMERKEY/C_CUSTKEY/;\
	     s/S_SUPPLIERKEY/S_SUPPKEY/;\
	     s/FOREIGN KEY [A-Z0-9_]* /FOREIGN KEY /;' \
	     < build/dss.ri > $@.tmp/alter-tables.sql
	awk '/^CREATE TABLE / { printf("DROP TABLE IF EXISTS %s CASCADE;\n", $$3); }' < build/dss.ddl > $@.tmp/drop-tables.sql
	mv $@.tmp $@

data-scale-$(TPCH_SCALE): build/dbgen
	rm -fr $@ $@.tmp
	mkdir $@.tmp
	rm -f build/*.tbl
	cd build && ./dbgen -s $(TPCH_SCALE)
	mv build/*.tbl $@.tmp/
	mv $@.tmp $@

postgresql-queries: build/dbgen build/templates-modified-for-postgresql
	rm -fr $@.tmp
	mkdir $@.tmp
	( \
	  cd build ; \
	  for I in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 ; do \
	    DSS_QUERY=templates-modified-for-postgresql ./qgen $$I > ../$@.tmp/$$I.sql ; \
	    sed 's/^select/explain select/' < ../$@.tmp/$$I.sql > ../$@.tmp/$$I.explain.sql ; \
	    sed 's/^select/explain analyze select/' < ../$@.tmp/$$I.sql > ../$@.tmp/$$I.explain-analyze.sql ; \
      done ; \
	)
	mv $@.tmp $@

build/templates-modified-for-postgresql: build
	# qgen knows how to spell LIMIT on various other systems, but not postgres
	# so we'll tweak the templates with sed
	rm -fr $@.tmp
	mkdir $@.tmp
	sed 's/:n -1//;s/s_suppkey;/s_suppkey LIMIT 1;/' < build/queries/15.sql > $@.tmp/15.sql
	for I in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 16 17 18 19 20 21 ; do \
	  sed 's/;//;s/(3)//;s/:n[ -]*/LIMIT /' < build/queries/$$I.sql > $@.tmp/$$I.sql ; \
	  echo ';' >> $@.tmp/$$I.sql ; \
    done
	mv $@.tmp $@

build/dbgen: build/Makefile
	# compiles with a bunch of warnings about dodgy printf format strings...
	cd build && make

build/Makefile: build
	# the following details are not true...
	sed 's/^CC *=.*$$/CC=cc/;\
	     s/^DATABASE *=.*$$/DATABASE=ORACLE/;\
	     s/^MACHINE *=.*$$/MACHINE=LINUX -D_POSIX_SOURCE -DEOL_HANDLING/;\
	     s/^WORKLOAD *=.*$$/WORKLOAD=TPCH/' < $</makefile.suite > $@

build: dbgen.zip
	unzip $< && mv $(TPCH_DBGEN_GITHUB_REPO)-$(TPCH_DBGEN_GITHUB_COMMIT) build

dbgen.zip:
	wget -O $@ $(TPCH_DBGEN_GITHUB_ZIP)

clean:
	rm -fr dbgen.zip build postgresql-schema postgresql-queries data-scale-*
