#!/bin/bash
#$ -cwd
#$ -j y

BINDIR=~/Code/Tools/bin/mac
WORKDIR=$(pwd)
if [[ $HOSTNAME == node*  ]]; then  # #grepl('login[0-9]*.ecdf.ed.ac.uk', HOSTNAME))
  # Eddie3!
  BINDIR=/exports/cmvm/datastore/eb/groups/hickey_group/Programs/AlphaImpute/v1.3.2
  WORKDIR=TMPDIR
  export PATH=$PATH:/exports/cmvm/eddie/eb/groups/hickey_group/shojedw/bin # For nicey parallel 
fi

# Argument parsing
verbose=1
specfile=
genotype=
pedigree=
phasedanim=
phasefile=
trues=
incremental=FALSE
savedir='./'
savestr='All'
ncpu=-1
BASEDIR=$(pwd)
inputbylftp=FALSE
inputlftpdir=
savebylftp=FALSE
savelftpdir=
lftphost=cmvm.datastore.ed.ac.uk

alldirs='Miscellaneous Phasing Results InputFiles GeneProb IterateGeneProb'


if [ -z "$NSLOTS" ]; then
  NSLOTS=1
fi

command -v parallel >/dev/null 2>&1 || { 
	echo >&2 'Script requires GNU parallel (http://www.gnu.org/software/parallel/) to work.';
	echo >&2 'Stefan has compiled copies for Mac and Linux.';
	echo >&2 'Aborting.'; 
	exit 1; 
	}


