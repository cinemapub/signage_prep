# signage_prep
Simple bash tools to: rescale/letterbox videos &amp; images, add fadeout/pause after videos

## image_prep.sh
	
### Usage

	Program: image_prep.sh by p.forret@brightfish.be
	Version: v1.0 - 2017-11-30 13:57
	Usage: image_prep.sh [-q] [-v] [-f] [-m] [-s <scale>] [-b <blur>] [-c <col>] <action> <input> <output>
	Flags, options and parameters:
	    -f|--force     : [flag] do not ask for confirmation [default: off]
	    -m|--mute      : [flag] remove sound [default: off]
	    -q|--quiet     : [flag] no output [default: off]
	    -v|--verbose   : [flag] output more [default: off]
	    -b|--blur <val>: [optn] blur strength  [default: 10]
	    -c|--col <val> : [optn] color to add  [default: black]
	    -s|--scale <val>: [optn] scale method: box/stretch/blur  [default: box]
	    <action : [parameter] what to do: SCALE
	    <input  : [parameter] input image filename
	    <output : [parameter] output image filename

## video_prep.sh

### Usage 

	Program: video_prep.sh by p.forret@brightfish.be
	Version: v1.0 - 2017-11-30 14:55
	Usage: video_prep.sh [-f] [-m] [-q] [-v] [-b <bps>] [-c <col>] [-d <dur>] [-g <bg>] [-h <hout>] [-r <rat>] [-s <scale>] [-w <wout>] <action> <input> <output>
	Flags, options and parameters:
	    -f|--force     : [flag] do not ask for confirmation [default: off]
	    -m|--mute      : [flag] remove sound [default: off]
	    -q|--quiet     : [flag] no output [default: off]
	    -v|--verbose   : [flag] output more [default: off]
	    -b|--bps <val> : [optn] output video bitrate  [default: 6M]
	    -c|--col <val> : [optn] color to add  [default: black]
	    -d|--dur <val> : [optn] add duration in seconds  [default: 1]
	    -g|--bg <val>  : [optn] background image  [default: empty.jpg]
	    -r|--rat <val> : [optn] output video framerate  [default: 25]
	    -s|--scale <val>: [optn] scale method: box/stretch/blur  [default: box]
	    -w|--wout <val>: [optn] output video width  [default: 1080]
	    -h|--hout <val>: [optn] output video height  [default: 1920]
	    <action>  : [parameter] what to do: APPEND/PREPEND/SCALE/BACKGROUND/EXTRACT
	    <input>   : [parameter] input file name
	    <output>  : [parameter] output file name
