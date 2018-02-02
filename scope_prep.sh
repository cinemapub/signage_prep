#!/bin/bash
# first set some execution parameters
prefix_fmt=""
# uncomment next line to have date/time prefix for every output line
#prefix_fmt='+%Y-%m-%d %H:%M:%S :: '

runasroot=0
# runasroot = 0 :: don't check anything
# runasroot = 1 :: script MUST run as root
# runasroot = -1 :: script MAY NOT run as root

### Change the next lines to reflect which flags/options/parameters you need
### flag:   switch a flag 'on' / no extra parameter / e.g. "-v" for verbose
# flag|<short>|<long>|<description>|<default>

### option: set an option value / 1 extra parameter / e.g. "-l error.log" for logging to file
# option|<short>|<long>|<description>|<default>

### param:  comes after the options
#param|<type>|<long>|<description>
# where <type> = 1 for single parameters or <type> = n for (last) parameter that can be a list
[[ -z "$TEMP" ]] && TEMP=/tmp

list_options() {
echo -n "
flag|m|mute|remove audio from video
flag|q|quiet|no output
flag|v|verbose|output more
flag|n|nocrop|don't autodetect crop
flag|d|debug|add debug features (screenshot)
option|b|bps|output video bitrate|80M
option|g|bg|background image|empty.jpg
option|l|logdir|folder for log files|$TEMP/signage_prep
option|r|rat|output video framerate|24
option|s|scale|scale method: box/stretch/blur/ambi/full/auto|auto
option|t|tmpdir|folder for temp files|$TEMP/signage_prep
option|w|wxh|output dimensions|2048x858
option|x|cont|container dimensions|2048x1080
param|1|action|what to do: SCALE/ANALYZE
param|1|input|input file name
param|1|output|output file name
"
}

# change program version to your own release logic
readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(cd $(dirname $0); pwd)
readonly PROGVERS="v1.0"
readonly PROGAUTH="p.forret@brightfish.be"

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

PROGDATE=$(stat -c %y "$PROGDIR/$PROGNAME" 2>/dev/null | cut -c1-16) # generic linux
if [[ -z $PROGDATE ]] ; then
  PROGDATE=$(stat -f "%Sm" "$PROGDIR/$PROGNAME" 2>/dev/null) # for MacOS
fi

readonly ARGS="$@"
#set -e                                  # Exit immediately on error
verbose=0
quiet=0
piped=0
[[ -t 1 ]] && piped=0 || piped=1        # detect if out put is piped

# Defaults
args=()

