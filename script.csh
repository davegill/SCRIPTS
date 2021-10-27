#!/bin/csh

#	Script to run regression tests within a container

#	It looks like we may run out of stack sometimes, so make it
#	as large as we can.

unlimit stacksize

#	We are either asking for a BUILD or a RUN function. This script is
#	set up in two pieces (the over arching IF test) based on this value.

set WHICH_FUNCTION    = $1
shift

#	The BUILD function runs the clean (optional), configure, and compile
#	steps. Input is provided for whether or not to run clean, the options
#	appended at the end of the configure command, the numerical choices and
#	nesting options for configure, and the target for the compile command.

if      ( $WHICH_FUNCTION == BUILD ) then

	#	There are at least four args that are required for a BUILD step.
	#	1. Clean? If yes then the value is CLEAN, if no then any other string.
	#	2. The configuration number. For example, Linux GNU MPI = 34.
	#	3. The nest option for the configuration. Always 1, unless a moving domain.
	#	4. The build target for compile, for example, "em_real".

	if ( ${#argv} < 4 ) then
		touch /wrf/wrfoutput/FAIL_BUILD_ARGS
		exit ( 1 )
	endif

	set CLEAN             = $1
	set CONF_BUILD_NUM    = $2
	set CONF_BUILD_NEST   = $3
	set COMP_BUILD_TARGET = $4
	shift
	shift
	shift
	shift

	#	Check for additional arguments, first those that are passed to configure.
	#	These are denoted as they start with a leading dash "-". If we find a option
	#	that does not fit this criteria, we move to the next type of optional
	#	input to the BUILD step.

	set CONF_OPT = " "
	while ( ${#argv} )
		set HOLD = $1
		set str = "-"
		set loc = `awk -v a="$HOLD" -v b="$str" 'BEGIN{print index(a,b)}'`
		if ( $loc == 1 ) then
			set CONF_OPT = ( $CONF_OPT " " $HOLD )
			shift
		else
			break
		endif
	end

	#	The second type of optional input is for setting env variables. The syntax is
	#	similar to bash, for example "WRF_CHEM=1". No spaces and no quotes. If a space
	#	is required, fill it with an at symbol, "@". For example, "J=-j@3".

	set NMM_IS_FOUND = FALSE
	set str = @
	while ( ${#argv} )
		set PACKAGE = $1
		set loc = `awk -v a="$PACKAGE" -v b="$str" 'BEGIN{print index(a,b)}'`
		if ( $loc != 0 ) then
			echo $PACKAGE > .orig_with_at
			sed -e 's/@/ /g' .orig_with_at > .new_without_at
			set PACKAGE = `cat .new_without_at`
		endif
		set ARGUMENT =  `echo $PACKAGE | cut -d"=" -f1`
		set VALUE    = "`echo $PACKAGE | cut -d"=" -f2`"
		setenv $ARGUMENT "$VALUE"
		if ( $ARGUMENT == WRF_NMM_CORE ) then
			set NMM_IS_FOUND = TRUE
		endif
		shift
	end

	#	We have now processed all of the input for the BUILD step. The next steps
	#	are the traditional pieces required to build the WRF model. The SUCCESS or
	#	FAILURE of each step is determined and then that information is passed on in
	#	two different ways: both a flagged file and a return code.

	#	Get into the WRF directory.

	cd WRF >& /dev/null
	
	#	Remove all specially named flagged files in the special directory.

	rm /wrf/wrfoutput/{FAIL,SUCCESS}_BUILD_WRF_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM} >& /dev/null

	#	There are the usual three steps for a BUILD: clean, configure, compile.
	#	We start those here.

	#	Are we asked to clean the directory structure? If so, then do it.

	if ( $CLEAN == CLEAN ) then
		./clean -a >& /dev/null
	endif
	
	#	The configure step has three pieces of input information. 
	#	1. There are the associated option flags, for example "-d".
	#	2. There is the numerical selection, for example Linux GNU MPI = 34.
	#	3. There is the nesting, typically = 1.

	./configure ${CONF_OPT} << EOF >& configure.output
$CONF_BUILD_NUM
$CONF_BUILD_NEST
EOF

	#	With GNU 9, the troubles with the RRTMG-derivative -d builds have gone
	#	away. Remove the prophylaxis for RRTMG FAST and RRTMG KIAPS. Remember,
	#	lest we forget the dark night, that NMM is still built with GNU 7.
	#	Ergo, if this is an NMM build, we leave those RRTMG-deviative schemes OUT.

	if ( $NMM_IS_FOUND == FALSE ) then
		sed -e 's/-DBUILD_RRTMG_FAST=0/-DBUILD_RRTMG_FAST=1/' configure.wrf > .foo1
		mv .foo1 configure.wrf
		sed -e 's/-DBUILD_RRTMK=0/-DBUILD_RRTMK=1/' configure.wrf > .foo1
		mv .foo1 configure.wrf
	endif
	
	#	The compile command takes only one input option, the compilation
	#	target. Any and all environment variables have already been processed
	#	at input and have been set. There are occassional problems with the
	#	build. Once *most* of the code is built, a re-compile is quick. If the
	#	executables already exist, then "no harm, no foul". If the executables
	#	do not exist, this is a quick way to grab that karma we have all earned.

	./compile $COMP_BUILD_TARGET >& compile.log.$COMP_BUILD_TARGET.$CONF_BUILD_NUM
	echo "ONCE MORE WITH FEELING" >>& compile.log.$COMP_BUILD_TARGET.$CONF_BUILD_NUM
	./compile $COMP_BUILD_TARGET >>& compile.log.$COMP_BUILD_TARGET.$CONF_BUILD_NUM
	if ( ! -e main/wrf.exe ) then
		echo "THEY GOT THE MUSTARD OUT" >>& compile.log.$COMP_BUILD_TARGET.$CONF_BUILD_NUM
		./compile $COMP_BUILD_TARGET >>& compile.log.$COMP_BUILD_TARGET.$CONF_BUILD_NUM
	endif

	#	We need to test to see if the BUILD worked. This is most easily handled
	#	by looking at the executable files that were generated. Since the compiled
	#	targets produce different numbers of executables and different names of
	#	executables, each compile has to be handled separately, so there is a 
	#	lengthy IF test.
	
	if      ( $COMP_BUILD_TARGET ==  em_real ) then
		if ( ( -e main/wrf.exe       ) && \
		     ( -e main/real.exe      ) && \
		     ( -e main/tc.exe        ) && \
		     ( -e main/ndown.exe     ) ) then
			touch /wrf/wrfoutput/SUCCESS_BUILD_WRF_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}
			exit ( 0 )
		else
			touch /wrf/wrfoutput/FAIL_BUILD_WRF_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}
			exit ( 2 )
		endif
	
	else if ( $COMP_BUILD_TARGET == nmm_real ) then
		if ( ( -e main/wrf.exe       ) && \
		     ( -e main/real_nmm.exe  ) ) then
			touch /wrf/wrfoutput/SUCCESS_BUILD_WRF_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}
			exit ( 0 )
		else
			touch /wrf/wrfoutput/FAIL_BUILD_WRF_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}
			exit ( 2 )
		endif
	endif

#	That is the end of the BUILD phase.



#	If the user has asked for the RUN phase, then we are in now part #2 of the big
#	IF test in this script. Processing is similar as above. First we make sure that 
#	the minimum args are there. We bring in the mandatory args. 

else if ( $WHICH_FUNCTION == RUN   ) then

	#	We need four input values for the RUN phase of the script.
	#	1. The build target, for example "em_real".
	#	2. The build number from the configuration, such as 34 for MPI.
	#	   Honestly, this should be cleaned up by getting the info
	#	   from within files in the container.
	#	3. The directory structure where the namelist and data are located
	#	   may be separate from the build target. For example, we build
	#	   em_real, but get data and namelists from em_chem.
	#	4. The specific test to run from the namelist directory. This is a
	#	   string, for example 01, 03NE, 06DF, etc. This is taken directly
	#	   from the regtest naming convention.

	if ( ${#argv} < 4 ) then
		touch /wrf/wrfoutput/FAIL_RUN_ARGS
		exit ( 1 )
	endif

	#	Assign the mandatory inputs, then do the "shift" thing so that
	#	we may check on env variables that might be there.

	set COMP_BUILD_TARGET = $1
	set CONF_BUILD_NUM    = $2
	set COMP_RUN_DIR      = $3
	set COMP_RUN_TEST     = $4
	shift
	shift
	shift
	shift

	#	The optional input is for setting env variables. The syntax is
	#	similar to bash, for example "OMP_NUM_THREADS=3". Neither spaces
	#	or quotes are allowed in the string. 

	set HAVE_THREADS = FALSE
	rm .orig_with_at   >& /dev/null
	rm .new_without_at >& /dev/null
	set str = @
	while ( ${#argv} )
		set PACKAGE = $1
		set loc = `awk -v a="$PACKAGE" -v b="$str" 'BEGIN{print index(a,b)}'`
		if ( $loc != 0 ) then
			echo $PACKAGE > .orig_with_at
			sed -e 's/@/ /g' .orig_with_at > .new_without_at
			set PACKAGE = `cat .new_without_at`
		endif
		set ARGUMENT =  `echo $PACKAGE | cut -d"=" -f1`
		set VALUE    = "`echo $PACKAGE | cut -d"=" -f2`"
		setenv $ARGUMENT "$VALUE"

		#	Hold on to the OpenMP thread count, as we will toggle it
		#	back and forth between doing real (where we set OpenMP to off) 
		#	and WRF (where we want to utilize the OpenMP threads).

		if ( $ARGUMENT == OMP_NUM_THREADS ) then
			set WANT_THREADS = $VALUE
			set HAVE_THREADS = TRUE
		endif

		shift
	end

	#	The input is processed. Get into the WRF directory.

	cd WRF >& /dev/null

	#	Get into the specific directory that is required.

	cd test/$COMP_BUILD_TARGET

	#	We also remove any remnants of previous model runs. We do not want false
	#	positives showing up.

	foreach f ( wrfinput_d wrfbdy_d wrfout_d wrfchemi_d wrf_chem_input_d rsl real.print.out wrf.print.out )
		set num = `ls -1 | grep $f | wc -l | awk '{print $1}'`
		if ( $num > 0 ) then
			rm -rf ${f}*
		endif
	end

	#	Some directories have a script to bring in required tables.
	
	if ( -e run_me_first.csh ) then
		run_me_first.csh >& /dev/null
	endif
	
	#	Bring in all of the input data for the real program and the WRF model. This tends to
	#	be data from WPS (geogrid or metgrid), or some files for gridded or obs nudging.
	#	For the em_real data, we split the tests up in multiple pieces. Each piece needs the
	#	met_em* data. There is no need to have a massive data directory, we just link on the fly.

	if ( ! -d /wrf/Data/$COMP_RUN_DIR ) then
		if ( ( $COMP_RUN_DIR == em_realA ) || \
		     ( $COMP_RUN_DIR == em_realB ) || \
		     ( $COMP_RUN_DIR == em_realC ) || \
		     ( $COMP_RUN_DIR == em_realD ) || \
		     ( $COMP_RUN_DIR == em_realE ) || \
		     ( $COMP_RUN_DIR == em_realF ) || \
		     ( $COMP_RUN_DIR == em_realG ) || \
		     ( $COMP_RUN_DIR == em_realH ) || \
		     ( $COMP_RUN_DIR == em_realI ) || \
		     ( $COMP_RUN_DIR == em_realJ ) || \
		     ( $COMP_RUN_DIR == em_realK ) || \
		     ( $COMP_RUN_DIR == em_realL ) ) then
			pushd /wrf/Data >& /dev/null
			ln -sf em_real $COMP_RUN_DIR
			popd >& /dev/null
		endif
	endif
	ln -sf /wrf/Data/$COMP_RUN_DIR/* .
	
	#	Following the conventions in the regtest, the namelist files are in a few different
	#	locations. So that we can always use the regtest namelist files, we are just going to 
	#	use this structure.

	if      ( (   ${COMP_BUILD_TARGET} == nmm_real      )                                          || \
	          ( ( ${COMP_BUILD_TARGET} == em_b_wave     ) && ( $COMP_RUN_DIR == em_b_wave      ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_chem        ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_chem_kpp    ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_fire       ) && ( $COMP_RUN_DIR == em_fire        ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_hill2d_x   ) && ( $COMP_RUN_DIR == em_hill2d_x    ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_quarter_ss ) && ( $COMP_RUN_DIR == em_quarter_ss  ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_quarter_ss ) && ( $COMP_RUN_DIR == em_quarter_ss8 ) ) ) then
		cp /wrf/Namelists/weekly/$COMP_RUN_DIR/namelist.input.${COMP_RUN_TEST} namelist.input
	else if ( ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_real        ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_real8       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realA       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realB       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realC       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realD       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realE       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realF       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realG       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realH       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realI       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realJ       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realK       ) ) || \
	          ( ( ${COMP_BUILD_TARGET} == em_real       ) && ( $COMP_RUN_DIR == em_realL       ) ) ) then
		if      ( $CONF_BUILD_NUM == 32 ) then
			cp /wrf/Namelists/weekly/$COMP_RUN_DIR/SERIAL/namelist.input.${COMP_RUN_TEST} namelist.input
		else if ( $CONF_BUILD_NUM == 33 ) then
			cp /wrf/Namelists/weekly/$COMP_RUN_DIR/OPENMP/namelist.input.${COMP_RUN_TEST} namelist.input
		else if ( $CONF_BUILD_NUM == 34 ) then
			cp /wrf/Namelists/weekly/$COMP_RUN_DIR/MPI/namelist.input.${COMP_RUN_TEST} namelist.input
		endif
	else if ( ( ${COMP_BUILD_TARGET} == em_real ) && ( $COMP_RUN_DIR == em_move ) ) then
		cp /wrf/Namelists/weekly/$COMP_RUN_DIR/MPI/namelist.input.${COMP_RUN_TEST} namelist.input
	endif

	#	We now have all of the command line info processed. We are in the right directory.
	#	We have the gridded input for the real/ideal and WRF model. We have the SINGLE correct 
	#	namelist. There are two remaining steps: run real/ideal and run WRF. After each of
	#	those steps, we verify that everything went OK. 

	#	Since we are either running real.exe, or real_nmm.exe, or ideal.exe, we need to 
	#	figure out which. Also, if this is an idealized case, it is a safe assumption that
	#	the ideal.exe program should NOT be run with more than 1 MPI rank.
	
	if      ( ${COMP_BUILD_TARGET} ==  em_real ) then
		set exec = real.exe
		if ( ! $?NP ) then
			set NP   = 3
		endif
	else if ( ${COMP_BUILD_TARGET} == nmm_real ) then
		set exec = real_nmm.exe
		if ( ! $?NP ) then
			set NP   = 3
		endif
	else
		set str = em
		set loc = `awk -v a="$COMP_BUILD_TARGET" -v b="$str" 'BEGIN{print index(a,b)}'`
		if ( $loc == 1 ) then
			set exec = ideal.exe
			set NP   = 1
		endif
	endif

	#	Run the front-end program to WRF, which is real.exe, real_nmm.exe, or ideal.exe.

	if      ( $CONF_BUILD_NUM == 32 ) then
		${exec} >& real.print.out
		grep -q SUCCESS real.print.out
		set OK_FOUND_SUCCESS = $status
	else if ( $CONF_BUILD_NUM == 33 ) then
		setenv OMP_NUM_THREADS 1
		${exec} >& real.print.out
		grep -q SUCCESS real.print.out
		set OK_FOUND_SUCCESS = $status
	else if ( $CONF_BUILD_NUM == 34 ) then
		mpirun -np $NP --oversubscribe ${exec} >& real.print.out
		cat rsl.out.0000 >> real.print.out
		grep -q SUCCESS rsl.out.0000
		set OK_FOUND_SUCCESS = $status
	endif
	
	#	Remove specific SUCCESS or FAILURE files in the special directory.

	rm /wrf/wrfoutput/SUCCESS_*_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST} >& /dev/null
	rm /wrf/wrfoutput/FAIL_*_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST} >& /dev/null
	
	#	For the front-end program, we do two simple tests.
	#	1. Did we find the "SUCCESS" message at the end of the stdout file? If not, then
	#	   that is a FAILURE.
	#	2. Do we have the correct output files? Depending on the setup, this could be a 
	#	   wrfinput file and maybe a wrfbdy file.

	if ( $OK_FOUND_SUCCESS == 0 ) then
		if      ( (   ${COMP_BUILD_TARGET} !=  em_real ) && ( ${COMP_BUILD_TARGET} != nmm_real ) ) then
			if   ( -e wrfinput_d01 ) then
				touch /wrf/wrfoutput/SUCCESS_RUN_REAL_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
			else
				touch /wrf/wrfoutput/FAIL_RUN_REAL_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
				touch /wrf/wrfoutput/FAIL_RUN_WRF_d01_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
				exit ( 2 )
			endif
		else if ( (   ${COMP_BUILD_TARGET} == nmm_real ) || \
		          ( ( ${COMP_BUILD_TARGET} ==  em_real ) && ( ${COMP_RUN_TEST}     != global   ) ) ) then
			if ( ( -e wrfinput_d01 ) && ( -e wrfbdy_d01 ) ) then
				touch /wrf/wrfoutput/SUCCESS_RUN_REAL_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
			else
				touch /wrf/wrfoutput/FAIL_RUN_REAL_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
				touch /wrf/wrfoutput/FAIL_RUN_WRF_d01_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
				exit ( 2 )
			endif
		else if ( (   ${COMP_BUILD_TARGET} ==  em_real ) && ( ${COMP_RUN_TEST}     == global   ) ) then
			if   ( -e wrfinput_d01 ) then
				touch /wrf/wrfoutput/SUCCESS_RUN_REAL_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
			else
				touch /wrf/wrfoutput/FAIL_RUN_REAL_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
				touch /wrf/wrfoutput/FAIL_RUN_WRF_d01_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
				exit ( 2 )
			endif
		endif
	else
		touch /wrf/wrfoutput/FAIL_RUN_REAL_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
		touch /wrf/wrfoutput/FAIL_RUN_WRF_d01_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
		exit ( 2 )
	endif

	#	To run the model, first you run the front-end, then you run the model. We have determined
	#	that there is sufficient and OK input. After the model run, we check on the "SUCCESS"
	#	message.

#DAVE
#	if ( -e /wrf/wrfoutput/SUCCESS_RUN_REAL_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST} ) then
		if      ( $CONF_BUILD_NUM == 32 ) then
			wrf.exe >& wrf.print.out
			grep -q SUCCESS wrf.print.out
			set OK_FOUND_SUCCESS = $status
		else if ( $CONF_BUILD_NUM == 33 ) then
			if ( $HAVE_THREADS == TRUE ) then
				setenv OMP_NUM_THREADS $WANT_THREADS
			endif
			wrf.exe >& wrf.print.out
			grep -q SUCCESS wrf.print.out
			set OK_FOUND_SUCCESS = $status
		else if ( $CONF_BUILD_NUM == 34 ) then
			mpirun -np 3 --oversubscribe wrf.exe >& wrf.print.out
			cat rsl.out.0000 >> wrf.print.out
			grep -q SUCCESS rsl.out.0000
			set OK_FOUND_SUCCESS = $status
		endif
#	else
#		set OK_FOUND_SUCCESS = 1
#	endif

	#	If the "SUCCESS" message was not found, that is a FAILURE.

	if ( $OK_FOUND_SUCCESS == 0 ) then

		#	For the model we'll test a few things that we know should be there.

		set MAX_DOM = `grep max_dom namelist.input | cut -d"=" -f2 | cut -d"," -f1 | awk '{print $1}'`
		set d = 0
	      	while ( $d < $MAX_DOM )  
			@ d ++
			@ return_code = 10 + $d
	
			#	We check each domain from the namelist, does the file exist?

			set num = `ls -1 | grep wrfout_d0 | wc -l | awk '{print $1}'`
			if ( $num > 0 ) then
	
				#	Are there any NaNs in the file?

				ncdump wrfout_d0${d}_* | grep -i nan | grep -vi dominant
				set OK_nan = $status

				#	There are supposed to be EXACTLY two time periods.

				set nt = `ncdump -h wrfout_d0${d}_* | grep "Time = UNLIMITED" | cut -d"(" -f2 | awk '{print $1}'`
				if ( $nt == 2 ) then
					set OK_time_levels = 0
				else
					set OK_time_levels = 1
				endif
	
				#	If all those tests work out, we give a thumbs up, else FAILURE.

				if ( ( $OK_nan == 1 ) && ( $OK_time_levels == 0 ) ) then
					set FILE = /wrf/wrfoutput/SUCCESS_RUN_WRF_d0${d}_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
					touch $FILE
					python3 ~/rd_l2_norm.py wrfout_d0${d}_* >> $FILE
					exit ( 0 )
				else 
					touch /wrf/wrfoutput/FAIL_RUN_WRF_d0${d}_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
					exit ( $return_code )
				endif
			else
				touch /wrf/wrfoutput/FAIL_RUN_WRF_d0${d}_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
				exit ( $return_code )
			endif
		end
	else
		set d = 1
		touch /wrf/wrfoutput/FAIL_RUN_WRF_d0${d}_${COMP_BUILD_TARGET}_${CONF_BUILD_NUM}_${COMP_RUN_DIR}_${COMP_RUN_TEST}
		echo " " >> wrf.print.out
		echo "NAMELIST  " >> wrf.print.out
		cat namelist.input >> wrf.print.out
		exit ( 9 )
	endif
endif
