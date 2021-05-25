import numpy as np
from netCDF4 import Dataset
import os
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
from datetime import datetime, timedelta


date = sys.argv[1]
hr = int(sys.argv[2])

dateSave = datetime.strptime(date, "%Y%m%d")
hrSave = hr
while(hrSave>=24):
    dateSave += timedelta(days=1)
    hrSave -= 24


ncFile = Dataset("CMC_gdwps_global_ICEC_SFC_0_latlon0.25x0.25_%s00_P%03d.nc" % (date, hr), 'r')
var = ncFile.variables['ci'][0].data
lat = ncFile.variables['lat'][:].data
lon = ncFile.variables['lon'][:].data
print("##  File load done.")

varMin = 0.
varMax = 1.
var[var<varMin] = varMin  ##  For interpolation, NaN is not accepted

var = var[np.logical_and(lat<=85, lat>=-85), :]  ##  lat: 85S - 85N
lat = lat[np.logical_and(lat<=85, lat>=-85)]  ##  lat: 85S - 85N

##  Switch west and east
tmp = np.copy(var[:,:720])
var[:,:720] = var[:,720:]
var[:,720:] = tmp


maxTileLat = 85.0511287798066
tileSize = 512 ## px
maxZoom = 8


def yMercator(lat):
    return R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


def colorRange(color1, color2, n):
    colors = []
    for r,g,b in zip(np.linspace(color1[0],color2[0],n) ,np.linspace(color1[1],color2[1],n) ,np.linspace(color1[2],color2[2], n)):
        colors.append((r,g,b))
    return colors

    
##  No Ice = White
color0 = [(0,51,153)]
colors1 = colorRange([0,51,153],[255,255,255],100)

##  All ranges
colors = np.array(color0+colors1)


##  Interpolation fails for such big array, so break into pieces (only lon-wise)
noOfPieces = 1
for iSub in np.arange(noOfPieces):
    print("***  iSub: %d" % iSub)
    lonSize = int(lon.size/noOfPieces)
    subLon = lon[iSub*lonSize:(iSub+1)*lonSize]
    subVar = var[:,iSub*lonSize:(iSub+1)*lonSize]
    #
    #
    ##  Mercator
    R = 6378137
    x = R * subLon * np.pi/180.
    y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )
    #
    #
    ##  For interpolation
    interp = interpolate.interp2d(x, y, subVar, kind='linear')
    print("##  Interpolation function done.")
    #
    #
    for zoom in np.arange(2,6):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xx = np.linspace(np.min(x), np.max(x), int(noOfPoints/noOfPieces))
        yy = np.linspace(yMercator(-maxTileLat), yMercator(maxTileLat), noOfPoints)
        #
        if zoom<=5:
            varNew = interp(xx, yy)
            print("##  Interpolating done.")
            #
            varNewRounded = np.round(varNew, 2)
            varNewInt = (100*(varNewRounded-varMin)).astype(np.int32)
            varNewInt[varNewInt<0] = 0
            varNewInt[varNewInt>100*(varMax-varMin)] = 100*(varMax-varMin)
            varColored = colors[varNewInt]
            print("##  Coloring done.")
            #
            #
            ##  Save multiple resolutions
            for i in np.arange(int(2**zoom/noOfPieces)):
                for j in np.arange(2**zoom):
                    devNull = os.system('mkdir -p ../tiles/CMC_Seaice_%s_%02d/%d/%d' % (datetime.strftime(dateSave, "%Y%m%d"),hrSave,zoom,i+iSub*int(2**zoom/noOfPieces)))
                    varSub = varColored[j*tileSize:(j+1)*tileSize,i*tileSize:(i+1)*tileSize,:]
                    img2list = np.flipud(varSub).reshape(-1, 3*varSub.shape[1]).astype(np.uint8)
                    with open('../tiles/CMC_Seaice_%s_%02d/%d/%d/%d.png' % (datetime.strftime(dateSave, "%Y%m%d"),hrSave,zoom,i+iSub*int(2**zoom/noOfPieces),2**zoom-j-1), 'wb') as f:
                        writer = png.Writer(width=varSub.shape[1], height=varSub.shape[0], bitdepth=8, greyscale=False)
                        writer.write(f, img2list)
            #
            #
        else: ##  For memory issues, need to break into chunks for zooms>=6
            xLength = 8*tileSize  ##  Due to memory issue
            xChunks = int(xx.size / xLength)
            for iZoomSub in np.arange(xChunks):
                xxSub = xx[int(iZoomSub*noOfPoints/noOfPieces/xChunks):int((iZoomSub+1)*noOfPoints/noOfPieces/xChunks)]
                varNew = interp(xxSub, yy).astype(np.int32)
                print("##  Interpolating %d of %d done." % (iZoomSub,xChunks))
                #
                varNewRounded = np.round(varNew, 2)
                varNewInt = (100*(varNewRounded-varMin)).astype(np.int32)
                varNewInt[varNewInt<0] = 0
                varNewInt[varNewInt>100*(varMax-varMin)] = 100*(varMax-varMin)
                varColored = colors[varNewInt]
                print("##  Coloring done.")
                #
                #
                ##  Save multiple resolutions
                for i in np.arange(8):
                    for j in np.arange(2**zoom):
                        devNull = os.system('mkdir -p ../tiles/CMC_Seaice_%s_%02d/%d/%d' % (datetime.strftime(dateSave, "%Y%m%d"),hrSave,zoom, i+8*iZoomSub+8*xChunks*iSub))
                        varSub = varColored[j*tileSize:(j+1)*tileSize,i*tileSize:(i+1)*tileSize,:]
                        img2list = np.flipud(varSub).reshape(-1, 3*varSub.shape[1]).astype(np.uint8)
                        with open('../tiles/CMC_Seaice_%s_%02d/%d/%d/%d.png' % (datetime.strftime(dateSave, "%Y%m%d"),hrSave,zoom, i+8*iZoomSub+8*xChunks*iSub, 2**zoom-j-1), 'wb') as f:
                            writer = png.Writer(width=varSub.shape[1], height=varSub.shape[0], bitdepth=8, greyscale=False)
                            writer.write(f, img2list)

