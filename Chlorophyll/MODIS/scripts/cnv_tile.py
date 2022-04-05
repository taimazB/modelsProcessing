import numpy as np
from netCDF4 import Dataset
import os
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
import gc


date = sys.argv[1]

ncFile = Dataset("NESDIS_Chlorophyll_%s_12.nc" % date, 'r')
var = ncFile.variables['chlor_a'][0,0].data
lat = ncFile.variables['latitude'][:].data
lon = ncFile.variables['longitude'][:].data
print("##  File load done.")

varMin = -3 ## log(0.001)
varMax = 3 ## log(1000.)
var[np.isnan(var)] = 0

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



##  NaN = white
color0 = [(255,255,255)]

##  Purple range
colors1 = colorRange([0,51,0],[153,255,153],200)
colors2 = colorRange([255,255,0],[255,153,51],200)
colors3 = colorRange([255,0,0],[255,204,204],200)

##  All ranges
colors = np.array(color0+colors1+colors2+colors3)


##  If interpolation fails for big array, use noOfPieces>1
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
    for zoom in np.arange(2,8):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xx = np.linspace(np.min(x), np.max(x), int(noOfPoints/noOfPieces))
        yy = np.linspace(yMercator(-maxTileLat), yMercator(maxTileLat), noOfPoints)
        #
        if zoom<=5:
            varNew = interp(xx, yy).astype(np.int)
            varLog = np.log10(varNew)
            varLog[varLog<varMin] = varMin
            varLogRounded = np.round(varLog, 2)
            varLogInt = (100*(varLogRounded-varMin)).astype(np.int)
            print("##  Interpolating done.")
            #
            varColored = colors[varLogInt]
            print("##  Coloring done.")
            #
            #
            ##  Save multiple resolutions
            for i in np.arange(int(2**zoom/noOfPieces)):
                for j in np.arange(2**zoom):
                    devNull = os.system('mkdir -p ../tiles/NESDIS_Chlorophyll_%s_12/%d/%d' % (date,zoom,i+iSub*int(2**zoom/noOfPieces)))
                    varSub = varColored[j*tileSize:(j+1)*tileSize,i*tileSize:(i+1)*tileSize,:]
                    img2list = np.flipud(varSub).reshape(-1, 3*varSub.shape[1]).astype(np.uint8)
                    with open('../tiles/NESDIS_Chlorophyll_%s_12/%d/%d/%d.png' % (date,zoom,i+iSub*int(2**zoom/noOfPieces),2**zoom-j-1), 'wb') as f:
                        writer = png.Writer(width=varSub.shape[1], height=varSub.shape[0], bitdepth=8, greyscale=False)
                        writer.write(f, img2list)
            #
            #
        else: ##  For memory issues, need to break into chunks for zooms>=6
            xLength = 8*tileSize  ##  Due to memory issue
            xChunks = int(xx.size / xLength)
            for iZoomSub in np.arange(xChunks):
                xxSub = xx[int(iZoomSub*noOfPoints/noOfPieces/xChunks):int((iZoomSub+1)*noOfPoints/noOfPieces/xChunks)]
                varNew = interp(xxSub, yy).astype(np.int)
                varLog = np.log10(varNew)
                varLog[varLog<varMin] = varMin
                varLogRounded = np.round(varLog, 2)
                varLogInt = (100*(varLogRounded-varMin)).astype(np.int)
                print("##  Interpolating %d of %d done." % (iZoomSub,xChunks))
                #
                varColored = colors[varLogInt]
                print("##  Coloring done.")
                #
                #
                ##  Save multiple resolutions
                for i in np.arange(8):
                    for j in np.arange(2**zoom):
                        devNull = os.system('mkdir -p ../tiles/NESDIS_Chlorophyll_%s_12/%d/%d' % (date,zoom, i+8*iZoomSub+8*xChunks*iSub))
                        varSub = varColored[j*tileSize:(j+1)*tileSize,i*tileSize:(i+1)*tileSize,:]
                        img2list = np.flipud(varSub).reshape(-1, 3*varSub.shape[1]).astype(np.uint8)
                        with open('../tiles/NESDIS_Chlorophyll_%s_12/%d/%d/%d.png' % (date,zoom,i+8*iZoomSub+8*xChunks*iSub, 2**zoom-j-1), 'wb') as f:
                            writer = png.Writer(width=varSub.shape[1], height=varSub.shape[0], bitdepth=8, greyscale=False)
                            writer.write(f, img2list)

