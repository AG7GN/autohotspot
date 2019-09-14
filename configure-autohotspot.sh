#!/bin/bash

# This script gathers configuration data from the user to set up a hotspot on a Raspberry Pi.
# The data it gathers is used to configure the following files:
# $HOME/autohotspot.conf
# /etc/sysctl.conf 
# /etc/default/hostapd
# /etc/dhcpcd.conf
# /etc/dnsmasq.conf
# 
# Script and instructions are from  http://www.raspberryconnect.com/network/item/330-raspberry-pi-auto-wifi-hotspot-switch-internet
#

VERSION="1.13"

CONFIG_FILE="$HOME/autohotspot.conf"
TITLE="Manage Auto-HotSpot version $VERSION"
SCRIPT_SITE="http://www.raspberryconnect.com"
SCRIPT_PAGE="/network/item/330-raspberry-pi-auto-wifi-hotspot-switch-internet"
AUTO_HS_SCRIPT="/usr/local/bin/autohotspotN"
CRON_HS_COMMAND="sudo $AUTO_HS_SCRIPT >/dev/null 2>&1"

trap errorReport INT

function errorReport () {
   echo
   if [[ $1 == "" ]]
   then
      exit 0
   else
      if [[ $2 == "" ]]
      then
         echo >&2 "$1"
         exit 1
      else
         echo >&2 "$1"
         exit $2
      fi
   fi         
}

WIFI_STATUS="$(iw phy | grep -i ^Wiphy)"
[[ $WIFI_STATUS == "" ]] && errorReport "WiFi is not enabled.  Enable it and run this program again."

if systemctl | grep -q "autohotspot"
then
   if systemctl | grep -q "autohotspot.*loaded"
   then
      STATUS="Enabled"
      if pgrep dnsmasq >/dev/null && pgrep hostapd > /dev/null
      then
         STATUS+=" and active"
      else
         STATUS+=" but inactive"
      fi
   else
      STATUS="Disabled"
   fi
else
   STATUS="Uninstalled"
fi

if [[ $STATUS =~ Enabled ]]
then
   yad --center --title="$TITLE" --text "<b><big><big>Auto-HotSpot Status: <span color='blue'>$STATUS</span>\n</big></big></b>" \
   --borders=20 \
   --buttons-layout=center \
   --text-align=center \
   --align=right \
   --button=gtk-cancel:1 --button="<b>Remove Auto-Hotspot</b>":10 --button="<b>Reconfigure Auto-HotSpot</b>":11
   ANSWER=$?
   #echo "ANSWER=$ANSWER"
   case $ANSWER in
      10) # Remove selected
         echo "Removing autohotspot service..."
         sudo systemctl disable autohotspot
         echo "Done."
         echo "Disable IPv4 forwarding..."
         sudo sed -i 's|^net.ipv4.ip_forward=1|#net.ipv4.ip_forward=1|' /etc/sysctl.conf
         echo "Done."
         TFILE="$(mktemp)"
         grep -v "^nohook wpa_supplicant" /etc/dhcpcd.conf > $TFILE
         sudo mv -f $TFILE /etc/dhcpcd.conf
         # Remove cronjob if present
         crontab -u $USER -l | grep -v "$CRON_HS_COMMAND" | crontab -u $USER -
         #rm -f "$CONFIG_FILE"
         yad --center --title="$TITLE" --text "<b><big><big>Auto-HotSpot has been disabled.  Reboot required.</big></big></b>" \
         --question --no-wrap \
         --borders=20 \
         --buttons-layout=center \
         --text-align=center \
         --align=right \
         --button="Reboot Now":0 --button=Close:1
         if [ "$?" -eq "1" ]
         then
            echo "" && echo "Skipped reboot" && echo ""
            exit 0
         else
            echo "" && echo "Reboot" && echo"" && sudo shutdown -r +0
         fi
         ;;
      11) # Reconfigure selected
         echo "Reconfigure selected"
         ;;
      *) # Cancel
         exit 0
         ;;
   esac
fi

if [ -s "$CONFIG_FILE" ]
then # There is a config file
   echo "$CONFIG_FILE found."
	source "$CONFIG_FILE"
else # Set some default values in a new config file
   echo "Config file $CONFIG_FILE not found.  Creating a new one with default values."
	echo "declare -A F" > "$CONFIG_FILE"
   echo "F[_SSID_]='$(echo -n $HOSTNAME)-HotSpot'" >> "$CONFIG_FILE"
   echo "F[_PASSPHRASE_]='$(echo -n $HOSTNAME)-HotSpot-pw'" >> "$CONFIG_FILE"
   echo "F[_CHANNEL_]='6'" >> "$CONFIG_FILE"
   echo "F[_INTERVAL_]='None'" >> "$CONFIG_FILE"
	source "$CONFIG_FILE"
