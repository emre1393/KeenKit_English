#!/bin/sh

REPO="KeenKit"
SCRIPT="keenkit.sh"
TMP_DIR="/tmp"
OPT_DIR="/opt"

if ! opkg list-installed | grep -q "^curl"; then
  opkg update
  opkg install curl
fi

#curl -L -s "https://raw.githubusercontent.com/spatiumstas/$REPO/main/$SCRIPT" --output $TMP_DIR/$SCRIPT
#it needs to get translated bash script from fork
curl -L -s "https://raw.githubusercontent.com/emre1393/KeenKit_English/main/keenkit.sh" --output $TMP_DIR/$SCRIPT
mv "$TMP_DIR/$SCRIPT" "$OPT_DIR/$SCRIPT"
chmod +x $OPT_DIR/$SCRIPT
cd $OPT_DIR/bin
ln -sf $OPT_DIR/$SCRIPT $OPT_DIR/bin/keenkit
$OPT_DIR/$SCRIPT