#!/bin/csh

set REQUEST_DIR = $1 
set FORK        = $2
set REPO        = $3
set BRANCH      = $4

pushd $REQUEST_DIR >& /dev/null

if ( `pwd` != $REQUEST_DIR ) then
	echo ummm, we need to be in $REQUEST_DIR to start this
	exit ( 1 )
endif

if ( -d wrf-coop ) then
	rm -rf wrf-coop
endif

wget https://github.com/davegill/wrf-coop/archive/master.tar.gz
tar -xf master.tar.gz
rm master.tar.gz
mv wrf-coop-master wrf-coop

chmod 777 wrf-coop
cd wrf-coop/

sed -e "s|_FORK_|${FORK}|" \
    -e "s|_REPO_|${REPO}|" \
    -e "s|_BRANCH_|${BRANCH}|" \
    Dockerfile > .foo
mv .foo Dockerfile

./build.csh $REQUEST_DIR $REQUEST_DIR/wrf-coop

if ( ! -d OUTPUT ) then
	mkdir OUTPUT
	chmod 777 OUTPUT
endif
