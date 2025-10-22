#!/bin/bash -efu
cat <<__EOF__
######################################################################
# This script will install a PXE server that can be used to nuke Cisco
# IP Phones and install some (possibly olde) SIP firmware on them.
# This will include making a mess of your /srv/tftp/ if you have one
# Best run on / tested on a fresh Linux Mint 22.x
# Written by / (C)opyright 2025 "Nosey" Nick Waterman, for...
# Computer Recycling @ The Working Centre
######################################################################
__EOF__
# Consider occasionally:  shellcheck Cisco-SIP.sh

# Initial checks: Are we root?
case "${USER:-}" in
  root) ROOT_BAD="" ;;
  *)    ROOT_BAD="PLEASE RUN AS ROOT - sudo $0" ;;
esac

# ... on what OS?
# shellcheck source=/dev/null # Just don't need the file below when shellchecking
. /etc/os-release || PRETTY_NAME="UNKNOWN OS!!!"
case "$PRETTY_NAME" in
  "Linux Mint 22."*) OS_OK="$PRETTY_NAME - Perfect" ;;
  "Linux Mint"*)     OS_OK="$PRETTY_NAME - UNTESTED - GOOD LUCK!" ;;
  *)                 OS_OK="PRETTY_NAME - UNLIKELY TO WORK!!!" ;;
esac

# What ethernet interface are we likely to use?
IF=''
while IFS=' :|' read -r THIS_IF _IGNORE; do
  case "$THIS_IF" in
    Inter-|face  ) : ;; # Ignore these column headings...
    lo*   | wl*  ) : ;; # ... and these "dangerous" interfaces
    eth*  | enp* ) IF="$THIS_IF" ;; # Accept these interfaces
    *) echo "!!! Unrecognised interface $THIS_IF - edit $0 ?" ;;
  esac
done < /proc/net/dev

cat <<__EOF__
# Do you understand that this will:
# * Need to run as root - ${ROOT_BAD:-looks good!}
# * ... on a supported OS: $OS_OK
# * Run a DHCP and PXE server on ${IF:-WHAT ETHERNET IF=ethNN or whatever???}
# * ... which may interfere with normal booting or internet access for
#   machines on that interface!
# * Probably make a mess of any existing /srv/tftp/ :
__EOF__
ls /srv/tftp/ || true # error is fine if this does not exist
[[ "$ROOT_BAD" ]] && echo "$ROOT_BAD" && exit 9 # Nein!

BANNER () {
  echo "######################################################################"
  date +"# %F %T $*"
}
DIE () {
  BANNER "FATAL: $*"
  exit 9
}

######################################################################
BANNER  "Do you understand and accept the above?"

while read -rp "# Yes or No? [YN] : " YES; do case "$YES" in
  Y*|y*) YES=1  ; break ;;
  N*|n*) YES='' ; break ;;
esac; done
[[ "$IF" ]]       || exit 9 # Nein!
[[ "$YES" ]]      || exit 9 # Nein!

######################################################################
BANNER  Installing DHCPd and TFPTd

apt update
apt install -y udhcpd tftpd-hpa

######################################################################
BANNER  "Configuring $IF ..."

NEED_ETH="You'll need a switch (or IP Phone) on Ethernet port $IF"

IP4=''  PREFIX=''
DEVLIST=$(nmcli -t device show "$IF")
while IFS=:/ read -r KEY VAL VAL2; do
  case "$KEY" in
    IP4.ADDRESS*)  IP4="$VAL"  PREFIX="$VAL2" ;;
    WIRED-PROPERTIES.CARRIER) case "$VAL" in
      on) echo "... has carrier, good" ;;
      *) BANNER "WARNING WARNING! $NEED_ETH" ;;
    esac ;;
  esac
done <<< "$DEVLIST"

if [[ "$IP4" ]]; then
  echo "# Found IP4 addr $IP4 /$PREFIX"
