#!/bin/bash

# This script runs on every start calles by boostrap.service
# It makes sure that the system is configured like the
# default values or as in the config.
# For more details see background_raspiblitzSettings.md

# load codeVersion
source /home/admin/_version.info

logfile="/home/admin/raspiblitz.log"
echo "Writing logs to: ${logfile}"
echo "" > $logfile
echo "***********************************************" >> $logfile
echo "Running RaspiBlitz Bootstrap ${codeVersion}" >> $logfile
date >> $logfile
echo "***********************************************" >> $logfile


################################
# AFTER BOOT SCRIPT
# when a process needs to 
# execute stuff after a reboot
# /home/admin/setup.sh
################################

# check for after boot script
afterSetupScriptExists=$(ls /home/admin/setup.sh 2>/dev/null | grep -c setup.sh)
if [ ${afterSetupScriptExists} -eq 1 ]; then
  echo "*** SETUP SCRIPT DETECTED ***"
  # echo out script to journal logs
  sudo cat /home/admin/setup.sh
  # execute the after boot script
  sudo /home/admin/setup.sh
  # delete the after boot script
  sudo rm /home/admin/setup.sh
  # reboot again
  echo "DONE wait 6 secs ... one more reboot needed ... "
  sudo shutdown -r now
  sleep 100
fi


################################
# PUBLIC IP
# for LND on startup
################################
printf "PUBLICIP=$(curl -vv ipinfo.io/ip 2> /run/publicip.log)\n" > /run/publicip;
chmod 774 /run/publicip


################################
# HDD CHECK / INIT
# for the very first setup
################################

# check if the HDD is mounted
hddAvailable=$(ls -la /mnt/hdd 2>/dev/null)
if [ ${#hddAvailable} -eq 0 ]; then
  echo "HDD is NOT available" >> $logfile
  echo "TODO: Try to mount."
  exit 1
fi

################################
# CONFIGFILE BASICS
################################

# check if there is a config file
configFile="/mnt/hdd/raspiblitz.conf"
configExists=$(ls ${configFile} 2>/dev/null | grep -c '.conf')
if [ ${configExists} -eq 0 ]; then

  # create new config
  echo "creating config file: ${configFile}" >> $logfile
  echo "# RASPIBLITZ CONFIG FILE" > $configFile
  echo "raspiBlitzVersion='${version}'" >> $configFile
  sudo chmod 777 ${configFile}

else

  # load & check config version
  source $configFile
  if [ "${raspiBlitzVersion}" != "${raspiBlitzVersion}" ]; then
      echo "detected version change ... starting migration script" >> $logfile
      /home/admin/_migrateVersion.sh
  fi

fi

################################
# DEFAULT VALUES
################################

# AUTOPILOT
# autoPilot=off|on
if [ ${#autoPilot} -eq 0 ]; then
  echo "autoPilot=off" >> $configFile
fi

# after all default values written to config - reload config
source $configFile


################################
# AUTOPILOT
################################

echo "" >> $logfile
echo "** AUTOPILOT" >> $logfile

# check if LND is installed
lndExists=$(ls /mnt/hdd/lnd/lnd.conf 2>/dev/null | grep -c '.conf')
if [ ${lndExists} -eq 1 ]; then

  # check if autopilot is active in LND config
  lndAutopilot=$( grep -c "autopilot.active=1" /mnt/hdd/lnd/lnd.conf )
  echo "confAutopilot(${autoPilot})" >> $logfile
  echo "lndAutopilot(${lndAutopilot})" >> $logfile

  # switch on
  if [ ${lndAutopilot} -eq 0 ] && [ "${autoPilot}" = "on" ]; then
    echo "switching the LND autopilot ON" >> $logfile
    sudo sed -i "s/^autopilot.active=.*/autopilot.active=1/g" /mnt/hdd/lnd/lnd.conf
  fi

  # switch off
  if [ ${lndAutopilot} -eq 1 ] && [ "${autoPilot}" = "off" ]; then
    echo "switching the LND autopilot OFF" >> $logfile
    sudo sed -i "s/^autopilot.active=.*/autopilot.active=0/g" /mnt/hdd/lnd/lnd.conf
  fi

else

 echo "WARNING: /mnt/hdd/lnd/lnd.conf does not exists. Setup needs to run properly first!" >> $logfile

fi

echo "" >> $logfile
echo "DONE BOOTSTRAP" >> $logfile