fi

echo "Loading configuration GUI."

CHANNELs="$(iw phy | grep "\* 24.*MHz.*dBm)$" | tr -d '\t' | cut -d'[' -f2 | cut -d']' -f1 | tr '\n' '!' | sed 's/\!$//')"
if iw phy | grep -q "Band 2:"
then
   CHANNELs+="!36!149"
   MESSAGE="This Pi has dual band WiFi (2.4 and 5 GHz).  If you select channel 36 or 149, the hotspot will use the 5 GHz radio."
else
   MESSAGE="This Pi has single band WiFi (2.4 GHz only)."
fi
MESSAGE+="\n\nThe 'Check WiFi' setting below will create a cron job that will execute every 2,5,10 or 15 minutes\nto see if a configured WiFi network is in range.  If it is, it will deactivate Auto-HotSpot.\nSelecting 'No' will disable the cron job.\n\nDo not use single or double quotes in the SSID or Password."

[[ $CHANNELs =~ ${F[_CHANNEL_]} ]] && CHANNELs="$(echo "$CHANNELs" | sed "s/${F[_CHANNEL_]}/\^${F[_CHANNEL_]}/")" 

INTERVALs="No!2!5!10!15"
[[ $INTERVALs =~ ${F[_INTERVAL_]} ]] && INTERVALs="$(echo "$INTERVALs" | sed "s/${F[_INTERVAL_]}/\^${F[_INTERVAL_]}/")" 

ANS=""
ANS="$(yad --title="$TITLE" \
   --text="<b><big><big>Auto-HotSpot Configuration Parameters</big></big>\n\n</b>Status: <b><span color='blue'>$STATUS</span>\n\n \
$MESSAGE</b>\n" \
   --item-separator="!" \
   --center \
   --buttons-layout=center \
   --text-align=center \
   --align=right \
   --borders=20 \
   --form \
   --field="SSID (Network Name)" "${F[_SSID_]}" \
   --field="Hotspot Password (at least 8 characters)" "${F[_PASSPHRASE_]}" \
   --field="Channel":CB "$CHANNELs" \
	--field="Check WiFi":CB "$INTERVALs" \
   --focus-field 1 \
)"

[[ $? == 1 || $? == 252 ]] && errorReport  # User has cancelled.

[[ $ANS == "" ]] && errorReport "Error." 1

IFS='|' read -r -a TF <<< "$ANS"

F[_SSID_]="${TF[0]}"
F[_PASSPHRASE_]="${TF[1]}"
F[_CHANNEL_]="${TF[2]}"
F[_INTERVAL_]="${TF[3]}"

echo "declare -A F" > "$CONFIG_FILE"
for I in "${!F[@]}"
do
	echo "F[$I]='${F[$I]}'" >> "$CONFIG_FILE"
done

#: <<'END_COMMENT'
PKG_LIST="dnsmasq hostapd"
INSTALLED_LIST=""
for D in $PKG_LIST
do
   dpkg -l $D >/dev/null 2>&1 && INSTALLED_LIST+="$D "
done

if ! [[ $INSTALLED_LIST =~ "$PKG_LIST" ]]
then 
   echo "Install dnsmasq and hostapd if needed."
   sudo apt-get update
   for D in $PKG_LIST
   do
      if ! systemctl list-unit-files | grep -q $D
      then
         sudo apt-get install -y $D || errorReport "Unable to install $D"
      fi
		[[ $D == "hostapd" ]] && sudo systemctl unmask hostapd && sudo systemctl enable hostapd
      if systemctl list-unit-files | grep enabled | grep -q $D
      then 
      	sleep 5 
         sudo systemctl disable $D
      fi
   done
	#sudo systemctl unmask hostapd
   echo "Done."
fi

echo "Configuring dnsmasq and hostapd."
sudo sed -i 's|^#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
TFILE="$(mktemp)"
cat > $TFILE << EOF
#AutoHotspot config
interface=wlan0
bind-dynamic
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=192.168.50.150,192.168.50.200,255.255.255.0,12h
EOF
cat $TFILE | sudo tee --append /etc/dnsmasq.conf
rm $TFILE
if ! grep -q "nohook wpa_supplicant" /etc/dhcpcd.conf
then
   echo "nohook wpa_supplicant" | sudo tee --append /etc/dhcpcd.conf
