#! /usr/bin/env bash
set -eux

set +e
source ./machine-setup.sh > /dev/null 2>&1
set -e
cwd=`pwd`

USE_PREINST_LIBS=${USE_PREINST_LIBS:-"true"}
if [ $USE_PREINST_LIBS = true ]; then
  if [ $target = cheyenne ]; then
    export MOD_PATH=/glade/p/ral/jnt/tools/nwprod.update2018/lib/modulefiles
  else
    export MOD_PATH=/scratch3/NCEPDEV/nwprod/lib/modulefiles
  fi
else
  export MOD_PATH=${cwd}/lib/modulefiles
fi

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

cd gfs_post.fd/sorc
sh build_ncep_post.sh