else
  IP4=192.168.0.1  PREFIX=24
  echo "# No IP4 addr - configuring $IP4 /$PREFIX"
  nmcli connection add type ethernet \
    ifname "$IF" \
    ipv4.method manual \
    ipv4.addresses "$IP4/$PREFIX"
fi

case "$PREFIX" in
  24) : ;; # Fine
  *)
    echo "Sorry, this script is too stoopid to handle a /$PREFIX or anything except /24"
    exit 9
    ;;
esac

######################################################################
BANNER  "Configuring DHCP for $IP4 network on $IF ..."

IFS=. read -r A B C _D <<<"$IP4"

if ! [[ -f /etc/udhcpd.conf.orig ]]; then
  mv -vf /etc/udhcpd.conf /etc/udhcpd.conf.orig || true # not an error to fail
fi

cat > /etc/udhcpd.conf <<__EOF__
start        $A.$B.$C.20
end          $A.$B.$C.254
interface    $IF
siaddr       $IP4 # myself
optionsubnet 255.255.255.0
optrouter    $A.$B.$C.2
optiondomain local
option       lease  300 # 5min
__EOF__

systemctl restart udhcpd.service 
systemctl status  udhcpd.service --no-pager || DIE "$NEED_ETH"

######################################################################
BANNER  "Configuring TFTPd..."

mkdir -vp /srv/tftp/
sed -Ei~ 's/(TFTP_OPTIONS)=.*/\1="--secure -v -v -v"/' \
  /etc/default/tftpd-hpa
diff /etc/default/tftpd-hpa{~,} || true # if diff or nonexist

systemctl restart tftpd-hpa.service
systemctl status  tftpd-hpa.service --no-pager

######################################################################
BANNER  "Building /srv/tftp/ ..."

cd /srv/tftp/

FW_CX_DL () {
  URL="https://www.firewall.cx/downloads/$1/download.html"
  echo "# $URL ..."
  if [[ -f "$1.zip" ]]; then
    echo "#   ... already got"
  else
    wget -O "$1.tmp" "$URL"
    mv -v "$1.tmp" "$1.zip"
  fi
  if [[ -f "$2" ]]; then
    echo "#   ... already got $2"
  else
    unzip -o "$1.zip" "$2"
  fi
  tar xvf "$2"
}

FW_CX_DL cisco-7906g-7911g-sccp-sip-firmware-v9-2-1 \
  7906_7911/Sip/cmterm-7911_7906-sip.9-2-1.tar
# FW_CX_DL cisco-7940-7960-sccp-sip-firmware-v8-1-2-sr2-v3-8-12 \
#   7940_7960/SIP/P0S3-8-12-00.tar
FW_CX_DL cisco-7941-7961-sccp-sip-firmware-v9-2-1 \
  7941_7961/SIP/cmterm-7941_7961-sip.9-2-1.tar
FW_CX_DL cisco-7942-7962-sccp-sip-firmware-v9-2-1 \
  7942_7962/Sip/cmterm-7942_7962-sip.9-2-1.tar
FW_CX_DL cisco-7945g-7965g-sccp-sip-firmware-v9-2-1 \
  7945_7965/Sip/cmterm-7945_7965-sip.9-2-1.tar

if [[ -f cmterm-7945_7965-sip.9-4-2-1SR3-1.zip ]]; then
  echo "GOT cmterm-7945_7965-sip.9-4-2-1SR3-1.zip"
else
  wget https://archive.org/download/cmterm-7945_7965-sip.9-4-2-1SR3-1/cmterm-7945_7965-sip.9-4-2-1SR3-1.zip
fi
unzip -o cmterm-7945_7965-sip.9-4-2-1SR3-1.zip

######################################################################
BANNER Checks...

