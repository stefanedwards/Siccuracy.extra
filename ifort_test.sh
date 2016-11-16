#!/bin/bash
#$ -cwd
#$ -j y
#$ -m aes
#$ -M stefan.hoj-edwards@roslin.ed.ac.uk

BASEDIR=`pwd`
SRCDIR=$BASEDIR/Siccuracy
LIBDIR=$TMPDIR/lib

. /etc/profile.d/modules.sh
module load R/3.2.2
R_LD_PATH=$LD_LIBRARY_PATH
R_LIBS=$LIBDIR:/home/shojedw/R/x86_64-pc-linux-gnu-library/3.2:/exports/cmvm/eddie/eb/groups/hickey_group/shojedw/R/3.2.2:$R_LIBS
module load intel/2016

echo `date`
echo "BASEDIR:          $BASEDIR"
echo "SRCDIR:           $SRCDIR"
echo "LIBDIR:           $LIBDIR"
echo "R_LIBS:           $R_LIBS"
echo "R_LD_LIB.PATH:    $R_LD_PATH"
echo "LD_LIBRARY_PATH:  $LD_LIBRARY_PATH"

mkdir -p $LIBDIR
cp -R $SRCDIR $TMPDIR
cd $TMPDIR
rm -f Siccuracy/src/*.o
R CMD INSTALL -l $LIBDIR Siccuracy || exit 1

cp $SRCDIR/src/*.f95 $LIBDIR/Siccuracy/libs
cd $LIBDIR/Siccuracy/libs

rm Siccuracy.so

o=
for f in `ls *.f95`; do
  g=${f%.*}
  cp $f ${g}.f90
  args=" -warn all -O3 -fpic -c ${g}.f90 -o ${g}.o"
  echo "ifort $args"
  ifort $args
  #ifort -warn all -O3 -fpic -c ${g}.f90 -o ${g}.o
  o="$o ${g}.o"
done

ifort -shared -L${R_LIB_PATH} -L/usr/local/lib64 -o Siccuracy.so $o -L${R_LIB_PATH} -lR || exit 1
cd $TMPDIR

Rscript --vanilla --quiet -e 'library(testthat); library(Siccuracy);' -e 'print(.libPaths())' -e "testthat:::run_tests('Siccuracy', '$SRCDIR/tests/testthat',  filter=NULL, reporter='summary')"
