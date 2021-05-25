import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing
from datetime import datetime, timedelta


date = sys.argv[1]
hr = int(sys.argv[2])

if (hr<24):
    dateSave = date
    hrSave = hr
elif (hr<48):
    dateSave = datetime.strftime(datetime.strptime(date, "%Y%m%d") + timedelta(days=1), "%Y%m%d")
    hrSave = hr - 24
elif (hr<72):
    dateSave = datetime.strftime(datetime.strptime(date, "%Y%m%d") + timedelta(days=2), "%Y%m%d")
    hrSave = hr - 48


missingValue = -9e+33


ncFile = Dataset("CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_%s00_P%03d.nc" % (date, hr),'r')
u = ncFile.variables['ocu'][0,0].data
u[u==missingValue] = np.nan
v = ncFile.variables['ocv'][0,0].data
v[v==missingValue] = np.nan


##  latitude and longitude
lat = np.array(ncFile.variables['lat'])
lon = np.array(ncFile.variables['lon'])

# uGlob = np.empty((8001,12000)) ## 0.02 x 0.03 deg
# vGlob = np.empty((8001,12000)) ## ...

# iLonStart = int(lon.min()/.03)
# iLonEnd = int(lon.max()/.03)+1
# iLatStart = int((80+lat.min())/.02)
# iLatEnd = int((80+lat.max())/.02)+1
# uGlob[iLatStart:iLatEnd, iLonStart:iLonEnd] = u[:,:]  ## lat: -80 - 80
# vGlob[iLatStart:iLatEnd, iLonStart:iLonEnd] = v[:,:]  ## ...


##  Mercator
# lat = np.arange(-80,80.01,0.02)
# lon = np.arange(0,360,0.03)

R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
# xx = np.linspace(np.min(x), np.max(x), 12000)  ## 0.03 deg
# yy = np.linspace(np.min(y), np.max(y), 8001)  ## 0.02 deg
xx = np.linspace(np.min(x), np.max(x), lon.size)
yy = np.linspace(np.min(y), np.max(y), lat.size)


##  Fixed min/max values for all levels and times
uMin = -1.5
uMax = 1.5
vMin = -1.5
vMax = 1.5


##  For interpolation, NaN is not accepted
u[np.isnan(u)] = 0
v[np.isnan(v)] = 0

fu = interpolate.interp2d(x, y, u, kind='linear')
fv = interpolate.interp2d(x, y, v, kind='linear')

uNew = fu(xx, yy)
vNew = fv(xx, yy)

##  Normalize values
uNew = (65535*(uNew-uMin)/(uMax-uMin)).astype(np.uint16)
vNew = (65535*(vNew-vMin)/(vMax-vMin)).astype(np.uint16)

##  Rearrange u and v to lon: -180 to 180
uNew = np.concatenate((uNew[:,6000:], uNew[:,:6000]), axis=1)
vNew = np.concatenate((vNew[:,6000:], vNew[:,:6000]), axis=1)

##  Save image
img = np.empty((lat.size,lon.size,3), dtype=np.uint16)
img[:,:,0] = uNew[:,:]
img[:,:,1] = vNew[:,:]
img[:,:,2] = 0

with open('../../png/CMC_Currents_%s_%02d.png' % (dateSave, hrSave), 'wb') as f:
    writer = png.Writer(width=img.shape[1], height=img.shape[0], bitdepth=16, greyscale=False)
    # Convert img to the Python list of lists expected by the png writer
    img2list = np.flipud(img).reshape(-1, img.shape[1]*img.shape[2]).tolist()
    writer.write(f, img2list)


# plt.imshow(img)
# plt.show()


#############################################
##  Average depth for forecast/hindcast files
##  Interpolate to have square dimensions
if (hr<24):
    lat = np.array(ncFile.variables['lat'])
    lon = np.array(ncFile.variables['lon'])
    latOld = np.arange(lat.min(),lat.max()+0.01,0.02)
    lonOld = np.arange(lon.min(),lon.max()+0.01,0.03)
    latNew = np.arange(lat.min(),lat.max()+0.01,0.02)
    lonNew = np.arange(lon.min(),lon.max()+0.01,0.02)

    ##  Regrid (GNT needs same lat & lon resolution)
    uNew = np.empty((len(latNew), len(lonNew))) * np.nan
    vNew = np.empty((len(latNew), len(lonNew))) * np.nan


    ##  For interpolation, NaN is not accepted
    u[np.isnan(u)] = 0
    v[np.isnan(v)] = 0

    fu = interpolate.interp2d(lonOld, latOld, u, kind='linear')
    fv = interpolate.interp2d(lonOld, latOld, v, kind='linear')

    uNew = fu(lonNew, latNew)
    vNew = fv(lonNew, latNew)


    ##  Turn land into nan
    uNew[(uNew==0) & (vNew==0)] = np.nan
    vNew[np.isnan(uNew)] = np.nan

    iLatMax, iLonMax = uNew.shape


    ##  Write netCDF
    # open a netCDF file to write
    fileName = "CMC_Currents_surface_%s_%02d.nc" % (date, hr)
    ncout = Dataset(fileName, 'w', format='NETCDF4')

    # define axis size
    ncout.createDimension('x', iLonMax)
    ncout.createDimension('y', iLatMax)

    # create latitude axis
    latitude = ncout.createVariable('latitude', 'double', ('y'))
    latitude.standard_name = 'latitude'
    latitude.long_name = 'latitude'
    latitude.units = 'degrees_north'
    latitude.axis = 'Y'

    # create longitude axis
    longitude = ncout.createVariable('longitude', 'double', ('x'))
    longitude.standard_name = 'longitude'
    longitude.long_name = 'longitude'
    longitude.units = 'degrees_east'
    longitude.axis = 'X'

    # create variable array
    uout = ncout.createVariable('u', 'double', ('y', 'x'))
    uout.long_name = 'zonal velocity'
    uout.units = 'm/s'
    uout.coordinates = "latitude longitude"

    vout = ncout.createVariable('v', 'double', ('y', 'x'))
    vout.long_name = 'meridional velocity'
    vout.units = 'm/s'
    vout.coordinates = "latitude longitude"

    ##  Filling with date
    longitude[:] = lonNew[:]
    latitude[:] = latNew[:]
    uout[:,:] = uNew[:,:]
    vout[:,:] = vNew[:,:]

    # close files
    ncout.close()
