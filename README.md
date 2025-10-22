# Cisco-SIP

This script will install a PXE server that can be used to nuke Cisco
IP Phones and install some (possibly olde) SIP firmware on them.

Installation of the PXE server will include making a mess of your
/srv/tftp/ if you have one.

Best run on / tested on a fresh Linux Mint 22.x

Written by / (C)opyright 2025 "Nosey" Nick Waterman...
https://github.com/NoseyNick
... for Computer Recycling @ The Working Centre

## Instructions...

* `mkdir -p ~/Code`
* `cd ~/Code`
* `git clone https://github.com/chaslinux/cisco-sip.git` # -- this repo
* Helps to have a standalone switch on eth0 at this point - see below
* `sudo ~/Code/cisco-sip/Cisco-SIP.sh`

Subsequent instructions will appear on screen:

* plug any number of cisco IP phones into a switch,
  (or one directly into) Ethernet port
* Use the (left-most?) SW/NETWORK port on the phone, NOT PC (right)
* Power up phone WHILST HOLDING #
* BE PATIENT - some bootloaders take several minutes! (EG 7941, 7961)
* When blinky-light sequence begins (on line buttons or reciever)...
* Release #.  Firmly dial 1 2 3 4 5 6 7 8 9 * 0 #  but DO NOT RUSH
* Phone should factory-reset and boot into firmware resinstall
* There will be a sequence of (5?) checkboxes that fill in with a
  sequence of 🔲 (todo) ⬇️ (downloading) ✅️ (ready) ░░ (flashed)
* Phone should say "Wiped for CR at TWC" when done
