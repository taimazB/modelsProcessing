import numpy as np
from netCDF4 import Dataset
import sys
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing
import os
import imageio


dateHr = sys.argv[1].split('_')
date = dateHr[0]
hr = int(dateHr[1])
ncFileWest = Dataset("HYCOM_Currents_%s_%02d_west.nc" % (date, hr), 'r')
ncFileEast = Dataset("HYCOM_Currents_%s_%02d_east.nc" % (date, hr), 'r')

# depthRanges = [[0, 10], [10, 50], [50, 100], [100, 200], [
#     200, 500], [500, 1000], [1000, 1500], [1500, 2000], [50, 20000]]
depthRanges = [[0,10],[20,200],[50,1000]]
missingValue = -30000

# U
uw = np.array(ncFileWest.variables['water_u'][0])
ue = np.array(ncFileEast.variables['water_u'][0])
u = np.concatenate((uw[:, :, 1:], ue), axis=2)
u[u == missingValue] = np.nan
del uw, ue

# V
vw = np.array(ncFileWest.variables['water_v'][0])
ve = np.array(ncFileEast.variables['water_v'][0])
v = np.concatenate((vw[:, :, 1:], ve), axis=2)
v[v == missingValue] = np.nan
del vw, ve

# Depth
depths = ncFileWest.variables['depth'][:].data


##  latitude and longitude
# nc files are already from lat: 80S to 85N
lat = np.arange(-80, 85.01, 0.04)
lon = np.arange(-180, 180, 0.08)


# Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


# For interpolation
xx = np.linspace(np.min(x), np.max(x), 4500)  # 0.08 deg
yy = np.linspace(np.min(y), np.max(y), 4126)  # 0.04 deg


# Fixed min/max values for all levels and times
uvMin = -3
uvMax = 3


maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveTile(depthRange):
    uz = np.nanmean(u[np.bitwise_and(depths >= depthRange[0],
                                        depths < depthRange[1]), :len(lat), :], axis=0)
    vz = np.nanmean(v[np.bitwise_and(depths >= depthRange[0],
                                        depths < depthRange[1]), :len(lat), :], axis=0)
    #
    # For interpolation, NaN is not accepted
    uz[np.isnan(uz)] = 0
    vz[np.isnan(vz)] = 0
    #
    fu = interpolate.interp2d(x, y, uz, kind='linear')
    fv = interpolate.interp2d(x, y, vz, kind='linear')
    print("##  Interpolation function done.")
    #
    #
    for zoom in np.arange(minZoom, maxZoom+1):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xx = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        yy = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        #
        if zoom <= 5:
            uNew = fu(xx, yy)
            vNew = fv(xx, yy)
            #
            uNew[uNew > uvMax] = uvMax
            uNew[uNew < uvMin] = uvMin
            vNew[vNew > uvMax] = uvMax
            vNew[vNew < uvMin] = uvMin
            #
            # Normalize values
            uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
            vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
            #
            # Save image
            uvColored = np.empty((noOfPoints, noOfPoints, 3), dtype=np.uint16)
            uvColored[:, :, 0] = uNew[:, :]
            uvColored[:, :, 1] = vNew[:, :]
            uvColored[:, :, 2] = 0
            print("##  Coloring done.")
            #
            #
            # Save multiple resolutions
            for i in np.arange(2**zoom):
                for j in np.arange(2**zoom):
                    devNull = os.system('mkdir -p ../tiles/HYCOM_Currents_%s_%02d_%05d-%05d/%d/%d' % (
                        date, hr, depthRange[0], depthRange[1], zoom, i))
                    subUV = uvColored[j*tileSize:(j+1) *
                                        tileSize, i*tileSize:(i+1)*tileSize, :]
                    imageio.imwrite('../tiles/HYCOM_Currents_%s_%02d_%05d-%05d/%d/%d/%d.jpg' % (date, hr, depthRange[0], depthRange[1], zoom, i, 2**zoom-j-1), np.flipud(subUV).astype(np.uint8))
            #
            #
        else:  # For memory issues, need to break into chunks for zooms>=6
            xLength = 8*tileSize  # Due to memory issue
            xChunks = int(xx.size / xLength)
            for iSub in np.arange(xChunks):
                xxSub = xx[int(iSub*noOfPoints/xChunks):int((iSub+1)*noOfPoints/xChunks)]
                uNew = fu(xxSub, yy)
                vNew = fv(xxSub, yy)
                print("##  Interpolating %d of %d done." % (iSub, xChunks))
                #
                uNew[uNew > uvMax] = uvMax
                uNew[uNew < uvMin] = uvMin
                vNew[vNew > uvMax] = uvMax
                vNew[vNew < uvMin] = uvMin
                #
                # Normalize values
                uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
                vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
                #
                # Save image
                uvColored = np.empty((noOfPoints, xLength, 3), dtype=np.uint16)
                uvColored[:, :, 0] = uNew[:, :]
                uvColored[:, :, 1] = vNew[:, :]
                uvColored[:, :, 2] = 0
                del uNew,vNew
                print("##  Coloring done.")
                #
                # Save multiple resolutions
                for i in np.arange(8):
                    for j in np.arange(2**zoom):
                        devNull = os.system(
                            'mkdir -p ../tiles/HYCOM_Currents_%s_%02d_%05d-%05d/%d/%d' % (date, hr, depthRange[0], depthRange[1], zoom, i+8*iSub))
                        subUV = uvColored[j*tileSize:(j+1) *
                                            tileSize, i*tileSize:(i+1)*tileSize, :]
                        imageio.imwrite('../tiles/HYCOM_Currents_%s_%02d_%05d-%05d/%d/%d/%d.jpg' % (date, hr, depthRange[0], depthRange[1], zoom, i+8*iSub, 2**zoom-j-1), np.flipud(subUV).astype(np.uint8))


