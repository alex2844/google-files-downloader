#!/usr/bin/env bash

if [ ! -e 'drive' ]; then
	echo 'Error: drive not mounted';
	exit;
fi
cd drive;
dirs=();
dirs_my=($(shopt -s nullglob; echo *));
dirs_i=0;
for dirname_my in "${dirs_my[@]}"; do
	if [ "$dirname_my" == 'Shared drives' ]; then
		dirs_shared=($(shopt -s nullglob; echo Shared\ drives/*));
		for dirname_shared in "${dirs_shared[@]}"; do
			dirs+=("$dirname_shared");
		done
	else
		dirs+=("$dirname_my");
	fi
done
for dirname in "${dirs[@]}"; do
	if [ -e "$dirname/googleFilesDownloader" ]; then
		dirs_d="$dirname";
		break;
	fi
done
if [ -z "$dirs_d" ]; then
	for dirname in "${dirs[@]}"; do
		echo "$((++dirs_i)): $dirname";
	done
	read -p 'Please select a directory: ' dirs_s;
	dirs_d="${dirs[$((dirs_s-1))]}"
	if [ -z "$dirs_d" ]; then
		echo 'Error: directory not found';
		exit;
	fi;
fi
cd "$dirs_d";
if [ ! -e "googleFilesDownloader" ]; then
	mkdir 'googleFilesDownloader';
fi
if [ ! -e "googleFilesDownloader" ]; then
	exit;
fi;
cd 'googleFilesDownloader';
DRIVE=$(pwd);
ls > /dev/null;
torrent=($(shopt -s nullglob; echo *.torrent));
torrent_i=0;
for torrentname in "${torrent[@]}"; do
	if [ "$torrentname" == '*.torrents' ]; then
		continue;
	fi
	echo "$((++torrent_i)): $torrentname";
done
if [ "$torrent_i" -ne "0" ]; then
	read -p "Please select a torrent file: " torrent_s;
	if [ ! -z "$torrent_s" ]; then
		TORRENT_FILE="${torrent[$((torrent_s-1))]}";
		if [ ! -z "$TORRENT_FILE" ]; then
			is_torrent=1;
		fi
	fi
fi
if [ -z "$TORRENT_FILE" ]; then
	read -p "URL: " URL;
fi
read -p "Compress files? [Y/n]: " COMPRESS;
cd '/content';
if [ ! -e 'googleFilesDownloader' ]; then
	mkdir 'googleFilesDownloader';
fi
cd 'googleFilesDownloader';
if [ -z "$URL" ]; then
	if [ -z "$TORRENT_FILE" ]; then
		echo 'Error: url not found';
		exit;
	fi
else
	if [ -n "`echo $URL | grep -e '^magnet'`" ]; then
		is_magnet=1;
	elif [ -n "`echo $URL | grep -e '^http'`" ]; then
		if [ -n "`echo $URL | grep -e '\.torrent$'`" ]; then
			is_torrent=1;
		else
			is_http=1;
		fi
	else
		is_torrent=1;
		URL="https://drive.google.com/uc?export=download&id=$URL";
	fi;
fi
if [ "$is_http" == "1" ]; then
	hash=$(echo -n "$URL" | md5sum | awk '{print $1}');
	mkdir -p $hash;
	cd $hash;
	if [[ -z `type -p aria2c` ]]; then
		apt install aria2 -y
	fi
	aria2c -x 10 -s 10 $URL;
elif [ "$is_torrent" == "1" ]; then
	if [ ! -z "$URL" ]; then
		hash=$(echo -n "$URL" | md5sum | awk '{print $1}');
	else
		hash=$(echo -n "$TORRENT_FILE" | md5sum | awk '{print $1}');
	fi
	mkdir -p $hash;
	cd $hash;
	read -p "Download the full files? [Y/n]: " FULL;
	if [[ -z `type -p aria2c` ]]; then
		apt install aria2 -y
	fi
	if [ ! -z "$URL" ]; then
		TORRENT_FILE="$hash.torrent";
		curl -L -o $TORRENT_FILE "$URL";
	else
		TORRENT_FILE="$DRIVE/$TORRENT_FILE";
	fi
	if [ "${FULL^^}" == "N" ]; then
		aria2c -S "$TORRENT_FILE";
		read -p "Please select a files (1,2,3): " FILES;
		aria2c --allow-overwrite --disable-ipv6 --seed-time=0 --seed-ratio=0.0 --select-file="$FILES" "$TORRENT_FILE";
	else
		aria2c --allow-overwrite --disable-ipv6 --seed-time=0 --seed-ratio=0.0 "$TORRENT_FILE";
	fi
elif [ "$is_magnet" == "1" ]; then
	hash=$(echo "$URL" | grep -oP "(?<=btih:).*?(?=&)");
	mkdir -p $hash;
	cd $hash;
	read -p "Download the full files? [Y/n]: " FULL;
	if [[ -z `type -p aria2c` ]]; then
		apt install aria2 -y
	fi
	if [ "${FULL^^}" == "N" ]; then
		aria2c --bt-metadata-only=true --bt-save-metadata=true -q "$URL";
		aria2c -S "$hash.torrent";
		read -p "Please select a files (1,2,3): " FILES;
		aria2c --allow-overwrite --disable-ipv6 --seed-time=0 --seed-ratio=0.0 --select-file="$FILES" $hash.torrent;
	else
		aria2c --allow-overwrite --disable-ipv6 --seed-time=0 --seed-ratio=0.0 "$URL";
	fi
fi
if [ -e "$hash.torrent" ]; then
	rm $hash.torrent;
fi
if [ "${COMPRESS^^}" == "N" ]; then
	mv ../$hash "$DRIVE/";
else
	zip -r "$DRIVE/$hash.zip" ./;
	rm -r ../$hash;
fi
echo 'FINISH';
