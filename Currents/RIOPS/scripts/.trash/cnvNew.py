import numpy as np
from netCDF4 import Dataset
import numpy as np
import sys
from multiprocessing import Pool
from datetime import datetime, timedelta


date = sys.argv[1]
hr = int(sys.argv[2])


def readVar(var):
    fileName = "nc/org/CMC_riops_%s_depth_all_ps5km60N_3h-mean_%s00_P%03d.nc" % (var, date, hr)
    ncin = Dataset(fileName,'r')
    longitude = ncin.variables['longitude'][:].data
    latitude = ncin.variables['latitude'][:].data
    depths = ncin.variables['depth'][:].data
    arr = ncin.variables[var][0].data
    missingValue = 1e+20
    arr[arr==missingValue] = np.nan
    ncin.close()
    return longitude,latitude,depths,arr

    
def depthAvg(arr,depths):
    ##  Average from 100 to 1000 m depth
    arrZavg = np.nanmean(arr[(depths>=100) & (depths<=1000),:,:], axis=0)
    ##  Where depth<100, average from 0 to 100
    below100Avg = np.nanmean(arr[(depths<100),:,:], axis=0)
    arrZavg[np.isnan(arrZavg)] = below100Avg[np.isnan(arrZavg)]
    return arrZavg


#######################################################
##  Read variables
longitude,latitude,depths,ux = readVar("vozocrtx")
longitude,latitude,depths,vy = readVar("vomecrty")

kMax, iMax, jMax = ux.shape


#######################################################
##  Depth Average
uxAvg = depthAvg(ux,depths)
vyAvg = depthAvg(vy,depths)


#######################################################
##  Convert from ux,vy to u,v
## longitude[i,j]<260:   theta = (longitude[i,j] + 100) * np.pi/180
## longitude[i,j]>=260:  theta = (longitude[i,j] - 260) * np.pi/180
theta = longitude * np.pi/180
theta[longitude<260] += 100*np.pi/180
theta[longitude>=260] -= 260*np.pi/180

u = np.empty((kMax, iMax,jMax))
u[:] = np.NaN
v = np.empty((kMax, iMax,jMax))
v[:] = np.NaN
u = ux*np.cos(theta) + vy*np.sin(theta)
v = -ux*np.sin(theta) + vy*np.cos(theta)

uAvg = np.empty((iMax,jMax))
uAvg[:] = np.NaN
vAvg = np.empty((iMax,jMax))
vAvg[:] = np.NaN
uAvg = uxAvg*np.cos(theta) + vyAvg*np.sin(theta)
vAvg = -uxAvg*np.sin(theta) + vyAvg*np.cos(theta)


longitude[longitude>180] -= 360

#######################################################
##  Convert from u,v to speed,direction
speed = np.empty((kMax, iMax,jMax))
speed[:] = np.NaN
speed = np.sqrt(u**2+v**2)
direction = np.empty((kMax, iMax,jMax))
direction[:] = np.NaN
direction = np.arctan2(v,u)

speedAvg = np.empty((iMax,jMax))
speedAvg[:] = np.NaN
speedAvg = np.sqrt(uAvg**2+vAvg**2)
directionAvg = np.empty((iMax,jMax))
directionAvg[:] = np.NaN
directionAvg = np.arctan2(vAvg,uAvg)


#######################################################
##  Save as csv
if hr >=24:
    hr -= 24
    date = (datetime.strptime(date, "%Y%m%d") + timedelta(days=1)).strftime("%Y%m%d")

def saveCSV(k):
    arrSave = np.c_[longitude.flatten(), latitude.flatten(), speed[k,:,:].flatten(), direction[k,:,:].flatten()]
    arrSave = arrSave[~np.isnan(arrSave).any(axis=1)]
    np.savetxt('csv/RIOPS_UV_z%05d_%s_%02d.csv' % (depths[k], date, hr), arrSave, header="lon,lat,speed,direction", comments="", delimiter=',', fmt="%.3f")

with Pool(12) as p:
    p.map(saveCSV, np.arange(75))

##  Save depth avg as csv
arrSave = np.c_[longitude.flatten(), latitude.flatten(), speedAvg.flatten(), directionAvg.flatten()]
arrSave = arrSave[~np.isnan(arrSave).any(axis=1)]
np.savetxt('csv/RIOPS_UV_avgDepth_%s_%02d.csv' % (date, hr), arrSave, header="lon,lat,speed,direction", comments="", delimiter=',', fmt="%.3f")


#######################################################
##  Save as nc (Depth average only)
fileName = "nc/forecast/RIOPS_UV_avgDepth_%s_%02d.nc" % (date, hr)
ncout = Dataset(fileName, 'w', format='NETCDF4')

# define axis size
ncout.createDimension('x', iMax)
ncout.createDimension('y', jMax)

lat = ncout.createVariable('latitude', 'double', ('x','y'))
lat.standard_name = 'latitude'
lat.long_name = 'latitude'
lat.units = 'degrees_north'
lat.axis = 'Y'

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
uout[:,:] = uAvg[:iMax,:jMax]
vout[:,:] = vAvg[:iMax,:jMax]

ncout.close()
