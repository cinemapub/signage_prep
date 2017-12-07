#!/bin/bash
readonly PROGDIR=$(cd $(dirname $0); cd .. ; pwd)
PROG="$PROGDIR/image_prep.sh -q"
SRCDIR=$PROGDIR/samples
OUTDIR=$PROGDIR/.test

if [ ! -d $OUTDIR ] ; then
	mkdir $OUTDIR
else
	rm $OUTDIR/*
fi

FILENO=0
for FILE in $SRCDIR/*.jpg ; do
	FILENO=$(expr $FILENO + 1)
	BNAME=$(basename $FILE | cut -c1-6)
	FNAME="$OUTDIR/$BNAME.$FILENO"
	echo "### $FILE -- $BNAME ###"

	$PROG -s blur -b 0 scale 	"$FILE" "$FNAME.blur0.jpg"
	$PROG -s blur -b 10 scale 	"$FILE" "$FNAME.blur10.jpg"
	$PROG -s blur -b 20 scale 	"$FILE" "$FNAME.blur20.jpg"
	$PROG -s blur -b -20 scale 	"$FILE" "$FNAME.blur-20.jpg"
	$PROG -s box scale 			"$FILE" "$FNAME.vhdbox.jpg"
	$PROG -s stretch scale		"$FILE" "$FNAME.stretch.jpg"
	$PROG -w 1920x1080 scale	"$FILE" "$FNAME.hdbox.jpg"
	$PROG -w 1920x1080 -s blur -b 10  scale	"$FILE" "$FNAME.hdblur10.jpg"
	$PROG -w 1920x1080 -s blur -b -10 scale	"$FILE" "$FNAME.hdblur-10.jpg"
	$PROG -w 1000x1200 -c white scale "$FILE"  "$FNAME.white.jpg"
done
