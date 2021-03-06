#!/bin/csh

set MAIL = /bin/Mail
set CP   = /bin/cp
set RM   = "/bin/rm -rf"

set email = $1

cd $HOME

$CP /classroom/dave/wrf-coop/Dockerfile .
$CP /classroom/dave/wrf-coop/Dockerfile-NMM .
$CP /classroom/dave/wrf-coop/*.csh .

date

if ( -e SUCCESS_FAIL ) then
	$RM SUCCESS_FAIL 
endif
touch SUCCESS_FAIL

set tests = ( test*.csh )
set num_tests = ${#tests}

set hn_part1 = lab1
set hn_num   = `hostname | cut -d"." -f1 | cut -c 5-6`
set hn_part2 = `hostname | cut -d"." -f2-`

ls -1 test_0* > foo.list

set script_to_run = `sed -n "${hn_num}p" foo.list`

if ( -e output.txt ) then
	$RM output.txt
endif 
echo The script to run is $script_to_run > output.txt

set LABEL = `grep "docker exec" $script_to_run | grep _RUN_ | cut -d"|" -f3 | awk '{print $2}' | rev | cut -d"_" -f2- | rev`

set test_num = `echo $script_to_run | cut -b 7-8`
if ( $test_num == 02 ) then
	( date ; ./single_init.csh Dockerfile-NMM wrf_nmmregtest ; ./$script_to_run ; ./single_end.csh wrf_nmmregtest ; date ) >> output.txt
else
	( date ; ./single_init.csh Dockerfile     wrf_regtest    ; ./$script_to_run ; ./single_end.csh wrf_regtest    ; date ) >> output.txt
endif

grep -aq SUCCESS output.txt >> SUCCESS_FAIL
set OK_S = $status
if  ( $OK_S == 0 ) then 
	echo "SUCCESS " >> SUCCESS_FAIL
	grep SUCCESS output.txt >> SUCCESS_FAIL
	echo " " >> SUCCESS_FAIL
endif

grep -aq FAIL output.txt >> SUCCESS_FAIL
set OK_F = $status
if  ( $OK_F == 0 ) then 
	echo "FAIL " >> SUCCESS_FAIL
	grep FAIL output.txt >> SUCCESS_FAIL
endif

if      ( $OK_F == 0 ) then
	set TITLE = FAIL
else if ( $OK_S == 0 ) then
	set TITLE = PASS
else
	set TITLE = FAIL
endif

$MAIL -s "Classroom test $LABEL $TITLE" -a output.txt $email < SUCCESS_FAIL

if ( $TITLE == PASS ) then
	$RM output.txt
	$RM SUCCESS_FAIL
	$RM build.csh
	$RM single_init.csh
	$RM single_end.csh
	$RM test_*.csh
	$RM Dockerfile
	$RM Dockerfile-NMM
	$RM foo.list
	$RM last_only_once.csh
	$RM Namelists
	$RM nml.tar
endif

date
