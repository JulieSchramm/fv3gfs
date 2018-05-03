#!/bin/sh -l
#PBS -N fv3gfs_V1_C192
#PBS -o out_C192
#PBS -e err_C192
#PBS -A P48503002
#PBS -q economy
###PBS -l select=48:ncpus=36:mpiprocs=36
### Request 12 nodes, each with 36 MPI tasks
#PBS -l select=8:ncpus=24:mpiprocs=24
#PBS -l walltime=00:40:00

set -x

#------------------------------------------------------------------
#------------------------------------------------------------------
# Running NEMS FV3GFS on Cheyenne
#------------------------------------------------------------------
#notes:
# this job card is for C96 case. If you are running
# C384 or C768 cases, please make the following change:
#
#   for C96, change line 8 and line 33 to:
#      #PBS -l select=8:ncpus=36:mpiprocs=36
#      export CASE=C96
#
#   for C192, change line 8 and line 33 to:
#      #PBS -l select=16:ncpus=36:mpiprocs=36
#      export CASE=C192
#
#   for C384, change line 8 and line 33 to:
#      #PBS -l select=32:ncpus=36:mpiprocs=36
#      export CASE=C384            
#
#   for C768, change line 8 and line 33 to:
#      #PBS -l select=64:ncpus=36:mpiprocs=36
#      export CASE=C768            
#
#------------------------------------------------------------------

export machine=cheyenne           #WCOSS_C, theia, etc
export PSLOT=fv3gfs               #user-defined experiment name
export CASE=C192                  #resolution, C96, C384 or C768
export CDATE=2016021000           #initial condition dates  2016021000 2017081712 
                                  #                         2018022800  2018032212

# Add ESMF shared library path to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/glade/p/work/heinzell/fv3/esmf-7.1.0_bs52/intel-17.0.1/mpt-2.15f/lib/libO/Linux.intel.64.mpi.default

export BASE_DATA=/glade/p/ral/jnt/GMTB/FV3GFS_V1_RELEASE # data directory
export FIX_FV3=$BASE_DATA/fix/fix_fv3                 #model fixed fields
export IC_DIR=$BASE_DATA/ICs                          #forecast initial conditions 

# temporary running directory
export DATA=/glade/scratch/$LOGNAME/${CASE}${PSLOT}${CDATE}     

# This will clean out your $DATA directory
if [ -d $DATA ]; then rm -rf $DATA ; fi

# directory to save output
export ROTDIR=/glade/scratch/$LOGNAME/$PSLOT/$CASE                    

# NEMS FV3GFS forecast executable directory
FV3DIR=${1:-`pwd`/../../..}
FV3DIR_RELEASE=${1:-`pwd`/..}
export FCSTEXECDIR=$FV3DIR/NEMS/exe

export FHMAX=24                                       #maximum forecast hours
export FHOUT=6                                        #forecast output frequency in hours
#---------------------------------------------------------
#---------------------------------------------------------
case $CASE in
  C96)  export DELTIM=1800; export layout_x=6; export layout_y=8;  export NODES=24; 
        export master_grid=1deg;   export REMAP_TASKS=48 ;;
  C192) export DELTIM=450 ; export layout_x=4; export layout_y=6;  export NODES=8;
        export master_grid=0p5deg; export REMAP_TASKS=72 ;;
  C384) export DELTIM=450 ; export layout_x=12; export layout_y=16;  export NODES=96;
        export master_grid=0p5deg; export REMAP_TASKS=96 ;;
  C768) export DELTIM=225 ; export layout_x=16; export layout_y=24; export NODES=192;
        export master_grid=0p25deg; export REMAP_TASKS=384 ;;
  *)    echo "grid $CASE not supported, exit"
        exit ;;
esac

export PARM_FV3DIAG=$FV3DIR_RELEASE/parm/parm_fv3diag
export FORECASTSH=$FV3DIR_RELEASE/scripts/exglobal_fcst_nemsfv3gfs.sh         

#---determine task configuration
export nth_f=2                                         # number of threads 
export npe_node_f=24
export task_per_node=$((npe_node_f/nth_f))
export tasks=$((NODES*task_per_node*nth_f))                  # number of tasks 
export NTHREADS_REMAP=$nth_f


export MODE=32bit           			       # dycore precision:   32bit, 64bit
export TYPE=nh         				       # hydrostatic option: nh, hydro
export HYPT=off           			       # hyperthreading:     on, off  
export COMP="prod"        			       # compiling mode:     debug, repro, prod
if [ ${HYPT} = on ]; then
   export hyperthread=".true."
   export j_opt="-j 2"
else
   export hyperthread=".false."
   export j_opt="-j 1"
fi
export FCSTEXEC=fv3_gfs_${TYPE}.${COMP}.${MODE}.x

cp $FV3DIR/NEMS/src/conf/module-setup.sh.inc module-setup.sh
cp $FV3DIR/NEMS/src/conf/modules.nems modules.fv3
source ./module-setup.sh
module use $( pwd -P )
module load modules.fv3
module list

export mpiexec="mpiexec_mpt -n ${tasks}"
export FCST_LAUNCHER="$mpiexec"

echo "Model started:  " `date`
export MPI_TYPE_DEPTH=20
export OMP_STACKSIZE=512M
export OMP_NUM_THREADS=$nth_f
export ESMF_RUNTIME_COMPLIANCECHECK=OFF:depth=4
#--------------------------------------------------------------------------

#--execute the forecast
$FORECASTSH
if [ $? != 0 ]; then echo "forecast failed, exit"; exit; fi

echo "fcst job is done"

#JLS Just run the forecast
exit

#-------------------------------------------------------------------------
#--convert 6-tile output to global arrary in netCDF format
ymd=`echo $CDATE |cut -c 1-8`
cyc=`echo $CDATE |cut -c 9-10`
export DATA=$ROTDIR/gfs.$ymd/$cyc
export IPD4=YES
export REMAPSH=$FV3DIR_RELEASE/ush/fv3gfs_remap.sh            #remap 6-tile output to global array in netcdf
export REMAPEXE=$FV3DIR_RELEASE/exec/fregrid_parallel
export REMAP_LAUNCHER="$mpiexec"

cp $FV3DIR_RELEASE/modulefiles/fv3gfs/fre-nctools.${machine} module.fre-nctools
module load module.fre-nctools
module list

$REMAPSH

echo "Remap job is done!"

exit

