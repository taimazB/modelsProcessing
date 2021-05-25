import numpy as np
from netCDF4 import Dataset
import math


ncin = Dataset('uv_avgDepth_2020-08-18_21.nc')

lat = ncin.variables['latitude'][:].data
lon = ncin.variables['longitude'][:].data
# depth = ncin.variables['depth'][:].data
u = ncin.variables['u'][:].data
v = ncin.variables['v'][:].data

# missingValue = ncin.variables['u'].missing_value

lon[lon>180] -= 360
# u[u==missingValue] = np.nan
# v[v==missingValue] = np.nan

speed = np.sqrt(u**2+v**2)
direction = np.arctan2(v,u)

# iDepth = 10
# np.savetxt('a.csv', np.stack([lon.flatten(), lat.flatten(), u[0,iDepth,:,:].flatten(), v[0,iDepth,:,:].flatten()]).transpose(), header='lon,lat,u,v', comments='', fmt='%10.4f,%10.4f,%10.6f,%10.6f')

np.savetxt('a.csv', np.stack([lon.flatten(), lat.flatten(), speed.flatten(), direction.flatten()]).transpose(), header='lon,lat,speed,direction', comments='', fmt='%10.4f,%10.4f,%10.6f,%10.6f')
