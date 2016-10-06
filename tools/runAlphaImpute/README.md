# runAlphaImpute.sh #

Script for easier running [AlphaImpute](http://www.alphagenes.roslin.ed.ac.uk/alphasuite/alphaimpute/),
for several input (genotype) files and for running under Sun Grid Engine (SGE).

## How does AlphaImpute work? ##

Magic. And mathematics. The best kind of magic.

AlphaImpute works throughs a series of steps ("RestartOption") and calls to supporting 
binaries (calculating gene probabilities and phasing).
It does support running through all steps and calls with a single call, but we have 
experienced that it sometimes does not work, or that we might want more control with how
the other binaries are called.

Furthermore, AlphaImpute is hardcoded to use a single filename for a parameter file 
(`AlphaImputeSpec.txt`), which might be cause of annoyance when you want to perform the 
same imputation on several chromosomes in parallel, as is recommended.

## How to use ##

Always check most recent help message:

~~~ .bash
./runAlphaImpute.sh -help

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
~~~

## Requirements and limitations

* This repository does not contain the binaries of AlphaImpute.
* The script requires [GNU parallel](http://www.gnu.org/software/parallel/) of which compiled version are kept within this repository.
* This script is only designed for AlphaImpute v. 1.3.2.
* If using HMM options in AlphaImpute, the number of available processors in the HMM options are not updated by the script.
  

## Examples 

Suppose a directory with contents as below with a genotype file for each chromosome, a spec file, and a pedigree.
The spec file and pedigree is the same for all chromosomes in this example, but we wish to impute the chromosomes separatly.
NB. The genotype file contains the genotypes of both fully genotypes animals and genotypes at lower densities.

    ~/data/
	      /myspecfile.txt
		  /pedigree.txt
		  /Chrom1.txt
		  /Chrom2.txt
		  /Chrom3.txt

The way of AlphaImpute requires that you copy each genotype file to a separate folder, together with `pedigree.txt` and `myspecfile.txt` (renaming it to `AlphaImputeSpec.txt`), 
updating `AlphaImputeSpec.txt` to use the correct files, running AlphaImpute within that folder, and perhaps copying back everything.

This script does all that for you. To impute the three chromosomes above simply run:

    ./runAlphaImpute.sh myspecfile.txt -g Chrom1.txt --TMPDIR chrom1
	./runAlphaImpute.sh myspecfile.txt -g Chrom2.txt --TMPDIR chrom2
	./runAlphaImpute.sh myspecfile.txt -g Chrom3.txt --TMPDIR chrom3

This will create subfolders `chrom1`, `chrom2`, and `chrom3`, and do all the work within these. No fuss.
If you do not specify the `--TMPDIR` argument, imputation will be performed within the current folder, which is unfortunate as we are doing three concurrent imputations.

If you instead want to perform the imputation in a temporary folder, you would most likely be interested in copying (some of) the contents back. You could do

    ./runAlphaImpute.sh myspecfile.txt --TMPDIR TMPDIR

This instance will run AlphaImpute using the files as specified in `myspecfile.txt` as is. All the folders generated by AlphaImpute will be copied back into this folder. 
To put it in specific folders, and in this case, impute several chromosomes at once while only retaining the results, do:

    ./runAlphaImpute.sh myspecfile.txt -g Chrom1.txt --TMPDIR TMPDIR --savedir Chrom1 --save Results
	./runAlphaImpute.sh myspecfile.txt -g Chrom2.txt --TMPDIR TMPDIR --savedir Chrom2 --save Results
	./runAlphaImpute.sh myspecfile.txt -g Chrom3.txt --TMPDIR TMPDIR --savedir Chrom3 --save Results
	
### Using with Sun Grid Engine

Just submit the script with options for a job. For qsub specific arguments, refer to your local manual and guidelines.

**There are some system specific settings for running on the Eddie3 grid computing at the University of Edinburgh**

For the above example, just submit as following

    qsub runAlphaImpute.sh myspecfile.txt -g Chrom1.txt --savedir Chrom1 --save Results
	qsub runAlphaImpute.sh myspecfile.txt -g Chrom2.txt --savedir Chrom2 --save Results
	qsub runAlphaImpute.sh myspecfile.txt -g Chrom3.txt --savedir Chrom3 --save Results
	