show_help() {
 cat << EOF
 Usage: ${0##*/}  [options] spec-file
 Run AlphaImpute, either locally or as a job.

    spec-file [Required]
        Filename of AlphaImpute spec file. Does not have to be named AlphaImputeSpec.txt,
        as this script will take care of providing the correct spec file at the respective
        steps.
                
   Options for overriding input files in the spec file.
   Useful for mass submitting chromosomes on same popuplation.    
	 Files mentioned in spec file (pedigree, genotype, etc.) are read relative to current
   directory. AlphaImpute does not seem to support relative file names (I might be wrong).
    -g,  --genotype       Input genotypes.
    -p,  --pedigree       Pedigree.
    -pa, --phasedanimals  File listing phased animals.
    -pf, --phasefile      File with phased genotypes.
    -t,  --trues          True genotypes. Avoid.


    -h  Display this help and exit.
    --incremental 
        Copy backs __all__ intermediate files after each stage of AlphaImpute/GeneProbs/Phasing.
    --ncpu Integer. 
        Number of processors available for overriding NumberOfProcessorsAvailable.
        Does not affect how many parallel processes are run (this is set by \$NSLOTS).
        If -1 (default), do nothing. If 0, uses value \$NSLOTS.
    --save 
        Comma separated list of files and folders not deleted and copied to local or savedir.
        If set to 'All', all folders created by AlphaImpute are saved.
        If set to 'None', nothing is copied back.
        Defaults to 'Results'.
        Choose between Miscellaneous,Phasing,Results,InputFiles,GeneProb,IterateGeneProb.
    --savedir path
        Absolute or relative path for copying back folders specified in --save.
    --TMPDIR path
        Sets working directory for AlphaImpute. Defaults to current directory if script
        is running locally, defaults to temporary directory if run through SGE or when set to 'TMPDIR'.
        Spec file and input files mentioned in spec file are copied to TMPDIR.
    -v  Verbose mode. Outputs extra information re. how this script is running.
    		Level 0: No extra output is printed (except AlphaImpute logs).
    		Level 1: Prints AlphaImputeSpec file and some status.
    		Level 2: Lots and lots of output!
    
    
EOF
}




# argument parsing : http://mywiki.wooledge.org/BashFAQ/035
position=0
while :; do
  case $1 in
		--clean-before)
		  cleanbefore=TRUE
		  ;;
		--clean-after)
		  cleanafter=TRUE
		  ;;
	  -g|--genotype) # Takes an optional argument
		  if [ -n "$2" ]; then
		    genotype=$2
		    shift
		  else
			  printf 'ERROR: "--genotype" requires a filename.\n' >&2
		    exit 1
		  fi
		  ;;
		-h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
			show_help
			exit
			;;		  
		--incremental)
			incremental=TRUE
			;;
	  -p|--pedigree) # Takes an optional argument
		  if [ -n "$2" ]; then
		    pedigree=$2
		    shift
		  else
			  printf 'ERROR: "--pedigree" requires a filename.\n' >&2
		    exit 1
		  fi
		  ;;
	  -pa|--phasefile) # Takes an optional argument
		  if [ -n "$2" ]; then
		    phasefile=$2
		    shift
		  else
			  printf 'ERROR: "--phasefile" requires a filename.\n' >&2
		    exit 1
		  fi
		  ;;		
	  -pf|--phasedanimals) # Takes an optional argument
		  if [ -n "$2" ]; then
		    phasedanim=$2
		    shift
		  else
			  printf 'ERROR: "--phasedanimals" requires a filename.\n' >&2
		    exit 1
		  fi
		  ;;		 		    
		--ncpu)
			if [ -n "$2" ]; then
			  ncpu=$2
			  shift
			else
			  printf 'ERROR: "--ncpu" requires an integer for number of available processors.\n' >&2
		    exit 1
		  fi
		  ;;						
	  --save) # Takes an optional argument
		  if [ -n "$2" ]; then
		    savestr=$2
		    shift
		  else
			  printf 'ERROR: "--save" requires specifying a directory to work in.\n' >&2
		    exit 1
		  fi
		  ;;
	  --savedir) # Takes an optional argument
		  if [ -n "$2" ]; then
		    savedir=$2
		    shift
		  else
			  printf 'ERROR: "--savedir" requires specifying a directory to work in.\n' >&2
		    exit 1
		  fi
		  ;;
	  --TMPDIR) # Takes an optional argument
		  if [ -n "$2" ]; then
		    WORKDIR=$2
		    shift
		  else
			  printf 'ERROR: "--TMPDIR" requires specifying a directory to work in.\n' >&2
		    exit 1
		  fi
		  ;;
    --TMPDIR=?*)
    	WORKDIR=${1#*=}  # Delete everything up to "=" and assign the remainder.
    	;;
		--TMPDIR=) # Requires something after =
			printf 'ERROR: "--TMPDIR" requires specifying a directory to work in.\n' >&2
			exit 1
			;;		
	  -t|--trues) # Takes an optional argument
		  if [ -n "$2" ]; then
		    trues=$2
		    shift
		  else
			  printf 'ERROR: "--trues" requires a filename.\n' >&2
		    exit 1
		  fi
		  ;;		  		  
	  -v|--verbose)
	    verbose=$((verbose + 1)) # Each -v argument adds 1 to verbosity.
      ;;
    --)              # End of all options.
    	printf 'End of all options?'
      shift
      break
      ;;
    -?*)
      printf 'WARNING: Unknown option (ignored): %s\n' "$1" >&2
      ;;
    *)               # Default case: If no more options then break out of the loop.
		  position=$((position+1))
      if [ ${#1} -eq 0 ]; then
	      break
	    fi
		  case $position in
		    1)
		      specfile=$1
		      ;;
		    #2)
		    #  genotype=$1
		    #  ;;
		    *)
		      printf 'WARNING: Unknown positional argument (ignored): %s\n' "$1" >&2
		      exit 1
		  esac 
  esac
  shift
done

# Check arguments.
if [ -z "$specfile" ]; then
  printf 'Needs a specfile!' >&2
  exit 1
fi

if [ $WORKDIR == 'TMPDIR' ]; then
  #WORKDIR=$TMPDIR
  WORKDIR=`mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir'`
  test $verbose -ge 2 && echo "TMPDIR now set to \$TMPDIR \($WORKDIR\)."
fi
if [ ! -d "$WORKDIR" ]; then
  mkdir -p $WORKDIR
fi