fi
echo "Done."

echo "Enable IPv4 forwarding."
sudo sed -i 's|^#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf
echo "Done."

if ! [ -s $AUTO_HS_SCRIPT ]
then
   echo "Downloading autohotspot script"
   SCRIPT_URL="$SCRIPT_SITE"
   SCRIPT_URL+="$(wget -q -O - ${SCRIPT_SITE}${SCRIPT_PAGE} | grep /autohotspotN.txt | grep -Eoi '<a [^>]+>' | grep -Eo 'href="[^\"]+"' | cut -d'"' -f2)"
   [[ $SCRIPT_URL == $SCRIPT_SITE ]] && errorReport "Unable to access ${SCRIPT_SITE}${SCRIPT_PAGE} where the autohotspot script is stored."
   TFILE="$(mktemp)"
   wget -q -O $TFILE $SCRIPT_URL || errorReport "Unable to retrieve autohotspot script from $SCRIPT_URL"
   sudo chmod +x $TFILE
   sudo mv $TFILE $AUTO_HS_SCRIPT
   echo "Done."
fi

TFILE="$(mktemp)"

cat > $TFILE <<EOF
interface=wlan0
driver=nl80211
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
$(echo "ssid=${F[_SSID_]}" | tr -d '"')
$(echo "wpa_passphrase=${F[_PASSPHRASE_]}" | tr -d '"')
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
country_code=US
ieee80211n=1
ieee80211d=1
logger_syslog=0
logger_syslog_level=4
logger_stdout=-1
logger_stdout_level=0
EOF

case ${F[_CHANNEL_]} in
   36|149)
      cat >> $TFILE <<EOF
hw_mode=a
wmm_enabled=1
# N
require_ht=1
ht_capab=[MAX-AMSDU-3839][HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]
# AC
ieee80211ac=1
require_vht=1
ieee80211d=0
ieee80211h=0
vht_capab=[MAX-AMSDU-3839][SHORT-GI-80]
vht_oper_chwidth=1
channel=${F[_CHANNEL_]}
vht_oper_centr_freq_seg0_idx=$(( F[_CHANNEL_] + 6 ))
EOF
      ;; 
   *)
      cat >> $TFILE <<EOF
hw_mode=g
channel=${F[_CHANNEL_]}
wmm_enabled=0
EOF
      ;;
esac

sudo cp -f $TFILE /etc/hostapd/hostapd.conf

# Set up autohotspot.service if necessary and (re)start it.

if systemctl list-unit-files | grep enabled | grep -q autohotspot
then # autohotspot service already set up
   echo "Restarting autohotspot service"
   if systemctl | grep running | grep -q autohotspot.service
   then # autohotspot is running.  Restart it.
   	sudo systemctl restart autohotspot || errorReport "ERROR: autohotspot failed to restart" 1 
   else # autohotspot is stopped. Start it.
   	sudo systemctl start autohotspot || errorReport "ERROR: autohotspot failed to start" 1
   fi  
   echo "Done."
else # set up autohotspot service
   cat > "$TFILE" << EOF
[Unit]
Description=Automatically generates an internet Hotspot when a valid ssid is not in range
After=multi-user.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/autohotspotN
[Install]
WantedBy=multi-user.target
EOF
   sudo cp -f "$TFILE" /etc/systemd/system/autohotspot.service
   echo "Creating autohotspot service"
   sudo systemctl enable autohotspot || errorReport "ERROR enabling autohotspot" 1
   echo "Done."
   echo "Starting autohotspot service"
   sudo systemctl start autohotspot || errorReport "ERROR: autohotspot failed to start" 1
   echo "Done."
fi
rm "$TFILE"

if [[ ${F[_INTERVAL]} == "No" ]]
then # Remove cronjob if present
   crontab -u $USER -l | grep -v "$CRON_HS_COMMAND" | crontab -u $USER -
else
   echo "Installing crontab"
   WHO="$USER"
   WHEN="*/${F[_INTERVAL_]} * * * *"
   WHAT="$CRON_HS_COMMAND"
   JOB="$WHEN $WHAT"
   cat <(fgrep -i -v "$WHAT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
   echo "Done."
fi

yad --center --title="$TITLE" --text "<b><big><big>Auto-HotSpot is ready.  You should reboot now.</big></big></b>" \
  --question --no-wrap \
  --borders=20 \
  --buttons-layout=center \
  --text-align=center \
  --align=right \
  --button="Reboot Now":0 --button=Close:1
[[ $? == 0 ]] && sudo shutdown -r +0 || exit 0







