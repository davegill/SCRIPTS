#!/bin/csh

set DIR  = ( em_real em_realE em_realB em_realK em_realL em_realJ em_realC em_realD em_realA em_realF em_realH em_realI em_realG )

set PAR  = ( MPI SERIAL OPENMP )
set PAR  = ( MPI )

set FILE = namelist.input.65DF

foreach D ($DIR )

	foreach P ( $PAR )
	
		sed -e '/use_aero_icbc/s/TRUE/FALSE/' $D/$P/$FILE >& .foo
		mv .foo $D/$P/$FILE
		
	end
end