out() {
  ((quiet)) && return
  local message="$@"
  local prefix=""
  if [[ -n $prefix_fmt ]]; then
    prefix=$(date "$prefix_fmt")
  fi
  if ((piped)); then
    message=$(echo $message | sed '
      s/\\[0-9]\{3\}\[[0-9]\(;[0-9]\{2\}\)\?m//g;
      s/✖/ERROR:/g;
      s/➨/ALERT:/g;
      s/✔/OK   :/g;
    ')
    printf '%b\n' "$prefix$message";
  else
    printf '%b\n' "$prefix$message";
  fi
}
progress() {
  ((quiet)) && return
  local message="$@"
  if ((piped)); then
    printf '%b\n' "$message";
    # \r makes no sense in file or pipe
  else
    printf '%b\r' "$message                                             ";
    # next line will overwrite this line
  fi
}
rollback()  { die ; }
trap rollback INT TERM EXIT
safe_exit() { trap - INT TERM EXIT ; exit ; }

die()     { out " \033[1;41m✖\033[0m: $@" >&2; safe_exit; }             # die with error message
alert()   { out " \033[1;31m➨\033[0m  $@" >&2 ; }                       # print error and continue
success() { out " \033[1;32m✔\033[0m  $@"; }
log()     { [[ $verbose -gt 0 ]] && out "\033[1;33m# $@\033[0m";}
notify()  { [[ $? == 0 ]] && success "$@" || alert "$@"; }
escape()  { echo $@ | sed 's/\//\\\//g'; }         # escape / as \/

is_set()     { local target=$1 ; [[ $target -gt 0 ]] ; }
is_empty()     { local target=$1 ; [[ -z $target ]] ; }
is_not_empty() { local target=$1;  [[ -n $target ]] ; }

is_file() { local target=$1; [[ -f $target ]] ; }
is_dir()  { local target=$1; [[ -d $target ]] ; }


usage() {
out "### Program: \033[1;32m$PROGNAME\033[0m by $PROGAUTH"
out "### Version: $PROGVERS - $PROGDATE"
echo -n "### Usage: $PROGNAME"
 list_options \
| awk '
BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="### Flags, options and parameters:"}
$1 ~ /flag/  {
  fulltext = fulltext sprintf("\n    -%1s|--%-10s: [flag] %s [default: off]",$2,$3,$4) ;
  oneline  = oneline " [-" $2 "]"
  }
$1 ~ /option/  {
  fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [optn] %s",$2,$3,"val",$4) ;
  if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
  oneline  = oneline " [-" $2 " <" $3 ">]"
  }
$1 ~ /secret/  {
  fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secr] %s",$2,$3,"val",$4) ;
    oneline  = oneline " [-" $2 " <" $3 ">]"
  }
$1 ~ /param/ {
  if($2 == "1"){
        fulltext = fulltext sprintf("\n    %-10s: [parameter] %s","<"$3">",$4);
        oneline  = oneline " <" $3 ">"
   } else {
        fulltext = fulltext sprintf("\n    %-10s: [parameter] %s (1 or more)","<"$3">",$4);
        oneline  = oneline " <" $3 "> [<...>]"
   }
  }
  END {print oneline; print fulltext}
'
}

init_options() {
    init_command=$(list_options \
    | awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3"=0; "}
    $1 ~ /flag/   && $5 != "" {print $3"="$5"; "}
    $1 ~ /option/ && $5 == "" {print $3"=\" \"; "}
    $1 ~ /option/ && $5 != "" {print $3"="$5"; "}
    ')
    if [[ -n "$init_command" ]] ; then
        #log "init_options: $(echo "$init_command" | wc -l) options/flags initialised"
        eval "$init_command"
   fi
}

