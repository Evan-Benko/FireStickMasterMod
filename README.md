# Wireless ADB FireStick Master Mod


## Intended use, Start on your Firestick:
### make sure your firestick is in developer mode with adb Debugging ON
### to turn on developer mode go to settings -> myFireTV -> about -> Fire TV Stick (click it 7 times until it says you are already a developer)
### to enable ADB debugging go to settings -> myFireTV -> Developer Options -> ADB debugging (Set it to ON)
## Now on your Mac:
### execute the following commands in a new terminal
### cd to the folder directory for example 
### cd downloads/fire 
### if you have the folder in the downloads directory
### ./adb connect firestick_IP_ADDRESS
### for example 
### ./adb connect 192.168.40.21
### to find your firestick ip go to settings -> myFireTv -> about -> network -> use the IP Address shown
### there should be a pop up on your computer to confirm you want the MAC to connect, accept it
### next run the following
### for file in *.apk; do ./adb install "$file"; done
### just wait for all the apps to install you should see them show up as they insatll on the Firestick


## how to add more apks to install
 ### simply download any .apk files compatible with the firestick and drop them in the fire directory
