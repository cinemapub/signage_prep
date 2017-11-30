# signage_prep
Simple bash tools to: rescale/letterbox videos &amp; images, add fadeout/pause after videos

## image_prep.sh
	
### Usage

	Program: image_prep.sh by p.forret@brightfish.be
	Version: v1.0 - 2017-11-30 13:57
	Usage: image_prep.sh [-q] [-v] [-s <scale>] [-b <blur>] [-c <col>] <action> <input> <output>
	Flags, options and parameters:
	    -q|--quiet     : [flag] no output [default: off]
	    -v|--verbose   : [flag] output more [default: off]
	    -b|--blur <val>: [optn] blur strength  [default: 10]
	    -c|--col <val> : [optn] color to add  [default: black]
	    -s|--scale <val>: [optn] scale method: box/stretch/blur  [default: box]
	    <action : [parameter] what to do: SCALE
	    <input  : [parameter] input image filename
	    <output : [parameter] output image filename

### Examples

* `image_prep.sh -s blur -b 20 SCALE [input] [output]`

## video_prep.sh

### Usage 

	Program: video_prep.sh by p.forret@brightfish.be
	Version: v1.0 - 2017-11-30 14:55
	Usage: video_prep.sh [-m] [-q] [-v] [-b <bps>] [-c <col>] [-d <dur>] [-g <bg>] [-h <hout>] [-r <rat>] [-s <scale>] [-w <wout>] <action> <input> <output>
	Flags, options and parameters:
	    -m|--mute      : [flag] remove sound [default: off]
	    -q|--quiet     : [flag] no output [default: off]
	    -v|--verbose   : [flag] output more [default: off]
	    -b|--bps <val> : [optn] output video bitrate  [default: 6M]
	    -c|--col <val> : [optn] color/last/fade to use for append [default: black]
	    -d|--dur <val> : [optn] add duration in seconds  [default: 1]
	    -g|--bg <val>  : [optn] background image  [default: empty.jpg]
	    -r|--rat <val> : [optn] output video framerate  [default: 25]
	    -s|--scale <val>: [optn] scale method: box/stretch/blur  [default: box]
	    -w|--wout <val>: [optn] output video width  [default: 1080]
	    -h|--hout <val>: [optn] output video height  [default: 1920]
	    <action>  : [parameter] what to do: APPEND/PREPEND/SCALE/BACKGROUND/EXTRACT
	    <input>   : [parameter] input file name
	    <output>  : [parameter] output file name

### Examples

* `video_prep.sh -m -c fade -d 7 -b 10M  APPEND [input] [output]`


## Sample images and video

* `camera_square.jpg`: [Photo by Alexander Andrews on Unsplash](https://unsplash.com/photos/sNPfZxrBYdQ "Photo by Alexander Andrews on Unsplash")
* `dog_landscape.jpg`: [Photo by Aaron Barnaby on Unsplash](https://unsplash.com/photos/dp2m5glF2Y4 "Photo by Aaron Barnaby on Unsplash")
* `alex_portrait.jpg`: [Photo by Alex Iby on Unsplash](https://unsplash.com/photos/470eBDOc8bk "Photo by Alex Iby on Unsplash")
* `fashion_divx.mov, bunny_divx.mp4`: [DivX Sample videos](http://www.divx.com/en/devices/profiles/video)
* `lights.mp4`: [Videezy free video](https://www.videezy.com/backgrounds/5064-distant-lights-4k-motion-background-loop)
