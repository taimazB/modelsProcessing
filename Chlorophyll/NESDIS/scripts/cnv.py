import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
from colour import Color


date = sys.argv[1] ## eg 20201217

ncFile = Dataset("NESDIS_Chlorophyll_%s_12.nc" % date, 'r')
chlr = ncFile.variables['chlor_a'][0,0].data
lat = ncFile.variables['latitude'][:].data
lon = ncFile.variables['longitude'][:].data
chlrMin = -3 ## log(0.001)
chlrMax = 3 ## log(1000.)

chlr[np.isnan(chlr)] = 0  ##  For interpolation, NaN is not accepted

##  latitude and longitude
##  nc files are already from lat: 80S to 80N
# lat = np.arange(-80,80.01,0.01)
# lon = np.arange(0,359.99,0.01)


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), 36000)  ## 0.01 deg
yy = np.linspace(np.min(y), np.max(y), 16000)  ## 0.01 deg


f = interpolate.interp2d(x, y, chlr, kind='linear')
    
chlrNew = f(xx, yy)
chlrLog = np.log10(chlrNew)
chlrLog[chlrLog<chlrMin] = chlrMin
chlrLogRounded = np.round(chlrLog, 2)
chlrLogInt = (100*(chlrLogRounded-chlrMin)).astype(np.int)

##  NaNs = white
color0  = [Color('white').rgb]

##  Green range
colors1 = [color.rgb for color in list(Color("#030").range_to(Color("#9f9"), 200))]

##  Yellow range
colors2 = [color.rgb for color in list(Color("#ff0").range_to(Color("#f93"), 200))]

##  Red range
colors3 = [color.rgb for color in list(Color("#f00").range_to(Color("#fcc"), 200))]

##  All ranges
colors = np.array(color0+colors1+colors2+colors3)

chlrColored = 255*colors[chlrLogInt]


for i in np.arange(18):
    ##  Due to the damn Mercator projection:
    j = 0
    for lat1,lat2 in zip(np.arange(-80,80,20),np.arange(-60,100,20)):
        y1 = R * np.log( np.tan(np.pi/4 + lat1*np.pi/180/2) )
        j1 = np.abs(yy-y1).argmin()
        y2 = R * np.log( np.tan(np.pi/4 + lat2*np.pi/180/2) )
        j2 = np.abs(yy-y2).argmin()
        subChlr = chlrColored[j1:j2, i*2000:(i+1)*2000]
        img2list = np.flipud(subChlr).reshape(-1, 3*subChlr.shape[1]).astype(np.uint8)
        #
        with open('../png/NESDIS_Chlorophyll_%s_12/NESDIS_Chlorophyll_%s_12_reg%02d-%02d.png' % (date,date,i,j), 'wb') as f:
            writer = png.Writer(width=subChlr.shape[1], height=subChlr.shape[0], bitdepth=8, greyscale=False)
            writer.write(f, img2list)
        j += 1

exit()

plt.imshow(sstNew)
plt.show()
