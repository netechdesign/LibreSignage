#!/bin/bash

set -e
. build/build_conf.sh

mkdir -p $DIST_DIR;

# Copy LibreSignage files to dist/.
echo 'Copy LibreSignage files to "'$DIST_DIR'".';
cp -Rp $SRC_DIR/* $DIST_DIR/.;

# Set correct file permissions.
echo "Set default file permissions (Owner: $DEF_OWNER | Mode: $DEF_MODE)";
chown -R $DEF_OWNER $DIST_DIR;
chmod -R $DEF_MODE $DIST_DIR;

echo "Set file permission exceptions.";
for i in "${!owner_data[@]}"; do
	echo "${owner_data[$i]} $DIST_DIR/$i" | xargs -t chown
done

for i in "${!mode_data[@]}"; do
	echo "${mode_data[$i]} $DIST_DIR/$i" | xargs -t chmod
done