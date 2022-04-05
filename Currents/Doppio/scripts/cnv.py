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
import math


maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7


# tracemalloc.start()
date = sys.argv[1]

# if (hr < 24):
#     dateSave = date
#     hrSave = hr
# elif (hr < 48):
#     dateSave = datetime.strftime(datetime.strptime(
#         date, "%Y%m%d") + timedelta(days=1), "%Y%m%d")
#     hrSave = hr - 24
# elif (hr < 72):
#     dateSave = datetime.strftime(datetime.strptime(
#         date, "%Y%m%d") + timedelta(days=2), "%Y%m%d")
#     hrSave = hr - 48


missingValue = 1e+37

ncFile = Dataset("Doppio_Currents_%s.nc" % date, 'r')

times = ncFile.variables['time1'][:].data  # Hours since 2017-11-01
u = ncFile.variables['ubar_eastward'][:].data
u[u == missingValue] = np.nan
v = ncFile.variables['vbar_northward'][:].data
v[v == missingValue] = np.nan


##  latitude, longitude
lonNC = ncFile.variables['lon'][:].data
latNC = ncFile.variables['lat'][:].data


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
uvMin = -3.
uvMax = 3.


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    try:
        if(xTile[i*tileSize: (i+1)*tileSize].min() > xNC.max() or
           xTile[i*tileSize: (i+1)*tileSize].max() < xNC.min() or
           yTile[j*tileSize: (j+1)*tileSize].min() > yNC.max() or
           yTile[j*tileSize: (j+1)*tileSize].max() < yNC.min()):
            return
    except:
        return
    devNull = os.system('mkdir -p ../tiles/Doppio_Currents_%s_avgDepth/%d/%d' %
                        (dateSave, zoom, i))
    uNew = fu(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    vNew = fv(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    uNew[uNew > uvMax] = uvMax
    uNew[uNew < uvMin] = uvMin
    vNew[vNew > uvMax] = uvMax
    vNew[vNew < uvMin] = uvMin
    #
    # To trim the interpolation tail from the right side
    iLonMax = np.argmin(np.abs(xTile-xMercator(lonNC.max())))
    if((i+1)*tileSize > iLonMax):
        if(i*tileSize > iLonMax):
            uNew[:, :] = 0
            vNew[:, :] = 0
        else:
            uNew[:, iLonMax % tileSize:] = 0
            vNew[:, iLonMax % tileSize:] = 0
    #
    # To trim the interpolation tail from the left side
    iLonMin = np.argmin(np.abs(xTile-xMercator(lonNC.min())))
    if(i*tileSize < iLonMin):
        if((i+1)*tileSize < iLonMin):
            uNew[:, :] = 0
            vNew[:, :] = 0
        else:
            uNew[:, :iLonMin % tileSize] = 0
            vNew[:, :iLonMin % tileSize] = 0
    #
    # To trim the interpolation tail from the top side
    jLatMax = np.argmin(np.abs(yTile-yMercator(latNC.max())))
    if((j+1)*tileSize > jLatMax):
        if(j*tileSize > jLatMax):
            uNew[:, :] = 0
            vNew[:, :] = 0
        else:
            uNew[jLatMax % tileSize:, :] = 0
            vNew[jLatMax % tileSize:, :] = 0
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile-yMercator(latNC.min())))
    if(j*tileSize < jLatMin):
        if((j+1)*tileSize < jLatMin):
            uNew[:, :] = 0
            vNew[:, :] = 0
        else:
            uNew[:jLatMin % tileSize, :] = 0
            vNew[:jLatMin % tileSize, :] = 0
    #
    # Normalize
    uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    #
    if(np.min(uNew) == 127 and np.max(uNew) == 127 and np.min(vNew) == 127 and np.max(vNew) == 127):
        return
    else:
        uvColored = np.empty(
            (uNew.shape[0], vNew.shape[1], 3), dtype=np.uint8)
        uvColored[:, :, 0] = uNew[:, :]
        uvColored[:, :, 1] = vNew[:, :]
        uvColored[:, :, 2] = 0
        imageio.imwrite('../tiles/Doppio_Currents_%s_avgDepth/%d/%d/%d.png' %
                        (dateSave, zoom, i, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


def saveTile(iTime):
    global dateSave
    global zoom, uTime, vTime
    global xTile, yTile, fu, fv
    #
    dateSave = (datetime(2017, 11, 1) +
                timedelta(hours=times[iTime])).strftime('%Y%m%d_%H')
    uTime = u[iTime, :, :]
    vTime = v[iTime, :, :]
    #
    # For interpolation, NaN is not accepted
    uTime[np.isnan(uTime)] = 0
    vTime[np.isnan(vTime)] = 0
    fu = interpolate.interp2d(xNC, yNC, uTime, kind='linear')
    fv = interpolate.interp2d(xNC, yNC, vTime, kind='linear')
    #
    #
    for zoom in np.arange(minZoom, maxZoom+1):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xTile = np.linspace(xMercator(-180),
                            xMercator(180), noOfPoints)
        yTile = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        # iters = np.array(np.meshgrid(np.arange(2**zoom),
        # np.arange(2**zoom))).T.reshape(-1, 2)
        iStart = max(math.floor(np.abs(xTile-xNC[0]).argmin()/tileSize)-1, 0)
        iEnd = math.ceil(np.abs(xTile-xNC[-1]).argmin()/tileSize)+1
        jStart = max(math.floor(np.abs(xTile-yNC[0]).argmin()/tileSize)-1, 0)
        jEnd = math.ceil(np.abs(xTile-yNC[-1]).argmin()/tileSize)+1
        iters = np.array(np.meshgrid(np.arange(iStart, iEnd),
                                     np.arange(jStart, jEnd))).T.reshape(-1, 2)
        #
        poolSize = min(len(iters), 32)
        with multiprocessing.Pool(poolSize) as p:
            p.starmap(saveImg, iters)


def saveNC(iTime):
    dateSave = (datetime(2017, 11, 1) +
                timedelta(hours=times[iTime])).strftime('%Y%m%d_%H')
    fileName = "Doppio_Currents_avgDepth_%s.nc" % (dateSave)
    ncout = Dataset(fileName, 'w', format='NETCDF4')
    #
    # define axis size
    ncout.createDimension('x', len(lonNC))
    ncout.createDimension('y', len(latNC))
    #
    # create latitude axis
    latitude = ncout.createVariable('latitude', 'double', ('y'))
    latitude.standard_name = 'latitude'
    latitude.long_name = 'latitude'
    latitude.units = 'degrees_north'
    latitude.axis = 'Y'
    #
    # create longitude axis
    longitude = ncout.createVariable('longitude', 'double', ('x'))
    longitude.standard_name = 'longitude'
    longitude.long_name = 'longitude'
    longitude.units = 'degrees_east'
    longitude.axis = 'X'
    #
    # create variable array
    uout = ncout.createVariable('u', 'double', ('y', 'x'))
    uout.long_name = 'zonal velocity'
    uout.units = 'm/s'
    uout.coordinates = "latitude longitude"
    #
    vout = ncout.createVariable('v', 'double', ('y', 'x'))
    vout.long_name = 'meridional velocity'
    vout.units = 'm/s'
    vout.coordinates = "latitude longitude"
    #
    # copy axis from original dataset
    longitude[:] = lonNC[:]
    latitude[:] = latNC[:]
    uout[:, :] = u[iTime, :, :]
    vout[:, :] = v[iTime, :, :]
    #
    # close files
    ncout.close()
    # print(tracemalloc.get_traced_memory())
    # tracemalloc.stop()


for iTime in np.arange(len(times)):
    saveTile(iTime)
    saveNC(iTime)  # For PP

exit()

#############################################
# Average depth for forecast/hindcast files
# Only if hr<24
# if (hr<24):
latOld = latNC  # np.arange(30, 90, 0.08)
lonOld = lonNC  # np.arange(0, 360, 0.08)
latNew = np.arange(30, 90, 0.04)
lonNew = np.arange(-180, 180, 0.04)
#
# Regrid (GNT needs same lat & lon resolution)
iDepth100 = np.argmin(np.abs(depths-100))  # index of depth=100 m
iDepth1000 = np.argmin(np.abs(depths-1000))  # index of depth=1000 m
uNew = np.empty((iDepth1000+1, len(latNew), len(lonNew))) * np.nan
vNew = np.empty((iDepth1000+1, len(latNew), len(lonNew))) * np.nan
#


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


# Average from 100 to 1000 m depth
uZavg = np.nanmean(uNew[iDepth100:iDepth1000+2, :, :], axis=0)
vZavg = np.nanmean(vNew[iDepth100:iDepth1000+2, :, :], axis=0)
# Where depth<100, average from 0 to 100
uBelow100Avg = np.nanmean(uNew[:iDepth100+1, :, :], axis=0)
uZavg[np.isnan(uZavg)] = uBelow100Avg[np.isnan(uZavg)]
vBelow100Avg = np.nanmean(vNew[:iDepth100+1, :, :], axis=0)
vZavg[np.isnan(vZavg)] = vBelow100Avg[np.isnan(vZavg)]
del uNew, vNew, uBelow100Avg, vBelow100Avg


# Write netCDF
# open a netCDF file to write
fileName = "avg/RIOPS_Currents_avgDepth_%s_%02d.nc" % (dateSave, hrSave)
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


# copy axis from original dataset
longitude[:] = lonNew[:]
latitude[:] = latNew[:]
uout[:, :] = uZavg[:, :]
vout[:, :] = vZavg[:, :]

# close files
ncout.close()
# print(tracemalloc.get_traced_memory())
# tracemalloc.stop()