parse_options() {
    if [[ $# -eq 0 ]] ; then
       usage >&2 ; safe_exit
    fi

    ## first process all the -x --xxxx flags and options
    while [[ $1 = -?* ]]; do
        # flag <flag> is savec as $flag = 0/1
        # option <option> is saved as $option
       save_option=$(list_options \
        | awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        ')
        if [[ -n "$save_option" ]] ; then
            #log "parse_options: $save_option"
            eval $save_option
        else
            die "$PROGNAME cannot interpret option [$1]"
        fi
        shift
    done

    ## then run through the given parameters
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    nb_singles=$(echo $single_params | wc -w)
    [[ $nb_singles -gt 0 ]] && [[ $# -eq 0 ]] && die "$PROGNAME needs the parameter(s) [$(echo $single_params)]"

    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    nb_multis=$(echo $multi_param | wc -w)
    if [[ $nb_multis -gt 1 ]] ; then
        die "$PROGNAME cannot have more than 1 'multi' parameter: [$(echo $multi_param)]"
    fi

    for param in $single_params ; do
        if [[ -z "$1" ]] ; then
            die "$PROGNAME needs parameter [$param]"
        fi
        out $(printf "[%s] = %s" "$param" "$1")
        eval $param="$1"
        shift
    done

    [[ $nb_multis -gt 0 ]] && [[ $# -eq 0 ]] && die "$PROGNAME needs the (multi) parameter [$multi_param]"
    [[ $nb_multis -eq 0 ]] && [[ $# -gt 0 ]] && die "$PROGNAME cannot interpret extra parameters"

    # save the rest of the params in the multi param
	if [ -s "$*" ] ; then
		eval "$multi_param=( $* )"
	fi
}

[[ $runasroot == 1  ]] && [[ $UID -ne 0 ]] && die "You MUST be root to run this script"
[[ $runasroot == -1 ]] && [[ $UID -eq 0 ]] && die "You MAY NOT be root to run this script"

################### DO NOT MODIFY ABOVE THIS LINE ###################
#####################################################################

## Put your script here

showinfo_video(){
  bname=$(basename "$1")
  width=$(get_ffprobe "$1" "width")
  height=$(get_ffprobe "$1" "height")
  pix_fmt=$(get_ffprobe "$1" "pix_fmt")
  codec=$(get_ffprobe "$1" "codec_name")
  duration=$(get_ffprobe "$1" "duration" | awk '{printf "%.2f", $1}')
  nbframes=$(get_ffprobe "$1" "nb_frames")
  framerate=$(get_ffprobe "$1" "avg_frame_rate")
  #framerate=$(echo "scale=2; $framerate" | bc)
  framerate=$(echo $framerate | awk '{printf "%.2f", $1}')
  filesize=$(du -b "$1" | awk '{print $1}')
  kbsize=$(expr $filesize / 1000)
  #bitrate=$(echo $filesize \* 8 / \( $duration \* 1000000 \) | bc)
  bitrate=$(echo $filesize \* 8 / \( $duration \* 1000000 \) | bc)
  out "# $bname - $kbsize KB @ $bitrate Mbps"
  out "# $width x $height - $duration sec ($nbframes frames @ $framerate fps) - $codec ($pix_fmt)"
}

showinfo_audio(){
  bname=$(basename "$1")
  codec=$(get_ffprobe "$1" "codec_name")
  duration=$(get_ffprobe "$1" "duration" | awk '{printf "%.2f", $1}')
  filesize=$(du -b "$1" | awk '{print $1}')
  kbsize=$(expr $filesize / 1000)
  #bitrate=$(echo $filesize \* 8 / \( $duration \* 1000000 \) | bc)
  bitrate=$(echo $filesize \* 8 / \( $duration \* 1000000 \) | bc)
  out "# $bname - $kbsize KB @ $bitrate Mbps - $duration sec - $codec"
}

showinfo_image(){
  bname=$(basename "$1")
  out "Image: [$bname]"
  width=$(get_ffprobe "$1" "width")
  height=$(get_ffprobe "$1" "height")
  out "     | $width x $height (WxH)"
  filesize=$(du -b "$1" | awk '{print $1}')
  kbsize=$(expr $filesize / 1000)
  out "     | $kbsize KB"
  compression=$(echo $filesize \* 100 / \($width \* $height \* 3 \) | bc)
  out "     | Compressed $compression %"
}

get_ffprobe() {
  # $1 = file
  # $2 = parameters
  # reads lines like 'width=1080' and gives back 1080
  uniq=$(echo "$1" | md5sum | cut -c1-6)
  tmp_probe=$tmpdir/$(basename "$1" | cut -c1-10).$uniq.probe.txt
  if [ ! -s "$tmp_probe" -o "$1" -nt "$tmp_probe" ] ; then
    # only first time
    log "get_ffprobe:  use [$tmp_probe]" >&2
    ffprobe -show_streams "$1" 2> /dev/null | grep -v "0/0" > $tmp_probe 
  fi
  grep "$2=" "$tmp_probe" | cut -d= -f2- | head -1
}

if [[ -z "$FFMPEG" ]] ; then
  if [[ ! -z $(which ffmpeg) ]] ; then
    FFMPEG=$(which ffmpeg)
  else
    die "No FFMPEG installed (using 'which ffmpeg')"
  fi
fi
  
detect_crop_image() {
  # $1 = file
  # cropdetect round should be 8 because 1080 is not a multiple of 16
  log "detect_crop_image: using first 5 seconds" >&2
  log "detect_crop_image: $FFMPEG -i $1 -t 5 -vf cropdetect=70:8 -f null -" >&2
  $FFMPEG -i "$1" -t 5 -vf cropdetect=70:8 -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1
}

run_ffmpeg(){
  uniq=$(echo "$*" | md5sum | cut -c1-6)
  lastfile=$(echo "$*" | awk '{print $NF}' )
  lname=$(basename $lastfile)
  logfile="$logdir/ff.$lname.$uniq.log"
  log "logfile = [$logfile]"

  log "command = [$FFMPEG $@]"
  echo "COMMAND = [$FFMPEG $@]" > $logfile
  echo "-------" >> $logfile
  $FFMPEG "$@" 2>> $logfile
  if [ $? -ne 0  ] ; then
    die "Command failed - check [$logfile]"
  fi
}


main() {
  if [ ! -d $tmpdir ] ; then
    log "Create tmp folder [$tmpdir]"
    mkdir "$tmpdir"
  else
    log "cleanup tmp folder [$tmpdir]"
    find "$tmpdir" -mtime +1 -exec rm {} \;
  fi
  if [ ! -d $logdir ] ; then
    log "Create log folder [$logdir]"
    mkdir "$logdir"
  else
    log "cleanup log folder [$logdir]"
    find "$logdir" -mtime +7 -exec rm {} \;
  fi

  log "Using ffmpeg: $FFMPEG"
  log $($FFMPEG -version | head -1)

  [[ ${wxh^^} == "SCOPE" ]] && wxh="2048x856"
  [[ ${wxh^^} == "FLAT" ]] && wxh="2048x1080"
  wout=$(echo $wxh | cut -dx -f1)
  hout=$(echo $wxh | cut -dx -f2)
  log "Output dimensions   : [$wxh] -> $wout x $hout"

  wcont=$(echo $cont | cut -dx -f1)
  hcont=$(echo $cont | cut -dx -f2)
  log "Container dimensions: [$cont] -> $wcont x $hcont"

  mediatype=""
  [[ "$wxh" == "2048x858" ]] && mediatype="scope"
  [[ "$wxh" == "2048x1080" ]] && mediatype="flat"
  [[ "$wxh" == "1920x1080" ]] && mediatype="flat"
  log "Mediatype: [$mediatype]"
  win=$(get_ffprobe "$input" "width")
  hin=$(get_ffprobe "$input" "height")
  ffcrop=$(detect_crop_image "$input")
  crops=${ffcrop#*=}
  cnums=(${crops//:/ })
  wreal=${cnums[@]:0:1}
  hreal=${cnums[@]:1:1}
  areal=$(expr $wreal \* 100 / $hreal) # eg 178, 190, 235
  aout=$(expr $wout \* 100 / $hout)
  log "Input container: $win x $hin"
  log "Input image    : $wreal x $hreal ($areal)"
  log "Output image   : $wout x $hout ($aout)"
  method=test
  cropok=4
  if [[ $aout -le 200 ]] ; then
    # convert to flat
    if [[ $areal -le $(expr $aout - $cropok - $cropok - $cropok - $cropok) ]] ; then
      # ex: 1.50 -> 1.90
      method="AMBI"
    elif [[ $areal -le $(expr $aout - $cropok) ]] ; then
      # ex: 1.78 -> 1.90
      method="CROP"
    elif [[ $areal -le $(expr $aout + $cropok) ]] ; then
      # ex: 1.92 -> 1.90
      method="CROP"
    else
      # ex: 2.35 -> 1.90
      method="BOX"
    fi 
  else
    # convert to scope
    if [[ $areal -le $(expr $aout - $cropok) ]] ; then
      # ex: 1.78 -> 2.35
      method="AMBI"
    elif [[ $areal -le $(expr $aout + $cropok) ]] ; then
      # ex: 2.37 -> 2.35
      method="CROP"
    else
      # ex: 2.40 -> 2.35
      method="BOX"
    fi 
  fi
  case ${action^^} in
    ANALYZE)
      echo "-w ${wout}x${hout} -x ${wcont}x${hcont} -s $method SCALE"
    ;;
    SCALE)
		  showinfo_video $input
      scale=${scale^^}
      if [[ "$scale" == "AUTO" ]] ;  then
        scale=$method
      fi
      fffont="fontfile=font/bahnschrift.ttf:fontsize=20:fontcolor=white"
	    width=$(get_ffprobe "$input" "width")
	    height=$(get_ffprobe "$input" "height")
      log "Input container: $width x $height"
	    pix_fmt=$(get_ffprobe "$input" "pix_fmt")
      log "Input format: $pix_fmt"
      duration=$(get_ffprobe "$input" "duration" | awk '{printf "%.2f", $1}' )
	    bname=$(basename "$input")
      log "Input filename: $bname"
      # first default seeting without crop detection
      wreal=$width
      hreal=$height
      realaspect=$(echo "$wreal $hreal" | awk '{printf "%.2f", $1/$2}')
      if (($debug)) ; then
        ffcrop="drawtext=$fffont:text='InitialImage=${wreal}x${hreal}($realaspect)':x=(w-text_w)/2:y=(h-text_h)/2"
      else
        ffcrop="copy"
      fi

      ## 
      ## TODO: interlacing detection
      # ffmpeg -i <input> -frames:v 300 -filter:v idet -an -f rawvideo -y /dev/null 2>&1 | grep Parsed


      ## ----------------- PERFORM CROP DETECTION TO GUESS REAL IMAGE DIMENSIONS
      if [[ $nocrop -eq 0 ]] ; then
        # do crop detection
        cropdetect=$(detect_crop_image "$input")
        log "Crop detection: $cropdetect"
        if [[ ! -z "$ffcrop" ]] ; then
          # e.g. crop=1920:816:0:132
          crops=${cropdetect#*=}
          cnums=(${crops//:/ })
          wreal=${cnums[@]:0:1}
          hreal=${cnums[@]:1:1}
          if [[ "$wreal|$hreal" -ne "$width|$height" ]] ; then
            realaspect=$(echo "$wreal $hreal" | awk '{printf "%.2f", $1/$2}')
            out "# Crop detection: $wreal x $hreal ($realaspect)"
            if (($debug)) ; then
              ffcrop="$ffcrop,drawtext=$fffont:text='InitialCrop=${wreal}x${hreal}($realaspect)':x=(w-text_w)/2:y=(h-text_h)/2"
            fi
          fi
        fi
      fi 
      out "# Convert [${scale}] : ${wreal}x${hreal} -> ${wout}x${hout}"

      fformat="-r $rat -b:v $bps -an -metadata artist=SpottixDCP -metadata comment=input:${wreal}x${hreal};output:${wout}x${hout};container:${wcont}x${hcont};method:$scale"
      if [[ -n "$mediatype" ]] ; then
        fformat="$fformat -metadata network=$mediatype"
      fi
      log "FFMPEG OUTPUT FORMAT = [$fformat]"

      ## ----------------- DECIDE ON AUDIO AND VIDEO CONFORM
      fps=$(get_ffprobe "$input" "avg_frame_rate")
      fps=${fps%/1} # clean up "25/1" fps
      fps=$(echo $fps | awk '{printf "%.2f", $1}')
      log "Input FPS: $fps fps"

      if [[ "$fps" == "24.00" ]] ;  then
        # already correct framerate
        ffaudio="-acodec pcm_s24le -ar 48000"
      elif [[ "$fps" == "25.00" ]] ;  then
        # use conform: slowdown 
        # via https://toolstud.io/video/framerate.php
        # ffmpeg -i [input] -r 24 -filter:v "setpts=1.0417*PTS" -y [output]
        # ffmpeg -i [input] -filter:a "atempo=0.96" -vn [output]
        log "Input FPS = $fps => conform to 24"
        ffaudio="-acodec pcm_s24le -ar 48000 -filter:a atempo=0.96"
        ffcrop="$ffcrop,setpts=1.0417*PTS"
      else
        ## use standard: interpolation
        ffaudio="-acodec pcm_s24le -ar 48000"
      fi


      ## ----------------- DECIDE ON IMAGE SIZES AND RESIZING
      if (($debug)) ; then
        if [[ $wxh == $cont ]] ; then
          ffcont="setdar=dar=1.896,drawtext=$fffont:text='Container-${wcont}x${hcont}':x=(w-text_w)/2:y=10"
        else
          ffcont="pad=$wcont:$hcont:($wcont-iw)/2:($hcont-ih)/2,setdar=dar=1.896,drawtext=$fffont:text='Container=${wcont}x${hcont}':x=(w-text_w)/2:y=10"
        fi 
        ffscale="scale=w=$wout:h=$hout,drawtext=$fffont:text='Stretch-${wout}x${hout}':x=25:y=25"
        wnew=$(expr $wreal \* $hout / $hreal / 4 \* 4)
        if [[ $wnew -gt $wout ]] ; then
          wdown=$wout
          hdown=$(expr $wout  \* $hreal / $wreal / 4 \* 4)
          wup=$wnew
          hup=$(expr $wnew  \* $hreal / $wreal / 4 \* 4)
        else
          wdown=$wnew
          hdown=$(expr $wnew  \* $hreal / $wreal / 4 \* 4)
          wup=$wout
          hup=$(expr $wout  \* $hreal / $wreal / 4 \* 4)
        fi
        log "Scale Down: $wreal x $hreal -> $wdown x $hdown"
        log "Scale Up  : $wreal x $hreal -> $wup x $hup"
        ffscaledn="scale=w=$wout:h=$hout:force_original_aspect_ratio=decrease,drawtext=$fffont:text='Scale=${wdown}x${hdown}':x=25:y=25"
        ffscaleup="scale=w=$wout:h=$hout:force_original_aspect_ratio=increase,drawtext=$fffont:text='ScaleAndCrop=${wup}x${hup}':x=100:y=100"
      else
        if [[ $wxh == $cont ]] ; then
          ffcont="setdar=dar=1.896"
        else 
          ffcont="pad=$wcont:$hcont:($wcont-iw)/2:($hcont-ih)/2,setdar=dar=1.896"
        fi
        ffscale="scale=w=$wout:h=$hout"
        ffscaledn="scale=w=$wout:h=$hout:force_original_aspect_ratio=decrease"
        ffscaleup="scale=w=$wout:h=$hout:force_original_aspect_ratio=increase"
      fi

      t1=$(date +%s)

      ## ----------------- FIRST CONVERT AUDIO
      achannels=$(get_ffprobe "$input" "channel_layout")
      if [[ -n "$achannels" ]]; then
        dirout=$(dirname "$output")
        bnout=$(basename "$output")
        wavout="$dirout/${bnout%.*}.wav"
        log "AUDIO OUTPUT = $wavout"
        run_ffmpeg -i "$input" $ffaudio -y "$wavout"
        showinfo_audio "$wavout"
      fi


      ## ----------------- NOW CONVERT VIDEO / IMAGES
      case ${scale} in
        BOX)
          log "SCALE with method [${scale}]"
	      	run_ffmpeg -i "$input" -vf "${ffcrop},${ffscaledn},pad=$wout:$hout:($wout-iw)/2:($hout-ih)/2,${ffcont}" \
            $fformat -pix_fmt $pix_fmt -y "$output"
          ;;

        STRETCH)
          log "SCALE with method [${scale}]"
          run_ffmpeg -i "$input" -vf "${ffcrop},${ffscale},${ffcont}" \
            $fformat -y "$output"
          ;;

        CROP)
          log "SCALE with method [${scale}]"
          if ((debug)) ; then
            run_ffmpeg -i "$input" -vf "${ffcrop},${ffscaleup},crop=w=$wout:h=$hout,drawtext=$fffont:text='Crop=${wout}x${hout}',${ffcont}" \
              $fformat -y "$output"
          else
            run_ffmpeg -i "$input" -vf "${ffcrop},${ffscaleup},crop=w=$wout:h=$hout,${ffcont}" \
              $fformat -y "$output"
          fi

          ;;

        AMBI|BLUR)
          log "SCALE with method [${scale}]"

          tmp_bg=$tmpdir/$(basename "$input" | cut -c1-10).bg.mp4
          # first create background video on output resolution
          if [[ ${scale^^} == AMBI ]] ; then
            ffblur="hue=b=-1:s=2,boxblur=50:10"
          else
            ffblur="boxblur=10:10"
          fi
          if ((debug)) ; then
            run_ffmpeg -i "$input" -vf "${ffcrop},${ffscale},$ffblur,drawtext=$fffont:text='${scale^^}=${wout}x${hout}'"  $fformat -y $tmp_bg
          else
            run_ffmpeg -i "$input" -vf "${ffcrop},${ffscale},$ffblur" $fformat -y $tmp_bg
          fi 

          run_ffmpeg -i "$tmp_bg" -i "$input" \
            -filter_complex "[1:v]${ffcrop},${ffscaledn}[front];[0:v][front]overlay=(W-w)/2:(H-h)/2,${ffcont}" \
            $fformat -y "$output"
          ;;

        AMBIFULL|FULL)
          log "SCALE with method [ambifull]"

          tmp_bg=$tmpdir/$(basename "$input" | cut -c1-10).bg.mp4
          # first create background video on output resolution
          if ((debug)) ; then
            run_ffmpeg -i "$input" -vf "${ffcrop},scale=${wcont}x${hcont},hue=b=-1:s=2,boxblur=50:10,drawtext=$fffont:text='Blur=${wcont}x${hcont}'" $fformat -y $tmp_bg
          else
            run_ffmpeg -i "$input" -vf "${ffcrop},scale=${wcont}x${hcont},hue=b=-1:s=2,boxblur=50:10" $fformat -y $tmp_bg
          fi


          run_ffmpeg -i "$tmp_bg" -i "$input" \
            -filter_complex "[1:v]${ffcrop},${ffscaledn}[front];[0:v][front]overlay=(W-w)/2:(H-h)/2,${ffcont}" \
            $fformat -y "$output"
          ;;

        BACKGROUND|BACK)
          log "SCALE with method [background]"

          tmp_bg=$tmpdir/$(basename "$input" | cut -c1-10).bg.mp4
          # first create background video on output resolution
          run_ffmpeg -i "$input" -vf "${ffcrop},${ffscale}"  $fformat -y $tmp_bg

          run_ffmpeg -i "$tmp_bg" -i "$input" \
            -filter_complex "[1:v]${ffcrop},${ffscaledn}[front];[0:v][front]overlay=(W-w)/2:(H-h)/2,${ffcont}" \
            $fformat -y "$output"
          ;;

        IMAGE)
          # create background with stretch
          log "SCALE with method [image] (background)"
          if [ ! -f "$bg" ] ; then
            die "Cannot find background picture [$bg]"
          fi
          tmp_bg=$tmpdir/$(basename "$input" | cut -c1-10).bg.png
          # first create background image on output resolution
          run_ffmpeg -i "$bg" -vf "scale=w=$wout:h=$hout" $fformat -y "$tmp_bg"
          # now overlay
          duration=$(get_ffprobe "$input" "duration" | awk '{printf "%.2f", $1}')
          run_ffmpeg -loop 1 -i "$tmp_bg" -i "$input" \
            -filter_complex "[1:v] ${ffcrop},${ffscaledn}[pip];[0:v][pip] overlay=0:(H-h)/2,${ffcont}" \
            -t $duration $fformat -y "$output"
          ;;

        *)
        die "Cannot scale with method [$scale]"
      esac

      # calculate throughput
      t2=$(date +%s)
      dt=$(expr $t2 - $t1)
      mb=$(du -m "$output" | awk '{print $1}')
      mbps=$(echo "$mb $dt" | awk '{printf "%.2f", $1 / $2}')
      relative=$(echo "$duration  $dt" | awk '{printf "%.1f", $1 * 100 / $2}')
      out "Convert [${scale^^}] : $dt seconds ($mbps MB/s - $relative % of real-time speed)"

      showinfo_video $output 

      if (($debug)) ; then
        # also generate screen shot
        outdir=$(dirname "$output")
        [[ -z "$outdir" ]] && outdir="."
        bout=$(basename "$output")
        broot=${bout%.*}
        outdur=$(get_ffprobe "$output" "duration" | awk '{printf "%.0f", $1}')
        halfdur=$(expr $outdur / 2)
        shot="$outdir/$broot.${realaspect}.jpg"
        run_ffmpeg -ss $halfdur -i "$output" -vframes 1 -q:v 3 -y "$shot"
      fi
      out "----------"
	    ;;

	*)
      die "Action [$action] not recognized" 
  esac
}

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

init_options
parse_options $@
main
safe_exit