with multiprocessing.Pool(3) as p:
    p.map(saveTile, depthRanges)


#############################################
# Average depth for forecast/hindcast files
# Interpolate to have square dimensions
# Currently lon: 0.08 deg, lat: 0.04  -> GNT doesn't like it
# Interpolate to 0.04 x 0.04

latOld = np.arange(-80, 85.01, 0.04)
lonOld = np.arange(0, 360, 0.08)
latNew = np.arange(-80, 85.01, 0.04)
lonNew = np.arange(0, 360, 0.04)

# Regrid (GNT needs same lat & lon resolution)
uNew = np.empty((len(depths), len(latNew), len(lonNew))) * np.nan
vNew = np.empty((len(depths), len(latNew), len(lonNew))) * np.nan


def interp(k):
    uz = u[k]
    vz = v[k]
    #
    # For interpolation, NaN is not accepted
    uz[np.isnan(uz)] = 0
    vz[np.isnan(vz)] = 0
    #
    fu = interpolate.interp2d(lonOld, latOld, uz, kind='linear')
    fv = interpolate.interp2d(lonOld, latOld, vz, kind='linear')
    #
    uNew = fu(lonNew, latNew)
    vNew = fv(lonNew, latNew)
    return k, uNew, vNew


for k, uk, vk in multiprocessing.Pool(10).map(interp, np.arange(len(depths))):
    uNew[k, :, :] = uk[:, :]
    vNew[k, :, :] = vk[:, :]

del k,uk,vk


# Turn land into nan
uNew[(uNew == 0) & (vNew == 0)] = np.nan
vNew[np.isnan(uNew)] = np.nan


# Average from 100 to 1000 m depth, ignore nan's
uZavg = np.nanmean(uNew[(depths >= 100) & (depths <= 1000), :, :], axis=0)
uBelow100avg = np.nanmean(uNew[(depths < 100), :, :], axis=0)
uZavg[np.isnan(uZavg)] = uBelow100avg[np.isnan(uZavg)]
del uNew,uBelow100avg
vZavg = np.nanmean(vNew[(depths >= 100) & (depths <= 1000), :, :], axis=0)
vBelow100avg = np.nanmean(vNew[(depths < 100), :, :], axis=0)
vZavg[np.isnan(vZavg)] = vBelow100avg[np.isnan(vZavg)]
del vNew,vBelow100avg

iLatMax, iLonMax = uZavg.shape


# Write netCDF
# open a netCDF file to write
fileName = "HYCOM_Currents_avgDepth_%s_%02d.nc" % (date,hr)
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

# Filling with date
lat = np.arange(-80, 85.01, 0.04)
lon = np.arange(0, 360, 0.04)
longitude[:] = lon[:]
latitude[:] = lat[:]
uout[:, :] = uZavg[:, :]
vout[:, :] = vZavg[:, :]

# close files
ncout.close()
