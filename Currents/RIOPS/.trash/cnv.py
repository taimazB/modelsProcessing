import numpy as np
from netCDF4 import Dataset
import numpy as np
import math
import sys


fileName = sys.argv[1]
ncin = Dataset(fileName,'r')
longitude = ncin.variables['longitude']
latitude = ncin.variables['latitude']
depth = ncin.variables['depth'][:].data
ux = ncin.variables['vozocrtx'][0].data
vy = ncin.variables['vomecrty'][0].data

missingValue = 1e+20
ux[ux==missingValue] = np.nan
vy[vy==missingValue] = np.nan


##  Average from 100 to 1000 m depth, ignore nan's
uxZavg = np.nanmean(ux[(depth>=100) & (depth<=1000),:,:], axis=0)
vyZavg = np.nanmean(vy[(depth>=100) & (depth<=1000),:,:], axis=0)


iMax, jMax = uxZavg.shape


##  ux,vx -> u,v
u = np.empty((iMax,jMax))
u[:] = np.NaN

v = np.empty((iMax,jMax))
v[:] = np.NaN


for i in range(iMax):
    print(i)
    for j in range(jMax):
        if longitude[i,j]<260:
            theta = (longitude[i,j] + 100)*math.pi/180
        else:
            theta = (longitude[i,j]-260)*math.pi/180

        u[i,j] = uxZavg[i,j]*math.cos(theta) + vyZavg[i,j]*math.sin(theta)
        v[i,j] = -uxZavg[i,j]*math.sin(theta) + vyZavg[i,j]*math.cos(theta)


##  Write netCDF
# open a netCDF file to write
fileName = fileName.replace("allDepth", "avgDepth")
ncout = Dataset(fileName, 'w', format='NETCDF4')

# define axis size
ncout.createDimension('x', iMax)
ncout.createDimension('y', jMax)

# create latitude axis
lat = ncout.createVariable('latitude', 'double', ('x','y'))
lat.standard_name = 'latitude'
lat.long_name = 'latitude'
lat.units = 'degrees_north'
lat.axis = 'Y'

# create longitude axis
lon = ncout.createVariable('longitude', 'double', ('x','y'))
lon.standard_name = 'longitude'
lon.long_name = 'longitude'
lon.units = 'degrees_east'
lon.axis = 'X'

# create variable array
uout = ncout.createVariable('u', 'double', ('x', 'y'))
uout.long_name = 'zonal velocity'
uout.units = 'm/s'
uout.coordinates = "latitude longitude"

vout = ncout.createVariable('v', 'double', ('x', 'y'))
vout.long_name = 'meridional velocity'
vout.units = 'm/s'
vout.coordinates = "latitude longitude"


# copy axis from original dataset
lon[:,:] = longitude[:iMax,:jMax]
lat[:,:] = latitude[:iMax,:jMax]
uout[:,:] = u[:iMax,:jMax]
vout[:,:] = v[:iMax,:jMax]

# close files
ncin.close()
ncout.close()
