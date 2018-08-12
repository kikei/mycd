#!/bin/sh

help() {
    echo "Usage: $0 cuefile targetdir"
}

artist_in_cue() {
    cue=$1
    artist=$(grep PERFORMER $cue | sed -e 's/PERFORMER "\(.*\)"$/\1/')
    echo $artist
}

title_in_cue() {
    cue=$1
    title=$(grep TITLE $cue | sed -e 's/TITLE "\(.*\)"$/\1/' | head -1)
    echo $title
}

setup_artist_tags() {
    artist="$1"
    flac="$2"
    value=$(metaflac --show-tag ARTIST "$flac")
    if [ -x $value ]; then
    	metaflac --set-tag "ARTIST=$artist" "$flac"
    fi
}

setup_date_tags() {
    year="$1"
    flac="$2"
    value=$(metaflac --show-tag DATE "$flac")
    if [ -x $value ]; then
    	metaflac --set-tag "DATE=$year" "$flac"
    fi
}

setup_tags() {
    cue="$1"
    dir="$2"
    cd "$dir"
    artist=$(artist_in_cue "$cue")
    echo -n "Release year?: "
    read year
    IFS_orig=$IFS
    IFS=$'\n'
    cuetag.sh "$cue" $(
	for f in $(find . -type f -name "*.flac"); do
	    echo $f | sed -e 's/ /\ /g' 
	done)
    if [ $? != 0 ]; then
	echo "Error, failed to add tags by cuetag.sh."
	exit
    fi
    for f in $(find . -type f -name "*.flac"); do
	setup_artist_tags $artist $f
	if [ ! -x $year ]; then
	    setup_date_tags $year $f
	fi
    done
    IFS=$IFS_orig
}

if [ $# != 2 ]; then
    help
    exit 1
fi

cue="$1"
dir="$2"

if [ ! -f "$cue" ]; then
    echo "Cue file not exists, path=$cue"
    exit 1
fi
if [ ! -d "$dir" ]; then
    echo "Musics directory not exists, path=$dir"
    exit 1
fi

resolve_path() {
    path="$1"
    case $path in
	[/~]*)
	    echo $path
	    ;;
	*)
	    echo "`pwd`/$path"
	    ;;
    esac
}
cue=$(resolve_path "$cue")
dir=$(resolve_path "$dir")

setup_tags "$cue" "$dir"
