#!/bin/bash
readonly PROGDIR=$(cd $(dirname $0); cd .. ; pwd)
PROG="$PROGDIR/video_prep.sh -q"
SRCDIR=$PROGDIR/samples
OUTDIR=$PROGDIR/.test

if [ ! -d $OUTDIR ] ; then
	mkdir $OUTDIR
else
	rm $OUTDIR/*
fi

FILENO=0
for FILE in $SRCDIR/*.m* ; do
	FILENO=$(expr $FILENO + 1)
	BNAME=$(basename $FILE | cut -c1-6)
	FNAME="$OUTDIR/$BNAME.$FILENO"
	echo "### $FILE -- $BNAME ###"

	$PROG scale 	"$FILE" "$FNAME.scale.mp4"
	$PROG -s blur scale 	"$FILE" "$FNAME.blur.mp4"
	$PROG -w 1000x1000 scale 	"$FILE" "$FNAME.square.mp4"
	$PROG -c last append 	"$FILE" "$FNAME.last.mp4"
	$PROG -c fade append 	"$FILE" "$FNAME.fade.mp4"
	$PROG -c black append 	"$FILE" "$FNAME.black.mp4"
	$PROG -c white append 	"$FILE" "$FNAME.white.mp4"
	$PROG -g "$OUTDIR/alex_portrait.jpg" -s background scale 	"$FILE" "$FNAME.bg.mp4"
done
