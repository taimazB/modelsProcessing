#!/bin/bash
ftpLink="http://dd.alpha.weather.gc.ca/yopp/model_riops/netcdf/forecast/polar_stereographic/3d/"  ## 2020-11 and after
# export ftpLink="http://dd.alpha.weather.gc.ca/yopp/model_riops/netcdf/forecast/polar_stereographic/archives/3d/"  ## 2020-10 and before

############################################################################


function dl {
    # axel -c -a -n 50 -o u_${date}_${hr}.nc "${ftpLink}${year}/${month}/${day}/00/${hr}/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_${year}${month}${day}00_P${hr}.nc"
    # axel -c -a -n 50 -o v_${date}_${hr}.nc "${ftpLink}${year}/${month}/${day}/00/${hr}/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_${year}${month}${day}00_P${hr}.nc"
    
    hr=$1
    axel -q -c -a -n 50 -o u_${date}_${hr}.nc "${ftpLink}${year}/${month}/${day}/00/${hr}/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_${year}${month}${day}00_P${hr}.nc"
    axel -q -c -a -n 50 -o v_${date}_${hr}.nc "${ftpLink}${year}/${month}/${day}/00/${hr}/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_${year}${month}${day}00_P${hr}.nc"
}
# done
export -f dl


m=05
for d in {01..25}; do
    export date=2021${m}${d}
    
    echo "##  Proccesing ${date} ..."
    export year=`date -d ${date} +%Y`
    export month=`date -d ${date} +%m`
    export day=`date -d ${date} +%d`
    
    # for hr in {000..021..3}; do ##  multiple downloads are not allowed in this server -> no use of parallel
    
    # parallel "dl {}" ::: {000..021..3}
    for hr in {000..021..3}; do
	axel -q -c -a -n 50 -o u_${date}_${hr}.nc "${ftpLink}${year}/${month}/${day}/00/${hr}/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_${year}${month}${day}00_P${hr}.nc"
	axel -q -c -a -n 50 -o v_${date}_${hr}.nc "${ftpLink}${year}/${month}/${day}/00/${hr}/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_${year}${month}${day}00_P${hr}.nc"
    done
done

exit


for f in *.st; do
    uv=`echo $f | cut -d_ -f1`
    date=`echo $f | cut -d_ -f2`
    hr=`echo $f | cut -d_ -f3 | sed 's/\.nc\.st//'`
    year=`date -d ${date} +%Y`
    month=`date -d ${date} +%m`
    day=`date -d ${date} +%d`
    
    if [[ ${uv} == "u" ]]; then
	axel -c -a -n 50 -o u_${date}_${hr}.nc "${ftpLink}${year}/${month}/${day}/00/${hr}/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_${year}${month}${day}00_P${hr}.nc"
    elif [[ ${uv} == "v" ]]; then
	axel -c -a -n 50 -o v_${date}_${hr}.nc "${ftpLink}${year}/${month}/${day}/00/${hr}/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_${year}${month}${day}00_P${hr}.nc"
    fi
done


function regrid {
    hr=$1
    echo ${hr}
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,/home/taimaz/Projects/mapBoxData/Currents/RIOPS/nc/.grid2.txt u_${date}_${hr}.nc CMC_RIOPS_ux_${date}_${hr}.nc
    
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,/home/taimaz/Projects/mapBoxData/Currents/RIOPS/nc/.grid2.txt v_${date}_${hr}.nc CMC_RIOPS_vy_${date}_${hr}.nc
}
export -f regrid

m=10
for d in {01..31}; do
    export date=2020${m}${d}
    echo "##  Proccesing ${date} ..."
    parallel -j 2 "regrid {}" ::: {000..021..03}
done










############  png

function py {
    hr=$1
    echo ${hr}
    python3 scripts/cnv.py ${date} ${hr}
}
export -f py

m=07
for d in {01..31}; do
    export date=2020${m}${d}
    echo "##  Proccesing ${date} ..."
    parallel -j 2 "py {}" ::: {000..021..03}
done




##################################################
##  Convert png to jpg  (png's are big)
cd ${HERE}/png/
ls *.png | parallel 'convert {} ../jpg/`basename {} .png`.jpg'
mv ${HERE}/png/*.png /media/taimaz/f74aa447-fe2f-44af-8ee6-3bb554756a5d/taimaz/RIOPS/png/
