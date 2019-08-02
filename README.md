# Scripts to install, remove and manage an Auto-HotSpot on a Raspberry Pi

Version 20190802

Auto-HotSpot is a feature that allows the Raspberry Pi to become a "HotSpot" (WiFi access point).  This allows other computers, phones, and tablets to connect to and operate the Pi (using [VNC](https://www.raspberrypi.org/documentation/remote-access/vnc/)) over WiFi.  This Auto-HotSpot uses the [script written by roboberry](http://www.raspberryconnect.com/network/item/330-raspberry-pi-auto-wifi-hotspot-switch-internet) for use on Raspbian Stretch or Buster.

## Prerequisites

- Raspberry Pi 3B, 3B+ or 4 (NOTE: I have only tested this image with 3B and 3B+.) running Raspbian Stretch or Buster
- Familiarity with the Pi's Terminal application and basic LINUX commands

## Installation

1. On your Pi, open a browser and go to [autohotspot](https://github.com/AG7GN/autohotspot) on GitHub.  If you are reading this README online, you're already there.

1. Click __Clone or download__.  Click __Download ZIP__.

1. Open a Terminal and run these commands:

         cd Downloads
         mv autohotspot-master.zip ~
         cd ~
         unzip -o autohotspot-master.zip
         cd autohotspot-master
         chmod +x install-autohotspot-scripts.sh
         ./install-autohotspot-scripts.sh

1. Close the Terminal by clicking __File > Close Window__ or typing `exit` and press __Enter__ in the Terminal window.

1. Click __Raspberry > Preferences > Manage Auto-HotSpot__.  Follow the instructions on the screen.
   
## Notes

1.  When Auto-HotSpot is enabled, the Pi will create a HotSpot if an already configured WiFi network (as defined in `/etc/wpa_supplicant/wpa_supplicant.conf`) is __not__ within range.

1. The Pi will create a HotSpot if it's ethernet port is connected and no configured WiFi network is within range.  If that ethernet connection provides Internet access, users connected to the HotSpot can share that Internet connection.  

1. Internet access is not required for Auto-HotSpot to work.

1. If 'Check WiFi' is enabled in the __Manage Auto-HotSpot__ configuration screen, a cron job will be installed in the user's crontab that will periodically check to see if any configured WiFi networks are in range and if so, it will automatically disable Auto-HotSpot and instead connect as a client to that network.  Any users connected to the HotSpot will be disconnected if that happens.

1. You can remove, reinstall, or reconfigure Auto-HotSpot at any time by running the __Manage Auto-HotSpot__ script at __Raspberry > Preferences > Manage Auto-HotSpot__.

1. When Auto-HotSpot is enabled, if you hover your mouse over the opposing arrows icon in the upper right of the screen, you will see a status of "wlan0:STOPPED".  That means the Pi's WiFi interface is in hotspot mode.

1. When Auto-HotSpot is disabled or uninstalled, clicking on the opposing arrows icon should show a list of available WiFi networks.  Select the desired network and provide the password.  Once connected, this network will automatically be added to `/etc/wpa_supplicant/wpa_supplicant.conf`.  If you install/enable Auto-HotSpot at this point, the HotSpot will not activate as long as your Pi can connect to this WiFi network.

   If you no longer want to use the WiFi network the Pi is currently connected to, click on the opposing arrows icon, then right-click on the checked network.  Click __OK__ when prompted "Do you want to disconnect from the Wi-Fi network...?".  This will remove this WiFi network from `/etc/wpa_supplicant/wpa_supplicant.conf`.  Remember that if you disconnect while operating the Pi remorely, you will "saw off the limb you're sitting on" and will be disconnected from the Pi.
   
1. For more details on how the HotSpot operates see the [original article](http://www.raspberryconnect.com/network/item/330-raspberry-pi-auto-wifi-hotspot-switch-internet) on which this is based.





