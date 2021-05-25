import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
from colour import Color


date = sys.argv[1]

ncFile = Dataset("JPLMUR41_SST_%s_09.nc" % date, 'r')
sst = ncFile.variables['analysed_sst'][0].data
# lat = ncFile.variables['lat'][:].data
lat = np.arange(-80,80,0.01)
lon = ncFile.variables['lon'][:].data
sstMin = -2.
sstMax = 35.


sst = sst[1000:-999,:]  ##  lat: 80S - 80N
sst -= 273.15
sst[sst<sstMin] = sstMin  ##  For interpolation, NaN is not accepted
sst[sst>sstMax] = sstMax


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), 36000)  ## 0.01 deg
yy = np.linspace(np.min(y), np.max(y), 16000)  ## 0.01 deg


f = interpolate.interp2d(x, y, sst, kind='linear')

sstNew = f(xx, yy)
sstNewRounded = np.round(sstNew, 1)
sstNewInt = (10*(sstNewRounded+2)).astype(np.int)

##  Continents = black
color0  = [Color('black').rgb]

##  Purple range
colors1 = [color.rgb for color in list(Color("#c0c").range_to(Color("#f9f"), 20))]

##  Blue range
colors2 = [color.rgb for color in list(Color("#039").range_to(Color("#6cf"), 100))]

##  Green range
colors3 = [color.rgb for color in list(Color("#030").range_to(Color("#9f9"), 100))]

##  Yellow range
colors4 = [color.rgb for color in list(Color("#ff0").range_to(Color("#f93"), 100))]

##  Red range
colors5 = [color.rgb for color in list(Color("#f00").range_to(Color("#fcc"), 50))]

##  All ranges
colors = np.array(color0+colors1+colors2+colors3+colors4+colors5)

sstColored = 255*colors[sstNewInt]


for i in np.arange(18):
    ##  Due to the damn Mercator projection:
    j = 0
    for lat1,lat2 in zip(np.arange(-80,80,20),np.arange(-60,100,20)):
        y1 = R * np.log( np.tan(np.pi/4 + lat1*np.pi/180/2) )
        j1 = np.abs(yy-y1).argmin()
        y2 = R * np.log( np.tan(np.pi/4 + lat2*np.pi/180/2) )
        j2 = np.abs(yy-y2).argmin()
        subSST = sstColored[j1:j2, i*2000:(i+1)*2000]
        img2list = np.flipud(subSST).reshape(-1, 3*subSST.shape[1]).astype(np.uint8)
        with open('../png/JPLMUR41_SST_%s_09/JPLMUR41_SST_%s_09_reg%02d-%02d.png' % (date,date,i,j), 'wb') as f:
            writer = png.Writer(width=subSST.shape[1], height=subSST.shape[0], bitdepth=8, greyscale=False)
            writer.write(f, img2list)
        j += 1


exit()

plt.imshow(sstNew)
plt.show()
