import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing
from datetime import datetime, timedelta


fileName = sys.argv[1]
date = fileName.split('_')[0]

ncFile = Dataset(fileName,'r')
times = ncFile.variables['time'][:].data ##  minutes since 1900-01-01 00:00:00
u = ncFile.variables['uo'][:].data
v = ncFile.variables['vo'][:].data
lat = ncFile.variables['lat'][:].data
lon = ncFile.variables['lon'][:].data
depths = ncFile.variables['depth'][:].data

missingValue = 1e+20
u[u==missingValue] = np.nan
v[v==missingValue] = np.nan

R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), lon.size)
yy = np.linspace(np.min(y), np.max(y), lat.size)


##  Fixed min/max values for all levels and times
uMin = -1.5
uMax = 1.5
vMin = -1.5
vMax = 1.5


##  For interpolation, NaN is not accepted
# uGlob[np.isnan(uGlob)] = 0
# vGlob[np.isnan(vGlob)] = 0
u[np.isnan(u)] = 0
v[np.isnan(v)] = 0


baseTime = datetime(1900,1,1)
for i in np.arange(times.size):
    date = baseTime + timedelta(minutes=int(times[i]))
    for j in np.arange(depths.size):
        depth = np.int32(np.round(depths[j]))
        uTimeDepth = u[i,j,:,:]
        vTimeDepth = v[i,j,:,:]
        # 
        fu = interpolate.interp2d(x, y, uTimeDepth, kind='linear')
        fv = interpolate.interp2d(x, y, vTimeDepth, kind='linear')
        # 
        uNew = fu(xx, yy)
        vNew = fv(xx, yy)
        #
        ##  Normalize values
        uNew = (65535*(uNew-uMin)/(uMax-uMin)).astype(np.uint16)
        vNew = (65535*(vNew-vMin)/(vMax-vMin)).astype(np.uint16)
        # 
        ##  Rearrange u and v to lon: -180 to 180
        # uNew = np.concatenate((uNew[:,6000:], uNew[:,:6000]), axis=1)
        # vNew = np.concatenate((vNew[:,6000:], vNew[:,:6000]), axis=1)
        # 
        ##  Save image
        img = np.empty((uNew.shape[0],uNew.shape[1],3), dtype=np.uint16)
        img[:,:,0] = uNew[:,:]
        img[:,:,1] = vNew[:,:]
        img[:,:,2] = 0
        # 
        with open('../png/CMEMS_Currents_%s_%s_%04d.png' % (date.strftime("%Y%m%d"), date.strftime("%H"),  depth), 'wb') as f:
            writer = png.Writer(width=img.shape[1], height=img.shape[0], bitdepth=16, greyscale=False)
            # Convert img to the Python list of lists expected by the png writer
            img2list = np.flipud(img).reshape(-1, img.shape[1]*img.shape[2]).tolist()
            writer.write(f, img2list)


# plt.imshow(img)
# plt.show()
exit()

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
