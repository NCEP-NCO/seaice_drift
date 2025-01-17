#!/bin/ksh
########################################################### 
# Sea ice drift forecast model control script for
# Arctic and Antarctic.
# Produce Bulletins for OSO
# History: Sep 1997 - First implementation of new      
#        : Robert Grumbine, author.  30 June 1997.
#        : Modified 09 September 1997 by L. D. Burroughs
#        : June 1998 - Modified to collaborate with T-170 MRF  
#        : FEB 2000 - Convert to IBM SP."
#        : Jun 2001 - modified to increase output from 6 to 16 days 
#        : Oct 2004 - Modified for CCS Phase 2
#        :            It is originally Job 930
#        : Mar 2007 - Modified for 10m winds
#        : Aug 2013 - Move to Ensemble input
########################################################### 

cd $DATA

########################################
set -x
msg="HAS BEGUN!"
postmsg "$jlogfile" "$msg"
###########################

export FILENV=$DATA/.assign.FORTRAN

#set MP_HOLDTIME to a larger number to speed up processing by 
# preventing CPUs from being rescheduled as frequently

export MP_HOLDTIME=2666666

#-----------------------------------------------------
# copy over the fix files
#-----------------------------------------------------
cp $FIXsice/seaice_quote seaice_quote   
cp $FIXsice/seaice_forecast.points seaice_forecast.points

pgm=seaice_sicedrft
export pgm; prep_step

ln -sf seaice_forecast.points fort.47
ln -sf seaice_quote fort.91

echo $PDY > alpha
ln -sf alpha     fort.90

#-----------------------------------------------------
#get the ice line points
#-----------------------------------------------------

if [ -f $COMINice_analy/seaice_edge.t00z.txt ] ; then
  cp $COMINice_analy/seaice_edge.t00z.txt .
  ln -sf seaice_edge.t00z.txt fort.48
else
  echo Running with reference ice edge
  cp $FIXsice/seaice_edge.t00z.txt fort.48
fi

#-----------------------------------------------------
#units for the gfs data
#New Mar 2007: Construct averaged 10m winds to single file vs.
#  old usage of sigma files
#-----------------------------------------------------
#GFS Files are available every 3 hours through the 180
#  then 12 hours through 384 (no need for average, straight wgribbing)
#Note that due to resolution changes, we need to run averager even
#  when files are 12 hours apart
#Ensemble is 6 hours throughout v4.0.0 -- August 2013

#Ensure that the output files don't already exist
for fn in u.averaged.$PDY v.averaged.$PDY
do
  if [ -f $fn ] ; then
    rm $fn
  fi
done
base=$COMIN

#Construct averages for 10m winds
set -xe
for hr in 0 12 24 36 48  60  72  84  96 108 120 132 144 156 168 180 192 204 216 \
                    228 240 252 264 276 288 300 312 324 336 348 360 372
do
  h1=$hr;
  h2=`expr $h1 + 6`
  if [ $h1 -lt 10 ] ; then
    h1=0$h1;
  fi
  if [ $h2 -lt 10 ] ; then
    h2=0$h2;
  fi
  if [ $h1 -lt 100 ] ; then
    h1=0$h1;
  fi
  if [ $h2 -lt 100 ] ; then
    h2=0$h2;
  fi

  for mem in gep01 gep02 gep03 gep04 gep05 gep06 gep07 gep08 gep09 gep10 gep11 gep12 gep13 gep14 gep15 gep16 gep17 gep18 gep19 gep20
  do

    #${WGRIB2:?} ${base}/$mem.t${cyc}z.pgrb2a.0p50_bcf$h1  > index

    #grep 'UGRD:10 m above ground:' index | $WGRIB2 -i ${base}/$mem.t${cyc}z.pgrb2a.0p50_bcf$h1 -order we:ns -bin tmpu.${mem}.$h1.$PDY
    #grep 'VGRD:10 m above ground:' index | $WGRIB2 -i ${base}/$mem.t${cyc}z.pgrb2a.0p50_bcf$h1 -order we:ns -bin tmpv.${mem}.$h1.$PDY

    #${WGRIB2:?} ${base}/$mem.t${cyc}z.pgrb2a.0p50_bcf$h2 > index
    #grep 'UGRD:10 m above ground:' index | $WGRIB2 -i ${base}/$mem.t${cyc}z.pgrb2a.0p50_bcf$h2 -order we:ns -bin tmpu.${mem}.$h2.$PDY
    #grep 'VGRD:10 m above ground:' index | $WGRIB2 -i ${base}/$mem.t${cyc}z.pgrb2a.0p50_bcf$h2 -order we:ns -bin tmpv.${mem}.$h2.$PDY

    #from WCOSS1
    ${WGRIB2:?} ${base}/$mem.t${cyc}z.pgrb2a_bcf$h1  > index

    grep 'UGRD:10 m above ground:' index | $WGRIB2 -i ${base}/$mem.t${cyc}z.pgrb2a_bcf$h1 -order we:ns -bin tmpu.${mem}.$h1.$PDY
    grep 'VGRD:10 m above ground:' index | $WGRIB2 -i ${base}/$mem.t${cyc}z.pgrb2a_bcf$h1 -order we:ns -bin tmpv.${mem}.$h1.$PDY

    ${WGRIB2:?} ${base}/$mem.t${cyc}z.pgrb2a_bcf$h2 > index
    grep 'UGRD:10 m above ground:' index | $WGRIB2 -i ${base}/$mem.t${cyc}z.pgrb2a_bcf$h2 -order we:ns -bin tmpu.${mem}.$h2.$PDY
    grep 'VGRD:10 m above ground:' index | $WGRIB2 -i ${base}/$mem.t${cyc}z.pgrb2a_bcf$h2 -order we:ns -bin tmpv.${mem}.$h2.$PDY

    #preaverage appends the info:
    $EXECsice/seaice_preaverage u.averaged.${mem}.$PDY tmpu.${mem}.$h1.$PDY tmpu.${mem}.${h2}.$PDY
    $EXECsice/seaice_preaverage v.averaged.${mem}.$PDY tmpv.${mem}.$h1.$PDY tmpv.${mem}.${h2}.$PDY
  done
