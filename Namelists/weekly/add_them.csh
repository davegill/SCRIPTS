#!/bin/csh

set dir_orig = em_real

set names = ( \
MPI/namelist.input.cmt \
MPI/namelist.input.fsbm \
MPI/namelist.input.irr1VN \
MPI/namelist.input.irr2 \
MPI/namelist.input.irr3NE \
MPI/namelist.input.kiaps1NE \
MPI/namelist.input.kiaps2 \
MPI/namelist.input.rala \
MPI/namelist.input.ralbNE \
MPI/namelist.input.solaraNE \
MPI/namelist.input.solarb \
MPI/namelist.input.urb3aNE \
MPI/namelist.input.urb3bNE \
)

set dirs = ( \
em_realA \
em_realB \
em_realC \
em_realD \
em_realE \
em_realF \
em_realG \
em_realH \
)

foreach d ( $dirs )

	foreach f ( $names )
		cp $dir_orig/$f $d/$f
	end
	cd $d 
	cd OPENMP ; ln -sf ../MPI/namelist* .
	cd ..
	cd SERIAL ; ln -sf ../MPI/namelist* .
	cd ../..
	
end