grep '^[0-9a-f]' <<__EOF__ | shasum --check
44204a076ad827cf42cf17e0846c40e7c568b9d7  cisco-7906g-7911g-sccp-sip-firmware-v9-2-1.zip
# df6d94b87315f15357ce9645429c92d95cd6cf24  cisco-7940-7960-sccp-sip-firmware-v8-1-2-sr2-v3-8-12.zip
5713afa7ee70b4010a1199d125cde5d5d83aba75  cisco-7941-7961-sccp-sip-firmware-v9-2-1.zip
b364b366793409593183e9aa34d2a33f48c55cf3  cisco-7942-7962-sccp-sip-firmware-v9-2-1.zip
82b3f0b005e4def08e1a18340aafc86e27ad94d3  cisco-7945g-7965g-sccp-sip-firmware-v9-2-1.zip
10463f5c3a963d9fccb52f73fe8e76df10f4a014  cmterm-7945_7965-sip.9-4-2-1SR3-1.zip

e0f60b8161e6da9ba5c144ebdfcb5a94eb74f8d3  apps11.9-2-1TH1-13.sbn
fdc3f9d110f370348b5624e3897143783b0215c8  apps41.9-2-1TH1-13.sbn
9c90cbe8848ceb2c1a7a86c27dc28bb3d3177dd0  apps42.9-2-1TH1-13.sbn
e48519f8be1363c059128d9c8b8130c9a2329985  apps45.9-2-1TH1-13.sbn
87a0ff6863c371d2ddba4cddb66f7aaf55350095  apps45.9-4-2ES26.sbn
1fa968b2987ab7a40e7f781fe7506066389bfa46  cnu11.9-2-1TH1-13.sbn
f3faf637c5ab02bb03705c1a710b2ad3e8a539d6  cnu41.9-2-1TH1-13.sbn
55f6a78642e39bf3ff840cdaceb02f38fda878ec  cnu42.9-2-1TH1-13.sbn
e65419418fd35ab1d95bf8c12d868553cd7f06e8  cnu45.9-2-1TH1-13.sbn
c91f0ea4b84233f01b7e8606738a50a1bc44f16d  cnu45.9-4-2ES26.sbn
25bfc5960658e22bcbf278aba25ba59f22b6a658  cvm11sip.9-2-1TH1-13.sbn
a9b4a5d4e18ceb11df6466faed9cdfd687acb4fd  cvm41sip.9-2-1TH1-13.sbn
86c0a0058ad2dc887a79c9498d419cbd577d9eb8  cvm42sip.9-2-1TH1-13.sbn
9111519a7920dd2ac61b08eb318017952e1c453e  cvm45sip.9-2-1TH1-13.sbn
7649582fa1f176d44f73cf998b42f8464e308d9e  cvm45sip.9-4-2ES26.sbn
1bf2104aabbc3417d8513d555359d3927ddffc94  dsp11.9-2-1TH1-13.sbn
41abb4307d933a3f53493124c62fa2e934f45720  dsp41.9-2-1TH1-13.sbn
3a139ad3192ea02992e863b4b0c1b192383c6bac  dsp42.9-2-1TH1-13.sbn
a22e72bab461b7d1c26c4f7518416a884c257cd0  dsp45.9-2-1TH1-13.sbn
3bada8e66a23828747961f343a085ee8f34000b8  dsp45.9-4-2ES26.sbn
e880d07538a7dee8d8e545f42872ba0fc38f5256  jar11sip.9-2-1TH1-13.sbn
a6fad2ac31809edbf71abe88489a8103fd90058b  jar41sip.9-2-1TH1-13.sbn
e8c4f0a697dac49d0e8bc68e6ca09c3416dab17c  jar42sip.9-2-1TH1-13.sbn
bb2676f51f845ddc66110f361fab2ff4f451791e  jar45sip.9-2-1TH1-13.sbn
45b6502f4a9a14acb638b2bb60c16fd5b7d8fe35  jar45sip.9-4-2ES26.sbn
15e20d726f84b57233f0e216b98b8650feedcdae  term06.default.loads
ceb79b470adab712816219115e4059f66aeec508  term11.default.loads
322219e1647fcaeb793b2f52746ba85763bf2b68  term41.default.loads
4456b08509b83a494a6606a43311ace602b4bdd0  term42.default.loads
8a6d3a78f41ff7989e3c2d3c32289d9d1db07b8c  term45.default.loads
fb030af8d1092c99fc093b2ca4c7885fb69d0a62  term61.default.loads
471cfa57fbe95e912a1a4d567e3a9ce42dcc1dfa  term62.default.loads
ae73e3518d415742bfe28b378b71326cd1c4d429  term65.default.loads
__EOF__

