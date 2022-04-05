export ext=20642
export tileSize=512
export mainDir=~/Projects/mapBoxData/SST/JPLMUR41/


function tile {
    file=$1
    zoom=$2
    mkdir -p ${mainDir}/tiles/${file}/${zoom}
    convert -resize $((2**zoom*tileSize))x$((2**zoom*tileSize))\! ${mainDir}/png/${file}.png miff:- | convert miff:- -crop ${tileSize}x${tileSize} ${mainDir}/tiles/${file}/${zoom}/%05d.png
    cd ${mainDir}/tiles/${file}/${zoom}/
    for i in `seq 0 $((2**zoom-1))`; do
	for j in `seq 0 $((2**zoom-1))`; do
	    mkdir $j 2>/dev/null
	    indx=`printf %05d $((i*(2**zoom)+j))`
	    mv ${indx}.png ${j}/${i}.png
	done
    done
}
export -f tile


cd ${mainDir}/png/
for file in JPLMUR41_SST_20210502_09.png; do
    parallel -j 4 "tile `basename ${file} .png` {}" ::: {2..6}
done
