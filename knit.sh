#/bin/bash -vx
#$ -cwd
#$ -j y
#$ -l h_vmem=4G
#$ -pe sharedmem 4
#  -V
#$ -m as
#$ -M stefan.hoj-edwards@roslin.ed.ac.uk

echo Host: $(hostname)

. /etc/profile.d/modules.sh
module load R/3.2.2
#module load igmm/apps/gcta/1.24.7
#module load igmm/apps/plink/1.90b1g
#module load igmm/apps/dissect/1.2
#module load igmm/libs/boost/1.59.0
#module load igmm/apps/shapeit/2r837
module load intel/2016
module load igmm/libs/lapack/3.5.0
module load openmpi/1.10.1


export MKL_NUM_THREADS=$NSLOTS
export R_LIBS_SITE=/home/shojedw/R/x86_64-pc-linux-gnu-library/3.2:/exports/cmvm/eddie/eb/groups/hickey_group/shojedw/R/3.2.2:/exports/applications/apps/SL7/R/3.2.2/lib64/R/library:$R_LIBS
Rscript --no-restore -e "cat(.libPaths(), sep='\n', '\n'); library('knitr'); knit('$1')"
