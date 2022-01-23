#!/bin/csh

if ($#argv != 1 ) then
	echo 
	echo Hold on there hombre, we need a clue as to which test to run
	echo usage: $0 test_to_conduct
	echo where, test_to_conduct may be one of the following:
	echo "   WRFPlus"
	echo "   WRF4DVar"
	echo "   WRFDA"
	echo "   ALL"
	echo 
	exit 1
endif

set INPUT = $1

if      ( $INPUT == WRFPlus ) then
	# about 20 min on Mac laptop
	goto WRFPlus_STARTS_HERE

else if ( $INPUT == WRF4DVar ) then
	# about 8-9 min on Mac laptop
	goto WRF4DVar_STARTS_HERE

else if ( $INPUT == WRFDA  ) then
	# about 8-9 min on Mac laptop
	goto WRFDA_STARTS_HERE

else if ( $INPUT == ALL ) then
	goto ALL_STARTS_HERE

endif

#	WRFPlus build

WRFPlus_STARTS_HERE:
WRF4DVar_STARTS_HERE:
ALL_STARTS_HERE:
echo WRF DA Build WRFPlus
date
cd ~
if ( -d WRFPLUS ) then
	rm -rf WRFPLUS
endif
cp -pr WRF WRFPLUS
cd WRFPLUS 
./clean -a
./configure wrfplus << EOF >& configure.out
18
EOF
./compile -j 8 wrfplus >& foo
date
ls -1 main | grep wrfplus.exe
set OK = $status
if ( $OK == 0 ) then
	echo SUCCESS BUILD WRFPlus
	touch /wrf/wrfoutput/SUCCESS_BUILD_WRF_d01_wrfplus_18_WRFPlus
	ls -ls main/wrfplus.exe
else
	echo FAIL BUILD WRFPlus
	touch /wrf/wrfoutput/FAIL_BUILD_WRF_d01_wrfplus_18_WRFPlus
endif
#echo $OK = STATUS
if ( $INPUT == WRFPlus ) then
	exit $OK
endif

#	WRFDA-4DVar build

echo WRF DA Build WRFDA-4DVar
date
cd ~
if ( -d WRFDA ) then
	rm -rf WRFDA
endif
cp -pr WRF WRFDA
cd WRFDA
setenv CRTM 1   # will build with CRTM, optional
setenv WRFPLUS_DIR ~/WRFPLUS    # built-wrfplus-directory: must be built prior to 4DVar
./clean -a
./configure 4dvar << EOF >& configure.out
18
EOF
./compile -j 4 all_wrfvar >& foo
date
set HowMany = `ls -1 var/build/*.exe | wc -l`
if ( $HowMany == 43 ) then
	set OK = 0
	echo SUCCESS BUILD WRFDA-4DVar
	touch /wrf/wrfoutput/SUCCESS_BUILD_WRF_d01_all_wrfvar_18_WRFDA-4DVar
else
	set OK = 1
	echo "FAIL BUILD WRFDA-4DVar, only have $HowMany / 43 executables"
	touch /wrf/wrfoutput/FAIL_BUILD_WRF_d01_all_wrfvar_18_WRFDA-4DVar
endif
#echo $OK = STATUS
ls -ls var/build/*.exe
if ( $INPUT == WRF4DVar ) then
	exit $OK
endif

#	WRFDA build

WRFDA_STARTS_HERE:
echo WRF DA Build WRFDA
date
cd ~
if ( -d WRFDA2 ) then
	rm -rf WRFDA2
endif
cp -pr WRF WRFDA2
cd WRFDA2
setenv CRTM 1   # will build with CRTM, optional
unset WRFPLUS_DIR
./clean -a
./configure wrfda << EOF >& configure.out
34
EOF
./compile -j 4 all_wrfvar >& foo
date
set HowMany = `ls -1 var/build/*.exe | wc -l`
if ( $HowMany == 43 ) then
	set OK = 0
	echo SUCCESS BUILD WRFDA
	touch /wrf/wrfoutput/SUCCESS_BUILD_WRF_d01_all_wrfvar_34_WRFDA
else
	set OK = 1
	echo "FAIL BUILD WRFDA, only have $HowMany / 43 executables"
	touch /wrf/wrfoutput/FAIL_BUILD_WRF_d01_all_wrfvar_34_WRFDA
endif
#echo $OK = STATUS
ls -ls var/build/*.exe
if ( $INPUT == WRFDA  ) then
	exit $OK
endif
if ( $INPUT == ALL ) then
	exit $OK
endif
