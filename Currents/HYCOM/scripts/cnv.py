import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing


date = sys.argv[1]
ncFileWest = Dataset("HYCOM_Currents_%s_west.nc" % date,'r')
ncFileEast = Dataset("HYCOM_Currents_%s_east.nc" % date,'r')

depthRanges = [[0,10],[10,50],[50,100],[100,200],[200,500],[500,1000],[1000,1500],[1500,2000],[50,20000]]
missingValue = -30000

##  U
uw = np.array(ncFileWest.variables['water_u'][0])
ue = np.array(ncFileEast.variables['water_u'][0])
u = np.concatenate((ue[:,:,1:],uw),axis=2)
u[u==missingValue] = np.nan

##  V
vw = np.array(ncFileWest.variables['water_v'][0])
ve = np.array(ncFileEast.variables['water_v'][0])
v = np.concatenate((ve[:,:,1:],vw),axis=2)
v[v==missingValue] = np.nan

##  Depth
depths = ncFileWest.variables['depth'][:].data


##  latitude and longitude
##  nc files are already from lat: 80S to 85N
lat = np.arange(-80,85.01,0.04)
lon = np.arange(0,360,0.08)


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), 4500)  ## 0.08 deg
yy = np.linspace(np.min(y), np.max(y), 4126)  ## 0.04 deg


##  Fixed min/max values for all levels and times
uMin = -3.
uMax = 3.
vMin = -3.
vMax = 3.


def saveImage(depthRange):
    uz = np.nanmean(u[np.bitwise_and(depths>=depthRange[0],depths<depthRange[1]),:len(lat),:], axis=0)
    vz = np.nanmean(v[np.bitwise_and(depths>=depthRange[0],depths<depthRange[1]),:len(lat),:], axis=0)
    #
    ##  For interpolation, NaN is not accepted
    uz[np.isnan(uz)] = 0
    vz[np.isnan(vz)] = 0
    #
    fu = interpolate.interp2d(x, y, uz, kind='linear')
    fv = interpolate.interp2d(x, y, vz, kind='linear')
    #
    uNew = fu(xx, yy)
    vNew = fv(xx, yy)
    #
    ##  Normalize values
    uNew = (65535*(uNew-uMin)/(uMax-uMin)).astype(np.uint16)
    vNew = (65535*(vNew-vMin)/(vMax-vMin)).astype(np.uint16)
    #
    ##  Rearrange u and v to lon: -180 to 180
    uNew = np.concatenate((uNew[:,2250:], uNew[:,:2250]), axis=1)
    vNew = np.concatenate((vNew[:,2250:], vNew[:,:2250]), axis=1)
    #
    ##  Save image
    img = np.empty((4126,4500,3), dtype=np.uint16)
    img[:,:,0] = uNew[:,:]
    img[:,:,1] = vNew[:,:]
    img[:,:,2] = 0
    #
    with open('../png/HYCOM_Currents_%s_%04d-%04d.png' % (date, depthRange[0], depthRange[1]), 'wb') as f:
        writer = png.Writer(width=img.shape[1], height=img.shape[0], bitdepth=16, greyscale=False)
        # Convert img to the Python list of lists expected by the png writer
        img2list = np.flipud(img).reshape(-1, img.shape[1]*img.shape[2]).tolist()
        writer.write(f, img2list)


# plt.imshow(img)
# plt.show()


with multiprocessing.Pool(9) as p:
    p.map(saveImage, depthRanges)


#############################################
##  Average depth for forecast/hindcast files
##  Interpolate to have square dimensions
##  Currently lon: 0.08 deg, lat: 0.04  -> GNT doesn't like it
##  Interpolate to 0.04 x 0.04

latOld = np.arange(-80,85.01,0.04)
lonOld = np.arange(0,360,0.08)
latNew = np.arange(-80,85.01,0.04)
lonNew = np.arange(0,360,0.04)

##  Regrid (GNT needs same lat & lon resolution)
uNew = np.empty((len(depths), len(latNew), len(lonNew))) * np.nan
vNew = np.empty((len(depths), len(latNew), len(lonNew))) * np.nan


def interp(k):
    uz = u[k]
    vz = v[k]
    
    ##  For interpolation, NaN is not accepted
    uz[np.isnan(uz)] = 0
    vz[np.isnan(vz)] = 0
    
    fu = interpolate.interp2d(lonOld, latOld, uz, kind='linear')
    fv = interpolate.interp2d(lonOld, latOld, vz, kind='linear')
    
    uNew = fu(lonNew, latNew)
    vNew = fv(lonNew, latNew)
    return k, uNew, vNew

for k, uk, vk in multiprocessing.Pool(10).map(interp, np.arange(len(depths))):
    uNew[k,:,:] = uk[:,:]
    vNew[k,:,:] = vk[:,:]

##  Turn land into nan
uNew[(uNew==0) & (vNew==0)] = np.nan
vNew[np.isnan(uNew)] = np.nan


##  Average from 100 to 1000 m depth, ignore nan's
uZavg = np.nanmean(uNew[(depths>=100) & (depths<=1000),:,:], axis=0)
uBelow100avg = np.nanmean(uNew[(depths<100),:,:], axis=0)
uZavg[np.isnan(uZavg)] = uBelow100avg[np.isnan(uZavg)]
vZavg = np.nanmean(vNew[(depths>=100) & (depths<=1000),:,:], axis=0)
vBelow100avg = np.nanmean(vNew[(depths<100),:,:], axis=0)
vZavg[np.isnan(vZavg)] = vBelow100avg[np.isnan(vZavg)]

iLatMax, iLonMax = uZavg.shape


##  Write netCDF
# open a netCDF file to write
fileName = "HYCOM_Currents_avgDepth_%s.nc" % date
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
lat = np.arange(-80,85.01,0.04)
lon = np.arange(0,360,0.04)
longitude[:] = lon[:]
latitude[:] = lat[:]
uout[:,:] = uZavg[:,:]
vout[:,:] = vZavg[:,:]

# close files
ncout.close()
