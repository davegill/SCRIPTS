#!/bin/csh

set eligible = (		\
	namelist.input.3dtke	\
	namelist.input.conus	\
	namelist.input.rap	\
	namelist.input.tropical	\
	namelist.input.03	\
	namelist.input.03DF	\
	namelist.input.03FD	\
	namelist.input.06	\
	namelist.input.07NE	\
	namelist.input.10	\
	namelist.input.11	\
	namelist.input.14	\
	namelist.input.16	\
	namelist.input.16DF	\
	namelist.input.17	\
	namelist.input.17AD	\
	namelist.input.18	\
	namelist.input.20	\
	namelist.input.20NE	\
	namelist.input.38	\
	namelist.input.48	\
	namelist.input.49	\
	namelist.input.50	\
	namelist.input.51	\
	namelist.input.52	\
	namelist.input.52DF	\
	namelist.input.52FD	\
	namelist.input.60	\
	namelist.input.60NE	\
	namelist.input.65DF	\
	namelist.input.66FD	\
	namelist.input.71	\
	namelist.input.78	\
	namelist.input.79	\
	namelist.input.cmt	\
	namelist.input.kiaps1NE	\
	namelist.input.kiaps2	\
	namelist.input.solaraNE	\
	namelist.input.urb3bNE	\
				)

set NML_DIR = /wrf/Namelists/weekly/em_real/MPI
set NML_DIR = /classroom/dave/wrf-coop/SCRIPTS/Namelists/weekly/em_real/MPI

if ( -e column_opts ) then
	rm -rf column_opts
endif
touch column_opts
echo "OPTIONS            " > column_opts

set FIRST_TIME = TRUE
set col_count = 1
set short_opt = ( MP        CU         LW              SW           PBL               SFC                 LSM             URB )
foreach opt ( mp_physics cu_physics ra_lw_physics ra_sw_physics bl_pbl_physics sf_sfclay_physics sf_surface_physics sf_urban_physics )


	if ( -e column_$opt ) then
		rm column_$opt
	endif
	touch column_$opt
	echo "$short_opt[$col_count]" >> column_$opt

	foreach nml ( $eligible )

		if ( $FIRST_TIME == TRUE ) then
			echo $nml >> column_opts
		endif

		grep -iwq $opt $NML_DIR/$nml

		set OK = $status
		if ( $OK == 0 ) then
			grep -iw $opt $NML_DIR/$nml | cut -d"=" -f2 | cut -d"," -f1 >> column_$opt
		else
			echo "0" >> column_$opt
		endif
	end

	set FIRST_TIME = FALSE

	@ col_count ++
end

paste column_opts column_mp_physics column_cu_physics column_ra_lw_physics column_ra_sw_physics column_bl_pbl_physics column_sf_sfclay_physics column_sf_surface_physics column_sf_urban_physics