done

echo done with pre-averaging

#-------------------------- loop over each member for forecast
for mem in gep01 gep02 gep03 gep04 gep05 gep06 gep07 gep08 gep09 gep10 gep11 \
           gep12 gep13 gep14 gep15 gep16 gep17 gep18 gep19 gep20
do
  ln -sf u.averaged.${mem}.$PDY fort.11
  ln -sf v.averaged.${mem}.$PDY fort.12

  #-----------------------------------------------------
  #execute the model
  #-----------------------------------------------------
  msg="pgm sicedrft has BEGUN!"
  postmsg "$jlogfile" "$msg"

  time echo 32 | $EXECsice/seaice_sicedrft >> $pgmout 2>> errfile
  err=$?; export err; err_chk
  
  # Move each output file to temporary location:
  mv grid_ds grid_ds.$mem
  mv fort.60 fort.60.$mem
  mv fort.61 fort.61.$mem
  mv fort.62 fort.62.$mem
  mv fort.63 fort.63.$mem
  mv fort.64 fort.64.$mem
  # Will produce single best-guess kml file
  rm *.kml

done
echo done with running ensemble members

#-----------------------------------------------------
#NEW (2 June 2014) Down average to best guess from ensemble
#-----------------------------------------------------
#Blend the ensemble members down to a best guess
msg="pgm seaice_midpoints has begun"
postmsg "$jlogfile" "$msg"
time $EXECsice/seaice_midpoints fort.60.* fl.out ak.out >> $pgmout 2>> errfile
err=$?; export err; err_chk
echo debug midpoints:
ls -ls fl.out ak.out

#Reformat for distribution
cp fl.out fort.31
msg="pgm seaice_reformat has begun"
postmsg "$jlogfile" "$msg"
time $EXECsice/seaice_reformat  >> $pgmout 2>> errfile
err=$?; export err; err_chk

#copy to old names:
ln -sf fort.60 fl.out
ln -sf fort.61 ops.out
ln -sf fort.62 ak.out
ln -sf fort.63 global.tran
ln -sf fort.64 alaska.tran

#-----------------------------------------------------
#Distribute the output
#-----------------------------------------------------
if [ $SENDCOM = "YES" ] ; then
  cp ops.out            $COMOUT/global.$PDY
  cp ak.out             $COMOUT/alaska.$PDY
  cp seaice_drift_*.kml $COMOUT
  cp grid_ds.gep??      $COMOUT
  #cp fort.61.gep??      $COMOUT
  cp global.tran $COMOUT/global.tran.$PDY
  cp alaska.tran $COMOUT/alaska.tran.$PDY
  cp global.tran $pcom/global.tran.${cycle}
  cp alaska.tran $pcom/alaska.tran.${cycle}
  if [ "$SENDDBN" = 'YES' ] ; then
    $USHsice/make_ntc_bull.pl WMOHD NONE KWBC NONE alaska.tran $pcom/alaska.tran.${cycle}
    #$USHsice/make_ntc_bull.pl WMONV NONE KWBC NONE global.tran $pcom/global.tran.${cyc}.$job
    $USHsice/make_ntc_bull.pl WMONV NONE KWBC NONE global.tran $pcom/global.tran.${cyc}.ice_drift_00
    $DBNROOT/bin/dbn_alert MODEL ICE_DRIFT$SENDDBN_SUFFIX $job $COMOUT/global.$PDY
    $DBNROOT/bin/dbn_alert MODEL ICE_DRIFT$SENDDBN_SUFFIX $job $COMOUT/alaska.$PDY
    $DBNROOT/bin/dbn_alert MODEL ICE_DRIFT$SENDDBN_SUFFIX $job $COMOUT/global.tran.$PDY
    $DBNROOT/bin/dbn_alert MODEL ICE_DRIFT$SENDDBN_SUFFIX $job $COMOUT/alaska.tran.$PDY
    for file in `ls $COMOUT/*.kml`
    do
      $DBNROOT/bin/dbn_alert MODEL ICE_DRIFT_KML$SENDDBN_SUFFIX $job $file
    done
  fi
fi

#####################################################################
# GOOD RUN
set +x
echo "**************$job COMPLETED NORMALLY "
echo "**************$job COMPLETED NORMALLY "
echo "**************$job COMPLETED NORMALLY "
set -x
#####################################################################

#################################

msg='HAS COMPLETED NORMALLY.'
echo $msg
postmsg "$jlogfile" "$msg"


#------------------------------------------------------------------
# End of script
#------------------------------------------------------------------
