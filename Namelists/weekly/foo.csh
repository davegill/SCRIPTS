#!/bin/csh

set dirs = ( em_b_wave em_chem em_chem_kpp em_fire em_hill2d_x em_move em_quarter_ss em_quarter_ss8 em_real em_real8 nmm_hwrf nmm_nest  )

foreach d ( $dirs )

	pushd $d >& /dev/null

                set num = `ls -1 | grep namelist.input. | grep NE | wc -l | awk '{print $1}'`
                if ( $num > 0 ) then
			echo FOUND SOME $d
			grep -i history_interval namelist.input.*NE
			echo
		else
			echo No NML $d
			echo
                endif

	popd >& /dev/null
end
