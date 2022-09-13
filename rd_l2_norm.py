from netCDF4 import Dataset
import numpy as np
import sys

from warnings import filterwarnings
filterwarnings(action='ignore', category=DeprecationWarning, message='`np.bool` is a deprecated alias')

o = Dataset(str(sys.argv[1]))

list_of_vars = o.variables.keys()

if 'THM' in list_of_vars:
	u = o.variables["U"][1,:,:,:]
	v = o.variables["V"][1,:,:,:]
	t = o.variables["THM"][1,:,:,:]
	q = o.variables["QVAPOR"][1,:,:,:]
elif 'T' in list_of_vars:
	u = o.variables["U"][1,:,:,:]
	v = o.variables["V"][1,:,:,:]
	t = o.variables["T"][1,:,:,:]
	q = o.variables["Q"][1,:,:,:]

u = u**2
v = v**2
t = t**2

sum = np.sum(q)
print ('Qv = ' + str('{:3.12e}'.format(sum)) )
sum = np.sum(t)
print ('T  = ' + str('{:3.12e}'.format(sum)) )
sum = np.sum(u) + np.sum(v)
print ('UV = ' + str('{:3.12e}'.format(sum)) )