######################################################################
BANNER "Our XMLDefault.cnf.xml ..."

mv -vf XMLDefault.cnf.xml{,~} || true # if it didn't exist
# FAIRLY minimal XMLDefault.cnf.xml - see notes below
cat > XMLDefault.cnf.xml <<__EOF__
<Default>
  <autoRegistrationName>WIPED for CR at TWC</autoRegistrationName>
  <callManagerGroup>
    <members>
      <member priority="0">
        <callManager>
	  <ports>
	    <ethernetPhonePort>2000</ethernetPhonePort>
	  </ports>
	  <processNodeName>$IP4</processNodeName>
	</callManager>
      </member>
    </members>
  </callManagerGroup>
</Default>
__EOF__
# Yes, it really does need a <callManagerGroup><members><member><callManager>
# with <ports><ethernetPhonePort> and <processNodeName> (will send SIP REGISTER there)
# Consider... AFTER </callManagerGroup> but BEFORE </Default>:
#  <loadInformation495   model="Cisco 6921">SIP69xx.9-4-1-3SR3</loadInformation495>
#  <loadInformation496   model="Cisco 6941">SIP69xx.9-4-1-3SR3</loadInformation496>
#  <loadInformation497   model="Cisco 6961">SIP69xx.9-4-1-3SR3</loadInformation497>
#  <loadInformation36217 model="Cisco 8811">sip88xx.11-2-3MSR1-1</loadInformation36217>
#  <loadInformation683   model="Cisco 8841">sip88xx.11-2-3MSR1-1</loadInformation683>
#  <loadInformation684   model="Cisco 8851">sip88xx.11-2-3MSR1-1</loadInformation684>
#  <loadInformation685   model="Cisco 8861">sip88xx.11-2-3MSR1-1</loadInformation685>
diff XMLDefault.cnf.xml{~,} || true # if diffs or nonexist

######################################################################
BANNER Instructions ...

cat <<__EOF__

* OK! Now plug any number of cisco IP phones into a switch,
  (or one directly into) Ethernet port $IF
* Use the (left-most?) SW/NETWORK port on the phone, NOT PC (right)
* Power up phone WHILST HOLDING #
* BE PATIENT - some bootloaders take several minutes! (EG 7941, 7961)
* When blinky-light sequence begins (on line buttons or reciever)...
* Release #.  Firmly dial 1 2 3 4 5 6 7 8 9 * 0 #  but DO NOT RUSH
* Phone should factory-reset and boot into firmware resinstall
* There will be a sequence of (5?) checkboxes that fill in with a
  sequence of 🔲 (todo) ⬇️ (downloading) ✅️ (ready) ░░ (flashed)
* Phone should say "Wiped for CR at TWC" when done

######################################################################
Will watch logs with:
  tail -F /var/log/syslog | grep -E 'dhcpd|tftpd'
__EOF__
  tail -F /var/log/syslog | grep -E 'dhcpd|tftpd'

######################################################################
# ++++++++++ TODO: More of a "status report" for the download process:
#   termXX.default.loads ->
#   jar*sip*.sbn -> cnu*.sbn -> apps*.sbn -> dsp*.sbn -> cvm*sip*.sbn ->
#   [misc] -> [SEP*.cnf.xml] -> XMLDefault.cnf.xml
