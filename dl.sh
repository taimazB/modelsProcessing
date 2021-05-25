HERE=/home/taimaz/Projects/OceanGNS/data

cd ${HERE}

if [[ ! -e ${HERE}/.inProgress ]]; then
    > ${HERE}/.inProgress
    > ${HERE}/log

    # cd ${HERE}/Chlorophyll/NESDIS/
    # echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    # ./main.sh
    # echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log

    cd ${HERE}/SST/JPLMUR41/
    echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    ./main.sh
    echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log

    cd ${HERE}/SWH/CMC/
    echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    ./main.sh
    echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log
    
    cd ${HERE}/Seaice/CMC/
    echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    ./main.sh
    echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log

    cd ${HERE}/Currents/WMOP-surface/
    echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    ./main.sh
    echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log
    
    cd ${HERE}/Currents/CMC/
    echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    ./main.sh
    echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log

    cd ${HERE}/Currents/HYCOM/
    echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    ./main.sh
    echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log
    
    cd ${HERE}/Currents/RIOPS/
    echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    ./main.sh
    echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log
    

    rm ${HERE}/.inProgress
fi
