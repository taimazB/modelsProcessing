import numpy as np
from netCDF4 import Dataset
import sys
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing
import os
import imageio
# import tracemalloc
from datetime import datetime, timedelta


maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7

# tracemalloc.start()
dateHr = sys.argv[1].split('_')
date = dateHr[0]
hr = int(dateHr[1])
path = sys.argv[2]

ncFile = Dataset("HYCOM_Currents_%s_%02d.nc" % (date, hr), 'r')

# depthRanges = [[0, 10], [10, 50], [50, 100], [100, 200], [
#     200, 500], [500, 1000], [1000, 1500], [1500, 2000], [50, 20000]]
depthRanges = [[0, 10], [20, 200], [50, 1000]]
missingValue = -30000

latNC = ncFile.variables['lat'][:].data
iLat85 = np.argmin(np.abs(latNC-85))  ## max lat = 85
latNC = latNC[:iLat85+1]

lonNC = ncFile.variables['lon'][:].data
lonNC = np.concatenate((lonNC[2250:], lonNC[:2250])) # Switch west and east
lonNC[lonNC >= 180] -= 360

# U
u = np.array(ncFile.variables['water_u'][0])
u = np.concatenate((u[:, :iLat85+1, 2250:], u[:,:iLat85+1,:2250]), axis=2) # Switch west and east
u[u == missingValue] = np.nan

# V
v = np.array(ncFile.variables['water_v'][0])
v = np.concatenate((v[:, :iLat85+1, 2250:], v[:,:iLat85+1,:2250]), axis=2) # Switch west and east
v[v == missingValue] = np.nan


depths = ncFile.variables['depth'][:].data


# Global array for jpg (lat: ~-85 - ~85)
# latTile = np.arange(-maxTileLat, maxTileLat, 0.04)
# lonTile = np.arange(-180, 180, 0.08)
# uGlob = np.empty((len(depths), len(latTile), len(lonTile)))
# vGlob = np.empty((len(depths), len(latTile), len(lonTile)))

# iLatTile80S = np.argmin(np.abs(latTile-(-80)))  # index of 80S in the latTile
# index of maxTile in the latNC
# iLatNC85N = np.argmin(np.abs(latNC-maxTileLat))
# uGlob[:, iLatTile80S+1:, :] = u[:, :iLatNC85N+1, :]
# vGlob[:, iLatTile80S+1:, :] = v[:, :iLatNC85N+1, :]
# del u, v  ##  DO NOT del; needed later


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# For interpolation
# xx = np.linspace(np.min(x), np.max(x), len(lonTile))
# yy = np.linspace(np.min(y), np.max(y), len(latTile))


