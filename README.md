# SCRIPTS
Mandatory scripts for running regression tests on MMM Classroom machines.

## Crontab files

This system is run via the Unix crontab system.

### MMM Classroom 150

```
#	WRF Regression test cron

SHELL=/bin/sh
MAIL=gill@ucar.edu

#	Detect if a regression test has been requested
#	min	hour	day-mon	mon	day-wk	command
        */5	*	*	*	*	/classroom/dave/SCRIPTS/shared_cron.csh /classroom/dave/SCRIPTS /classroom/dave master=true >> $HOME/.wrf_reg_out.txt 2>&1

#	Every Sunday at midnight (UTC) remove the accumulated output file
#	min	hour	day-mon	mon	day-wk	command
	0	0	*	*	0	rm -f $HOME/.wrf_reg_out.txt > /dev/null 2>&1
```

### MMM Classroom machines 101 through 123

```
#	WRF Regression test cron

SHELL=/bin/sh
MAIL=gill@ucar.edu

#	Run test for new reg test every 5 min, with a 2 minute offset so the master can get ducks in a row
#	min				hour	day-mon	mon	day-wk	command
        7,12,17,22,27,32,37,42,47,52,57	*	*	*	*	/classroom/dave/SCRIPTS/shared_cron.csh /classroom/dave/SCRIPTS /classroom/dave master=false >> $HOME/.wrf_reg_out.txt 2>&1

#	Every Sunday at midnight (UTC) remove the accumulated output file
#	min	hour	day-mon	mon	day-wk	command
	0	0	*	*	0	rm -f $HOME/.wrf_reg_out.txt > /dev/null 2>&1
```

### Instructions

To activate the regression testing, a local file is copied and edited.

1. Copy the file "run_template" to "RUN"
```
cp run_template RUN
```
2. Edit this file as shown below.
3. Change the permissions to world writeable, not executable.
```
chmod 666 RUN
```

Here is what a typical `run_template` file looks like:

```
Email: gill@ucar.edu
Fork: https://github.com/wrf-model
Repo: WRF
Branch: release-v4.1.1
```

This information is filled in as:
```
Email: where you want the results mailed to, single person
example: weiwang@ucar.edu
example: dudhia@ucar.edu

Fork: which github for
example: https://github.com/kkeene44
example: https://github.com/smileMchen

Repo: There are still people who have a repo that is named WRF-1
example: WRF
example: WRF-1

Branch: which branch to checkout
example: develop
example: master
example: release-v4.1.2
```



  

