#!/bin/csh

#	The usual error processing of the possible input

if ( ${#argv} != 3 ) then
	echo "Usage: $0 SCRIPT_DIR REQUEST_DIR MASTER_TF" > err_msg
	echo "    where: SCRIPT_DIR is the fixed location of the WRF Regression scripts" >> err_msg
	echo "    where: REQUEST_DIR is the shared 777 directory where the user puts the 'RUN' file" >> err_msg
	echo "    where: MASTER_TF is the master=true or master=false switch identifying the subservient proletariat processes"  >> err_msg
	echo " " >> err_msg
	echo `hostname` >> err_msg
	echo "Not enough arguments" >> err_msg
	echo "Mail -s "WTF class FAIL start" gill@ucar.edu < err_msg"
cat err_msg
	rm err_msg
	exit ( 1 )
endif

set SCRIPT_DIR  = $1
set REQUEST_DIR = $2
set MASTER_TF   = $3

if ( ! -d $SCRIPT_DIR ) then
	echo "SCRIPT DIR does not exist: $SCRIPT_DIR" > err_msg
	echo "This is the directory where the regression scripts are located" >> err_msg
	echo `hostname` >> err_msg
	echo "Mail -s "class FAIL SCRIPT DIR" gill@ucar.edu < err_msg"
cat err_msg
	rm err_msg
	exit ( 2 )
endif

set INIT_SCRIPT = 01_get_wrf_src_for_container.csh
set RUN_SCRIPT  = 02_run_build_and_cases.csh

if ( ( ! -e $SCRIPT_DIR/$INIT_SCRIPT ) || ( ! -e $SCRIPT_DIR/$RUN_SCRIPT ) ) then
	echo "SCRIPT DIR missing files: $SCRIPT_DIR" > err_msg
	echo "SCRIPT DIR missing INIT or RUN SCRIPTS: $INIT_SCRIPT " >> err_msg
	echo "SCRIPT DIR missing INIT or RUN SCRIPTS: $RUN_SCRIPT " >> err_msg
	echo `hostname` >> err_msg
	echo "Mail -s "class FAIL missing scripts" gill@ucar.edu < err_msg"
cat err_msg
	rm err_msg
	exit ( 3 )
endif

if ( ! -d $REQUEST_DIR ) then
	echo "REQUEST DIR does not exist: $REQUEST_DIR" > err_msg
	echo "REQUEST DIR is the 777 permission directory where the RUN file is located" >> err_msg
	echo `hostname` >> err_msg
	echo "Mail -s "class FAIL REQUEST DIR" gill@ucar.edu < err_msg"
cat err_msg
	rm err_msg
	exit ( 4 )
endif

set permissions = `stat -c "%a %n" $REQUEST_DIR | awk '{print $1}'`

if ( "$permissions" != "777" ) then
	echo "Permissions for $REQUEST_DIR not 777" > err_msg
	echo `hostname` >> err_msg
	echo "Mail -s "class FAIL Permission REQUEST DIR" gill@ucar.edu < err_msg"
cat err_msg
	rm err_msg
	exit ( 5 )
endif

if ( ( $MASTER_TF != master=true ) && ( $MASTER_TF != master=false ) ) then
	echo "MASTER neither true nor false" > err_msg
	echo "The $MASTER_TF determines whether the process management or labor" >> err_msg
	echo `hostname` >> err_msg
	echo "Mail -s "master T / F" gill@ucar.edu < err_msg"
cat err_msg
	rm err_msg
	exit ( 6 )
endif

#	Check on some files that will tell us what we are to do, and 
#	what we may already be doing. This is a bit more obvious to 
#	check than a 0 return code.

set TRUE = 0

#	A user specifies to run a job. 

ls $REQUEST_DIR | grep -q RUN           ; set RUN           = $status

#	If that job request is well-formed, and nothing else is happening,
#	the it is turned into a valid request by the master process. This 
#	flag file is acted on by the worker bees.

ls $REQUEST_DIR | grep -q VALID_REQUEST ; set VALID_REQUEST = $status

#	While the worker bees are doing their processing (building code, 
#	running tests, etc), the flag file for this particular build 
#	(combination of build type, parallel option, and run-time namelist
#	location) is set to indiate that the processing is still going on.
#	This flag has a naming convention that is specific to the build /
#	run combination. This flag file is set by each worker bee.

ls $REQUEST_DIR | grep -q DOING_NOW     ; set DOING_NOW     = $status

#	After a build is complete and all of the associated cases are 
#	finished, the worker bee modifies the flag file status to be
#	upgraded from "under way" to "done".

ls $REQUEST_DIR | grep -q COMPLETE      ; set COMPLETE      = $status

#	On any malformed request to conduct testing, the RUN file is renamed 
#	by the master process.

ls $REQUEST_DIR | grep -q FAIL          ; set FAIL          = $status

#	Task depend on whether this is the master, in charge of all cron stuff

#	MASTER = TRUE

if      ( $MASTER_TF == master=true  ) then

	#	Use the flag file status to determine what stage we are at.

	if      ( ( $VALID_REQUEST == $TRUE ) && ( $DOING_NOW != $TRUE )&& ( $COMPLETE == $TRUE ) ) then
		set ACTIVITY = CLOSE_UP_SHOP
	else if   ( $VALID_REQUEST == $TRUE )                                                       then
		set ACTIVITY = LET_IT_CONTINUE_TO_RUN
	else if   ( $RUN           == $TRUE )                                                       then
		set ACTIVITY = CHECK_VALID
	else if   ( $FAIL          == $TRUE )                                                       then
		set ACTIVITY = BAD_INITIATION
	else	
		set ACTIVITY = ALL_QUIET
	endif

	#	All test cases for all builds are complete. Run last script for
	#	bit-wise comparison, do clean-up.
	
	if      ( $ACTIVITY == CLOSE_UP_SHOP          ) then
		echo `date` closing up shop
		chmod 755 $REQUEST_DIR/wrf-coop/last_only_once.csh
		$REQUEST_DIR/wrf-coop/last_only_once.csh >& attach.txt
		set name = `grep Email: $REQUEST_DIR/VALID_REQUEST | cut -d":" -f2 | awk '{print $1}'`
		cat > message.txt << EOF
The bit-for-bit comparisons, where appropriate, are the last
pieces of the regression test. The status of each reported
comparison should be zero.

The following is the code that was tested:
EOF
		cat $REQUEST_DIR/VALID_REQUEST >> message.txt
		Mail -s "Classroom test B4B" -a attach.txt $name < message.txt
		rm attach.txt
		rm message.txt
		rm -f $REQUEST_DIR/VALID_REQUEST
		rm $REQUEST_DIR/COMPLETE_* >& /dev/null
	
	else if ( $ACTIVITY == LET_IT_CONTINUE_TO_RUN ) then
		echo `date` letting it run

	else if ( $ACTIVITY == CHECK_VALID            ) then
		set email  = `grep -i Email:  $REQUEST_DIR/RUN | cut -d":" -f2- | awk '{print $1}'`
		set fork   = `grep -i Fork:   $REQUEST_DIR/RUN | cut -d":" -f2- | awk '{print $1}'`
		set repo   = `grep -i Repo:   $REQUEST_DIR/RUN | cut -d":" -f2- | awk '{print $1}'`
		set branch = `grep -i Branch: $REQUEST_DIR/RUN | cut -d":" -f2- | awk '{print $1}'`

		echo $email | grep -q @     ; set OK1 = $status
		echo $email | grep -q .     ; set OK2 = $status
		echo $fork  | grep -q https ; set OK3 = $status

		if ( ( $OK1 == $TRUE ) && ( $OK2 == $TRUE ) && ( $OK3 == $TRUE ) ) then
			date
			pushd $REQUEST_DIR
			$SCRIPT_DIR/$INIT_SCRIPT $REQUEST_DIR $fork $repo $branch
			mv $REQUEST_DIR/RUN $REQUEST_DIR/VALID_REQUEST
			chmod 777 $REQUEST_DIR/VALID_REQUEST
		else
			mv $REQUEST_DIR/RUN $REQUEST_DIR/FAIL
		endif

	else if ( $ACTIVITY == BAD_INITIATION         ) then
	else if ( $ACTIVITY == ALL_QUIET              ) then
		echo `date` all quiet
		exit ( 0 ) 
	endif

#	MASTER = FALSE. A lowly worker bee, but acutally does the work; not just a 
#	scheduler, like the big, big boss.

else if ( $MASTER_TF == master=false ) then

	#	Use the flag file status to determine what stage we are at.

	if      ( ( $VALID_REQUEST == $TRUE ) && ( $DOING_NOW != $TRUE )&& ( $COMPLETE == $TRUE ) ) then
		set ACTIVITY = CLOSE_UP_SHOP
	else if ( ( $VALID_REQUEST == $TRUE ) && ( $DOING_NOW == $TRUE ) )                          then
		set ACTIVITY = LET_IT_CONTINUE_TO_RUN
	else if ( ( $VALID_REQUEST == $TRUE ) && ( $DOING_NOW != $TRUE )&& ( $COMPLETE != $TRUE ) ) then
		set ACTIVITY = START_ME_UP
	else if   ( $VALID_REQUEST != $TRUE )                                                       then
		set ACTIVITY = ALL_QUIET
	endif

	#	Tell me what I am supposed to be feeling right now.
	
	if      ( $ACTIVITY == CLOSE_UP_SHOP          ) then
		echo `date` shutting down `hostname`
	
	else if ( $ACTIVITY == LET_IT_CONTINUE_TO_RUN ) then
		echo `date` letting it run on `hostname`

	else if ( $ACTIVITY == START_ME_UP            ) then
		echo `date` starting up test for `hostname`
		pushd ~
			foreach f ( build.csh Dockerfile Dockerfile-NMM foo.list last_only_once.csh \
			            Namelists nml.tar output.txt single.csh SUCCESS_FAIL \
			            test_001m.csh test_001o.csh test_001s.csh test_002m.csh \
			            test_003m.csh test_003s.csh test_004m.csh test_004o.csh test_004s.csh \
			            test_005m.csh test_005o.csh test_005s.csh test_006m.csh test_006o.csh \
			            test_006s.csh test_007m.csh test_007o.csh test_007s.csh test_008m.csh \
			            test_009m.csh test_009o.csh test_009s.csh test_010s.csh )
				if ( -e $f ) then
					rm -rf $f
				endif
			end
		popd
		set email  = `grep -i Email:  $REQUEST_DIR/VALID_REQUEST | cut -d":" -f2- | awk '{print $1}'`
		$SCRIPT_DIR/$RUN_SCRIPT $email

	else if ( $ACTIVITY == ALL_QUIET              ) then
		echo `date` nothing to do for `hostname`
		exit ( 0 ) 
	endif

endif
