#! /usr/bin/env bash
set -eux

set +e
source ./machine-setup.sh > /dev/null 2>&1
set -e
cwd=`pwd`

USE_PREINST_LIBS=${USE_PREINST_LIBS:-"true"}
if [ $USE_PREINST_LIBS = true ]; then
  if [ $target = cheyenne ]; then
    export MOD_PATH=/glade/p/ral/jnt/tools/nwprod/lib/modulefiles
  else
    export MOD_PATH=/scratch3/NCEPDEV/nwprod/lib/modulefiles
  fi
  source ../modulefiles/module_nemsutil.$target             > /dev/null 2>&1
else
  export MOD_PATH=${cwd}/lib/modulefiles
  if [ $target = wcoss_cray ]; then
    source ../modulefiles/module_nemsutil.${target}_userlib > /dev/null 2>&1
  else
    source ../modulefiles/module_nemsutil.$target           > /dev/null 2>&1
  fi
fi

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

for prog in nemsio_get.fd  mkgfsnemsioctl.fd  nemsio_cvt.fd  nemsio_read.fd ;do
 cd ${cwd}/${prog}
 make -f makefile
done

exit
