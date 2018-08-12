#!/bin/sh

ABCDE=abcde
SHNSPLIT=shnsplit
FILE_INWAV=
SKIP_RIPPING=0
DIR_WAVOUT=./wav
DIR_FLACOUT=./flac
DIR_LIGHTOUT=./mp4
TAG_DATE=$(date "+%Y")

help() {
    cat <<EOF
Usage: $0 [Options]

Options:
    -iw wavfile       Skip ripping and use wavfile as input.
    -ow directory     Directory for wav output.
    -of directory     Directory for flac output.
    -td year          Set date tag with year.
    --help, -h        Show this help.
EOF
}

setup_dir() {
    dir="$1"
    if [ ! -d "$dir" ]; then
	echo "Creating directory $dir"
	mkdir -p "$dir"
    fi
}


check_requirements() {
    if [ ! `which abcde` ]; then
	echo "Error, abcde needs to be installed."
	exit 1
    fi
    if [ ! `cuetag.sh` ]; then
	echo "Error, cuetag.sh needs to be installed."
	exit 1
    fi
    if [ ! `flac` ]; then
	echo "Error, metaflac needs to be installed."
	exit 1
    fi
    if [ ! `metaflac` ]; then
	echo "Error, metaflac needs to be installed."
	exit 1
    fi
}

while [ $# -gt 0 ]; do
    case $1 in
	-iw)
	    FILE_INWAV=$2
	    shift 2
	    ;;
	-ow)
	    DIR_WAVOUT=$2
	    shift 2
	    ;;
        -of)
	    DIR_FLACOUT=$2
	    shift 2
	    ;;
	-h)
	    help
	    exit 1
	    ;;
	*)
	    help
	    exit 1
	    ;;
    esac
done

extract_wav() {
    wavout=$1
    $ABCDE -1 -d /dev/cdrom -M -n -o wav -x
    if [ $? != 0 ]; then
	return $?
    fi
    rm -rf abcde.*
}

# Ripping
# cdrom -> wav, cue

echo "Ripping from cdrom..."

setup_dir $DIR_WAVOUT

if [ ! -x $FILE_INWAV ]; then
    echo "Skip cdrom ripping."
    WAV=$FILE_INWAV
else
    extract_wav $DIR_WAVOUT
    if [ $? != 0 ]; then
	echo "Error, wav file not exists ($?)."
	exit 1
    fi
    name=$(ls -t -1 | head -1)
    mv $name $wavout
    if [ $? != 0 ]; then
	echo "Error, failed to move wav file, name=$name."
	exit 1
    fi
    WAV=$(find $wavout/$name -type f -name "*.wav" | head -1)
fi

if [ ! -f $WAV ]; then
    echo "Error, wav file not exists, file=$WAV."
    exit 1
fi

CUE=${WAV%.*}.cue
echo "Done. wav=$WAV, cue=$CUE."

if [ ! -f $CUE ]; then
    echo "Error, cue file not exists, file=$CUE."
    exit 1
fi

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

ARTIST=$(artist_in_cue $CUE)
TITLE=$(title_in_cue $CUE)

echo "Ripping done."
echo "    Artist: $ARTIST"
echo "    Title: $TITLE"

split_flac() {
    out=$1
    wav=$2
    cue=$3
    $SHNSPLIT -f $cue -d $out -o 'flac flac -s -o %f -' -t "%n - %t" $wav
    return $?
}

split_mp4() {
    out=$1
    wav=$2
    cue=$3
    $SHNSPLIT -f $cue -d $out -o 'flac flac -s -o %f -' -t "%n - %t" $wav
}

# Encoding
# wav, cue -> flac

setup_dir $DIR_FLACOUT

echo "Splitting wav file to songs, wav=$WAV..."
split_flac $DIR_FLACOUT $WAV $CUE
if [ $? != 0 ]; then
    echo "Error, failed to split wav files."
    exit 1
fi

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
    cue=$1
    dir=$2
    cuetag.sh $cue $dir/*.flac
    artist=$(artist_in_cue $cue)
    year=$TAG_DATE
    IFS_orig=$IFS
    IFS=$'\n'
    for f in $(find $dir -type f -name "*.flac"); do
	setup_artist_tags $artist $f
	if [ ! -x $year ]; then
	    setup_date_tags $year $f
	fi
    done
    IFS=$IFS_orig
}

escape() {
    t="$*"
    echo $t | tr '/' '_' | \
	sed -e 's/ /\ /g' | \
	sed -e 's/(/\(/g' | \
	sed -e 's/)/\)/g' | \
	sed -e 's/!/\!/g' | \
	sed -e 's/?/\?/g'
}

# Tagging
# cue, flac -> flac
echo "Applying tags from cue file, cue=$CUE..."
setup_tags $CUE $DIR_FLACOUT

ARTIST_ESC="$(escape $ARTIST)"
TITLE_ESC="$(escape $TITLE)"
DIR_NAME="$ARTIST_ESC/$TITLE_ESC"
DIR_DEST="./$DIR_NAME"
setup_dir "$DIR_NAME"

# Rename as done
echo "Moving flac files to $DIR_DEST..."
mv $DIR_FLACOUT/*.flac "$DIR_DEST"

# Generating compressed version
# flac -> m4a

DIR_DESTL="$DIR_LIGHTOUT/$DIR_NAME"
setup_dir "$DIR_DESTL"

echo "Converting flac to aac..."

IFS_orig=$IFS
IFS=$'\n'
for f in $(find "$DIR_DEST" -type f -name "*.flac"); do
    echo $f
    m4a="$DIR_DESTL/$(basename $f .flac).m4a"
    ffmpeg -i "$f" -c:a aac -b:a 192k -v warning "$m4a"
done
IFS=$IFS_orig