# Fixed min/max values for all levels and times
uvMin = -3
uvMax = 3


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p %s/tiles/HYCOM_Currents_%s_%02d_%05d-%05d/%d/%d' %
                        (path, date, hr, depthRange[0], depthRange[1], zoom, i))
    uNew = fu(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    vNew = fv(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    uNew[uNew > uvMax] = uvMax
    uNew[uNew < uvMin] = uvMin
    vNew[vNew > uvMax] = uvMax
    vNew[vNew < uvMin] = uvMin
    #
    # Normalize
    uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    #
    if(np.min(uNew) == 127 and np.max(uNew) == 127 and np.min(vNew) == 127 and np.max(vNew) == 127):
        return
    else:
        # Coloring
        uvColored = np.empty(
            (uNew.shape[0], uNew.shape[1], 3), dtype=np.uint8)
        uvColored[:, :, 0] = uNew[:, :]
        uvColored[:, :, 1] = vNew[:, :]
        uvColored[:, :, 2] = 0
        imageio.imwrite('%s/tiles/HYCOM_Currents_%s_%02d_%05d-%05d/%d/%d/%d.png' % (path, date, hr,
                                                                                    depthRange[0], depthRange[1], zoom, i, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


# def saveImg2(i, j, iSub):
#     devNull = os.system(
#         'mkdir -p ../tiles/HYCOM_Currents_%s_%02d_%05d-%05d/%d/%d' % (date, hr, depthRange[0], depthRange[1], zoom, i+n*iSub))
#     subUnew = uNew[j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
#     subVnew = vNew[j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
#     if(np.min(subUnew)==127 and np.max(subUnew)==127 and np.min(subVnew)==127 and np.max(subVnew)==127):
#         return
#     else:
#         uvColored = np.empty(
#             (subUnew.shape[0], subVnew.shape[1], 3), dtype=np.uint16)
#         uvColored[:, :, 0] = subUnew[:, :]
#         uvColored[:, :, 1] = subVnew[:, :]
#         uvColored[:, :, 2] = 0
#         imageio.imwrite('../tiles/HYCOM_Currents_%s_%02d_%05d-%05d/%d/%d/%d.jpg' % (date, hr,
#                                                                                     depthRange[0], depthRange[1], zoom, i+n*iSub, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


def saveTile(depthRange):
    global zoom, uz, vz
    global xTile, yTile, fu, fv
    uz = np.nanmean(u[np.bitwise_and(depths >= depthRange[0],
                                     depths < depthRange[1]), :, :], axis=0)
    vz = np.nanmean(v[np.bitwise_and(depths >= depthRange[0],
                                     depths < depthRange[1]), :, :], axis=0)
    #
    # For interpolation, NaN is not accepted
    uz[np.isnan(uz)] = 0
    vz[np.isnan(vz)] = 0
    fu = interpolate.interp2d(xNC, yNC, uz, kind='linear')
    fv = interpolate.interp2d(xNC, yNC, vz, kind='linear')
    #
    for zoom in np.arange(minZoom, maxZoom+1):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xTile = np.linspace(xMercator(-180),
                            xMercator(180), noOfPoints)
        yTile = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        iters = np.array(np.meshgrid(np.arange(2**zoom),
                                     np.arange(2**zoom))).T.reshape(-1, 2)
        #
        poolSize = min(len(iters), 32)
        with multiprocessing.Pool(poolSize) as p:
            p.starmap(saveImg, iters)


global depthRange
for depthRange in depthRanges:
    saveTile(depthRange)


#############################################
# Average depth for forecast/hindcast files
# Interpolate to have square dimensions
# Currently lon: 0.08 deg, lat: 0.04  -> GNT doesn't like it
# Interpolate to 0.04 x 0.04

def writeNC(date,hr,depth,u,v):
    # Write netCDF
    # open a netCDF file to write
    fileName = "PP/HYCOM_Currents_%s_%s_%02d.nc" % (depth, date, hr)
    ncout = Dataset(fileName, 'w', format='NETCDF4')

    # define axis size
    ncout.createDimension('x', len(lonNew))
    ncout.createDimension('y', len(latNew))

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
    longitude[:] = lonNew[:]
    latitude[:] = latNew[:]
    uout[:, :] = u[:, :]
    vout[:, :] = v[:, :]

    # close files
    ncout.close()
    # print(tracemalloc.get_traced_memory())
    # tracemalloc.stop()


print("--  Saving depth average nc file ...")
latOld = latNC # np.arange(-80, 85.01, 0.04)
lonOld = lonNC # np.arange(-180, 180, 0.08)
latNew = np.arange(-80, 85.01, 0.04)
lonNew = np.arange(-180, 180, 0.04)

# Regrid (GNT needs same lat & lon resolution)
iDepth100 = np.argmin(np.abs(depths-100))  # index of depth=100 m
iDepth1000 = np.argmin(np.abs(depths-1000))  # index of depth=1000 m
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


for k, uk, vk in multiprocessing.Pool().map(interp, np.arange(len(depths[:iDepth1000+1]))):
    uNew[k, :, :] = uk[:, :]
    vNew[k, :, :] = vk[:, :]

del k, uk, vk


# Turn land into nan
uNew[(uNew == 0) & (vNew == 0)] = np.nan
vNew[np.isnan(uNew)] = np.nan


# Average from 100 to 1000 m depth, ignore nan's
uZavg = np.nanmean(uNew[iDepth100:iDepth1000+1, :, :], axis=0)
vZavg = np.nanmean(vNew[(depths >= 100) & (depths <= 1000), :, :], axis=0)
# Where depth<100, average from 0 to 100
uBelow100avg = np.nanmean(uNew[(depths < 100), :, :], axis=0)
uZavg[np.isnan(uZavg)] = uBelow100avg[np.isnan(uZavg)]
vBelow100avg = np.nanmean(vNew[(depths < 100), :, :], axis=0)
vZavg[np.isnan(vZavg)] = vBelow100avg[np.isnan(vZavg)]
# del vNew, vBelow100avg, uNew, uBelow100avg

writeNC(date,hr,'avgDepth',uZavg,vZavg)


##  Write surface values
writeNC(date,hr,'surface',uNew[0,:,:],vNew[0,:,:])
