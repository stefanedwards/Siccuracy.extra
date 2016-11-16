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
module load intel/2016

echo `date`
echo "BASEDIR:          $BASEDIR"
echo "SRCDIR:           $SRCDIR"
echo "LIBDIR:           $LIBDIR"
echo "R_LIBS:           $R_LIBS"
echo "LD_LIBRARY_PATH:  $LD_LIBRARY_PATH"


mkdir -p $LIBDIR
R CMD INSTALL -l $LIBDIR $SRCDIR
R_LIBS=$LIBDIR:$R_LIBS

cp $SRCDIR/src/*.f95 $LIBDIR/Siccuracy/libs
cd $LIBDIR/Siccuracy/libs

rm Siccuracy.so

o=
for f in `ls *.f95`; do
  g=${f%.*}
  cp $f ${g}.f09
  ifort -warn all -O3 -fpic -c ${g}.f90 -o ${g}.o
  o="$o ${g}.o"
done

ifort -shared -L$LD_LIBRARY_PATH -L/usr/local/lib64 -o Siccuracy.so $o -L$LD_LIBRARY_PATH -lR
stat=$?
if [ $stat .neq 0 ]; then
  exit 1
fi
cd $TMPDIR

Rscript R --vanilla --quiet -e 'library(testthat); library(Siccuracy);' -e 'print(.libPaths())' -e "testthat:::run_tests('Siccuracy', test_path, filter=NULL, reporter='SummaryReporter')"