IFS=',' read -r -a save <<< "$savestr"
test $verbose -ge 2 && echo "save expanded to: ${save[@]} (${#save[@]} entries)"
read -r -a alldirarray <<< "$alldirs"
if [ "${save[0]}" != 'All' -a "${save[0]}" != "None" ]; then
  saver=()
  for d in ${save[@]}; do
    for j in ${alldirarray[@]}; do
      if [ $d == $j ]; then
        saver+=($d)
      fi
    done
  done
  
  if [ ${#saver[@]} -eq 0 ]; then
    printf 'None of the elements in "--save" are known directories from AlphaImpute.\n' >&2 
    exit 1
  fi
  save=$saver
fi

if [ ! -z $savedir -a ${savedir:0:1} != '/' ]; then
  savedir=$BASEDIR/$savedir
elif [ ! $BASEDIR -ef $WORKDIR ]; then
  savedir=$BASEDIR
fi
test $verbose -ge 1 && echo "Save directory: $savedir"

# Test if lftp works and necessary
if [ ! $BASEDIR -ef $WORKDIR ]; then
	if [[ $BASEDIR =~ /exports/cmvm/datastore/ ]]; then
		inputbylftp=TRUE
		inputlftpdir=$(echo "$BASEDIR" | sed 's/^\/exports//g')
	fi
	if [[ $savedir =~ /exports/cmvm/datastore/ ]]; then
		savebylftp=TRUE
		savelftpdir=$(echo "$savedir" | sed 's/^\/exports//g')
	fi

	if [ $inputbylftp == "TRUE" -o $savebylftp == "TRUE" ]; then
		echo 'Checking key authentication for copying files directly to datastore...'
		login=$(whoami)
		cat /dev/null | lftp -u ${login},NULL -p 22222 sftp://${lftphost} -e "ls" > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo 'Key-checking failed!'
			inputbylftp=FALSE
			savebylftp=FALSE
		fi
	fi
  test $inputbylftp == 'TRUE' && echo "Will copy input files via ftp from $inputlftpdir."
  test $savebylftp == 'TRUE' && echo "Will copy results via ftp to $savelftpdir."
fi


if [ $verbose -ge 2 ]; then
  echo "Local directory (start): $BASEDIR"
  echo "specfile (pos. 1):       $specfile"
  echo "--TMPDIR:                $WORKDIR"
  echo "--incremental:           $incremental"
  echo "--ncpu:                  $ncpu"
  echo "--genotype               $genotype"
  echo "--pedigree               $pedigree"
  echo "--phasedanimals          $phasedanim"
  echo "--phasefile              $phasefile"
  echo "--trues                  $true"
  echo "--save                   ${save[@]}"
  echo "--savedir                $savedir"
fi


# Read Spec file
IFS=$'\n' read -d '' -r -a speclines < $specfile
IFS=' ,' read -r -a pedigreeline <<< ${speclines[0]}
test $verbose -ge 1 && echo "Picked up pedigree file: ${pedigreeline[1]}."
IFS=' ,' read -r -a genotypeline <<< ${speclines[1]}
test $verbose -ge 1 && echo "Picked up genotype file: ${genotypeline[1]}."
IFS=' ,' read -r -a phasedanimalsline <<< ${speclines[17]}
test $verbose -ge 1 && echo "Picked up UserDefinedAlphaPhaseAnimalsFile file: ${phasedanimalsline[1]}."
IFS=' ,' read -r -a phasingline <<< ${speclines[18]}
test $verbose -ge 1 && echo "Picked up PrePhasedFile file: ${phasingline[1]}."
IFS=' ,' read -r -a trueline <<< ${speclines[23]}
test $verbose -ge 1 && echo "Picked up TrueGenotypeFile file: ${trueline[1]}."


if [ -z "$genotype" ]; then
  genotype=${genotypeline[1]}
fi
if [ -z "$pedigree" ]; then
  pedigree=${pedigreeline[1]};
fi
if [ -z "$phasedanim" ]; then
  phasedanim=${phasedanimalsline[1]}
fi
if [ -z "$phasefile" ]; then
  phasefile=${phasingline[1]}
fi
if [ -z "$trues" ]; then
  trues=${trueline[1]}
fi


IFS=' ,' read -r -a ncpuline <<< ${speclines[11]}
test $verbose -ge 2 && echo "Picked up number of processors from specfile: ${ncpuline[1]}."
if [ $ncpu -eq 0 ]; then
  ncpu=$NSLOTS
elif [ $ncpu -lt 0 ]; then 
  ncpu=${ncpuline[1]}
fi



cd $WORKDIR
WORKDIR=$(pwd)
test $verbose -ge 2 && echo "Current directory: $(pwd)"

if [ ! $BASEDIR -ef $WORKDIR ]; then
	if [ $inputbylftp == "TRUE" ]; then
		get="get $genotype "
		test "$pedigree" != 'None' && get="$get $pedigree "
		test "$phasedanim" != 'None' && get="$get $phasedanim "
		test "$phasefile" != 'None' && get="$get $phasefile "
		test "$trues" != 'None' && get="$get $trues "
		echo $get from sftp://${lftphost}/$inputlftpdir
                lftp -u ${login},NULL -p 22222 sftp://${lftphost}${inputlftpdir} -e "$get ; exit"
	else
		cp $BASEDIR/$genotype .
		test "$pedigree" != 'None' && cp $BASEDIR/$pedigree .
		test "$phasedanim" != 'None' && cp $BASEDIR/$phasedanim .
		test "$phasefile" != 'None' && cp $BASEDIR/$phasefile .
		test "$trues" != 'None' && cp $BASEDIR/$trues .    
  fi
fi

#test if input files exists
stopswitch=FALSE
if [ ! -r "$genotype" ]; then
  echo ERROR: Was not able to read $genotype for Genotypes. >&2
  stopswitch=TRUE
fi
if [  "$pedigree" != 'None' -a ! -r "$pedigree" ]; then
  echo ERROR: Was not able to read $pedigree for Pedigree. >&2
  stopswitch=TRUE
fi
if [  "$phasedanim" != 'None' -a ! -r "$phasedanim" ]; then
  echo ERROR: Was not able to read $phasedanim for UserDefinedAlphaPhaseAnimalsFile. >&2
  stopswitch=TRUE
fi
if [  "$phasefile" != 'None' -a ! -r "$phasefile" ]; then
  echo ERROR: Was not able to read $phasefile for PrePhasedFile. >&2
  stopswitch=TRUE
fi
if [  "$trues" != 'None' -a ! -r "$trues" ]; then
  echo ERROR: Was not able to read $trues for TrueGenotypeFile. >&2
  stopswitch=TRUE
fi
test "$stopswitch" == 'TRUE' && exit 1


# Number of columns
ncol=`head -n 1 $genotype | awk '{print NF}'`
ncol=$(( ncol - 1 ))


make_spec() {
  echo "PedigreeFile ,$pedigree" 
  echo "GenotypeFile ,$genotype" 
  echo "${speclines[2]}"
  echo "NumberSnp ,$ncol"
  echo "${speclines[4]}" 
  echo "${speclines[5]}" 
  echo "${speclines[6]}" 
  echo "${speclines[7]}" 
  echo "${speclines[8]}" 
  echo "${speclines[9]}" 
  echo "${speclines[10]}" 
  echo "NumberOfProcessorsAvailable ,$ncpu" 
  echo "${speclines[12]}" 
  echo "PreprocessDataOnly ,$1" 
  echo "${speclines[14]}" 
  echo "${speclines[15]}" 
  echo "${speclines[16]}" 
  echo "UserDefinedAlphaPhaseAnimalsFile ,$phasedanim" 
  echo "PrePhasedFile ,$phasefile" 
  echo "BypassGeneProb ,$2"  
  echo "RestartOption ,$3"  
  echo "${speclines[21]}" 
  echo "${speclines[22]}" 
  echo "TrueGenotypeFile, $trues" 
}  
export -f make_spec
  
# Output all dem specs!
if [ $verbose -ge 1 ]; then
  echo
  echo 'Generated spec file.'
  make_spec 'At first' 'At first' 'Depends'
fi 


# Finally, get binaries if possible.
alphaimp='AlphaImputev1.3.2'
geneprob='GeneProbForAlphaImpute'
alphaphas='AlphaPhase1.1'
if [ ! -z $BINDIR ]; then
  cp $BINDIR/$alphaimp AlphaImpute
  alphaimp="$WORKDIR/AlphaImpute"
  cp $BINDIR/$geneprob $geneprob
  geneprob="$WORKDIR/$geneprob"
  cp $BINDIR/$alphaphas $alphaphas
  alphaphas="$WORKDIR/$alphaphas"
  chmod u+x $alphaimp $geneprob $alphaphas
fi
#######################################################################
# Setup complete. Now run AlphaImpute.
#######################################################################

echo 'Starting AlphaImpute step 1.'
make_spec 'Yes' 'No' '1' > AlphaImputeSpec.txt
# Because AlphaImpute complains when it cannot delete these folders...
mkdir -p Miscellaneous Phasing Results InputFiles GeneProb IterateGeneProb

$alphaimp
stat=$?
if [ $incremental == 'TRUE' ]; then
  if [ $savebylftp == 'TRUE' ]; then
  	lftp -u ${login},NULL -p 22222 sftp://$lftphost -e "mirror -v -c -R -P2 --no-perms "$WORKDIR" "$savelftpdir"/; exit" 
  else
    rsync -r $WORKDIR/ $save
  fi
fi
if [ $stat -ne 0 ]; then
  printf 'ERROR: AlphaImpute failed at restart 1 with exit status %i\n' "$stat" >&2
  exit 1
fi

echo 'Running GeneProbs if necessary.'
run_geneprob() {
  cd $1
  if [ ! -f GpDone.txt ]; then
    if [ -f GeneProbForAlphaImpute ]; then
      ./GeneProbForAlphaImpute  > GeneProbOut.txt
    else
    	$geneprob   > GeneProbOut.txt
    fi
    echo "$1 done."
  fi
}
export -f run_geneprob
parallel -j $NSLOTS run_geneprob ::: GeneProb/*
echo 'All geneprobs done.'
if [ $incremental == 'TRUE' ]; then
  if [ $savebylftp == 'TRUE' ]; then
  	lftp -u ${login},NULL -p 22222 sftp://$lftphost -e "mirror -v -c -R -P2 --no-perms "$WORKDIR" "$savelftpdir"/; exit" 
  else
    rsync -r $WORKDIR/ $save
  fi
fi


echo 'Running AlphaPhase if necessary.'
run_phasing() {
  cd $1
  if [ ! -f out ]; then
    mkdir -p Miscellaneous PhasingResults
  	if [ -f AlphaPhase1.1 ]; then
  		./AlphaPhase1.1 > out.txt
  	else
  		$alphaphase > out.txt
  	fi
  	echo "$1 done."
  fi
}
export -f run_phasing
parallel -j $NSLOTS run_phasing ::: Phasing/Phase*
echo 'All phasing done.'
if [ $incremental == 'TRUE' ]; then
  if [ $savebylftp == 'TRUE' ]; then
  	lftp -u ${login},NULL -p 22222 sftp://$lftphost -e "mirror -v -c -R -P2 --no-perms "$WORKDIR" "$savelftpdir"/; exit" 
  else
    rsync -r $WORKDIR/ $save
  fi
fi

echo 'Starting AlphaImpute step 3.'
make_spec 'No' 'No' '3' > AlphaImputeSpec.txt
$alphaimp
stat=$?
if [ $incremental == 'TRUE' ]; then
  if [ $savebylftp == 'TRUE' ]; then
  	lftp -u ${login},NULL -p 22222 sftp://$lftphost -e "mirror -v -c -R -P2 --no-perms "$WORKDIR" "$savelftpdir"/; exit" 
  else
    rsync -r $WORKDIR/ $save
  fi
fi
if [ $stat -ne 0 ]; then
  printf 'ERROR: AlphaImpute failed at restart 3 with exit status %i\n' "$stat" >&2
  exit 1
fi

echo 'Running IterateGeneProbs if necessary.'
parallel -j $NSLOTS run_geneprob ::: IterateGeneProb/GeneProb*
echo 'All Iterate geneprobs done.'


echo 'Starting AlphaImpute step 4.'
make_spec 'No' 'No' '4' > AlphaImputeSpec.txt
$alphaimp
stat=$?
if [ $incremental == 'TRUE' ]; then
  if [ $savebylftp == 'TRUE' ]; then
  	lftp -u ${login},NULL -p 22222 sftp://$lftphost -e "mirror -v -c -R -P2 --no-perms "$WORKDIR" "$savelftpdir"/; exit" 
  else
    rsync -r $WORKDIR/ $save
  fi
fi
if [ $stat -ne 0 ]; then
  printf 'ERROR: AlphaImpute failed at restart 4 with exit status %i\n' "$stat" >&2
  exit 1
fi


# Prepare to copy back any contents.
if [ "${save[0]}" != 'None' ]; then
  if [ "${save[0]}" == 'All' ]; then
    read -r -a save <<< "$alldirs"
  fi
  if [ $savebylftp == 'TRUE' ]; then
    put="mkdir -p ${savelftpdir} ;"
    put="$put put -O ${savelftpdir} AlphaImputeSpec.txt ; "
    for d in ${save[@]}; do
      put="$put mirror -v -c -R -P2 --no-perms \"$WORKDIR/$d\" \"$savelftpdir/\" ; "
    done
    put="$put exit"
    echo $put
    lftp -u ${login},NULL -p 22222 sftp://${lftphost}/ -e "$put"  
  else
	  mkdir -p $savedir
		cp AlphaImputeSpec.txt $savedir
		parallel -j $NSLOTS rsync -r $WORKDIR/{}/ $savedir/{} ::: ${save[@]}  
  fi
fi
