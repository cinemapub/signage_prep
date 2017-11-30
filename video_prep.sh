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
list_options() {
echo -n "
flag|f|force|do not ask for confirmation
flag|m|mute|remove sound
flag|q|quiet|no output
flag|v|verbose|output more
option|b|bps|output video bitrate|6M
option|c|col|color to add|black
option|d|dur|add duration in seconds|1
option|g|bg|background image|empty.jpg
option|h|hout|output video height|1920
option|r|rat|output video framerate|25
option|s|scale|scale method: box/stretch/blur|box
option|w|wout|output video width|1080
param|1|action|what to do: APPEND/PREPEND/BOX/BACKGROUND/EXTRACT
param|1|input|input file name
param|1|output|output file name
"
}

# change program version to your own release logic
readonly PROGVERS="v1.0"
readonly PROGAUTH="p.forret@brightfish.be"

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(cd $(dirname $0); pwd)
#readonly TMPDIR=$TMP/$(basename $0 .sh)
readonly TMPDIR=.tmp
PROGDATE=$(stat -c %y "$PROGDIR/$PROGNAME" 2>/dev/null | cut -c1-16) # generic linux
if [[ -z $PROGDATE ]] ; then
  PROGDATE=$(stat -f "%Sm" "$PROGDIR/$PROGNAME" 2>/dev/null) # for MacOS
fi
if [ ! -d $TMPDIR ] ; then
	# create cache dir
	mkdir $TMPDIR
else
	# clean up old files in cache dir
	find $TMPDIR -mtime +1 -exec rm {} \;
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
log()     { [[ $verbose -gt 0 ]] && out "$@";}
notify()  { [[ $? == 0 ]] && success "$@" || alert "$@"; }
escape()  { echo $@ | sed 's/\//\\\//g'; }         # escape / as \/

confirm() { (($force)) && return 0; read -p "$1 [y/N] " -n 1; echo " "; [[ $REPLY =~ ^[Yy]$ ]];}

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
  out "Video: [$bname]"
  width=$(get_ffprobe "$1" "width")
  height=$(get_ffprobe "$1" "height")
  out "     | $width x $height (WxH)"
  pix_fmt=$(get_ffprobe "$1" "pix_fmt")
  vid_cod=$(get_ffprobe "$1" "codec_name")
  out "     | $vid_cod ($pix_fmt)"
  duration=$(get_ffprobe "$1" "duration" | awk '{printf "%.2f", $1}')
  nbframes=$(get_ffprobe "$1" "nb_frames")
  framerate=$(get_ffprobe "$1" "avg_frame_rate")
  framerate=$(echo $framerate | sed 's#/1##g')
  out "     | $duration sec ($nbframes frames @ $framerate fps)"
  filesize=$(stat -c%s "$1")
  kbsize=$(expr $filesize / 1000)
  out "     | $kbsize KB"
  bitrate=$(echo $filesize \* 8 / \( $duration \* 1000 \) | bc)
  out "     | $bitrate Kbps"
}

showinfo_image(){
  bname=$(basename "$1")
  out "Image: [$bname]"
  width=$(get_ffprobe "$1" "width")
  height=$(get_ffprobe "$1" "height")
  out "     | $width x $height (WxH)"
  filesize=$(stat -c%s "$1")
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
		tmp_probe=$TMPDIR/$(basename $1 | cut -c1-10).$uniq.probe.txt
		if [ ! -s "$tmp_probe" -o "$1" -nt "$tmp_probe" ] ; then
			# only first time
			ffprobe -show_streams "$1" > $tmp_probe 2>/dev/null
		fi
		grep "$2=" "$tmp_probe" | cut -d= -f2- | head -1
}

run_ffmpeg(){
  uniq=$(echo "$*" | md5sum | cut -c1-6)
  lastfile=$(echo "$*" | awk '{print $NF}' )
  lname=$(basename $lastfile)
  logfile="log/ff.$lname.$uniq.log"
  log "logfile = [$logfile]"
  if [ -f "/c/tools/ffmpeg64/ffmpeg.exe" ] ; then
    FFMPEG=/c/tools/ffmpeg64/ffmpeg.exe
  elif [ -f "/mnt/c/tools/ffmpeg.exe" ] ; then
    FFMPEG=/mnt/c/tools/ffmpeg.exe
  else
    FFMPEG=ffmpeg
  fi

  log "command = [$FFMPEG $@]"
  echo "COMMAND = [$FFMPEG $@]" > $logfile
  echo "-------" >> $logfile
  $FFMPEG "$@" 2>> $logfile
  if [ $? -ne 0  ] ; then
    die "Command failed - check [$logfile]"
  fi
}


main() {
  fformat="-r $rat -b:v $bps"
  if [ -n "$mute" ] ; then
    fformat="$fformat -an"
  fi

  log "FFMPEG OUTPUT FORMAT = [$fformat]"
  case $action in
    LOOP|loop )
		width=$(get_ffprobe "$input" "width")
		height=$(get_ffprobe "$input" "height")
    	showinfo_image "$input"
	    if [ $width -eq $wout -a $height -eq $hout ] ; then
	      log "> create [$output] (Vertical HD)"
	      run_ffmpeg -loop 1 -i "$input" $fformat -t $dur -pix_fmt yuv420p -y "$output"
	    else
	      log "> create [$output] (Scale to Vertical HD)"
	      run_ffmpeg -loop 1 -i "$input" -filter_complex "scale=w=$wout:h=$hout" $fformat -t $dur -pix_fmt yuv420p -y "$output"
	    fi
	    showinfo_video "$output"
		;;

    APPEND|append )
		width=$(get_ffprobe "$input" "width")
		height=$(get_ffprobe "$input" "height")
		out "Resolution: $width x $height"
		pix_fmt=$(get_ffprobe "$input" "pix_fmt")
		vid_cod=$(get_ffprobe "$input" "codec_name")
		out "Encoding  : $vid_cod ($pix_fmt)"
		duration=$(get_ffprobe "$input" "duration" | awk '{printf "%.2f", $1}')
		nbframes=$(get_ffprobe "$input" "nb_frames")
		framerate=$(get_ffprobe "$input" "avg_frame_rate")
		bname=$(basename "$input")
		out "Duration  : $duration sec ($nbframes frames @ $framerate fps)"
		case $col in 
		last|fade)
			# get last frame
			frm_last=$(get_ffprobe "$input" "nb_frames")
			frm_prev=$(expr $frm_last - 1)
			log_last=$TMPDIR/$bname.last.log
			png_last=$TMPDIR/$bname.last.png
			out "- grab last frame image ($frm_last)"
			run_ffmpeg -i "$input" -vf "select='eq(n,$frm_prev)'" -vframes 1 -y $png_last
			vid_last=$TMPDIR/$bname.last.mp4
			if [ "$col" == "fade" ] ; then
				out "- create fade outro ($dur sec)"
				fadframes=$(echo "$dur	$rat" | awk '{printf "%.0f" ,$1*$2}')
				run_ffmpeg -r $rat -loop 1 -i $png_last -c:v $vid_cod -t $dur -filter:v "fade=out:0:$fadframes" $fformat -y $vid_last
			else
				out "- create freeze outro ($dur sec)"
				run_ffmpeg -r $rat -loop 1 -i $png_last -c:v $vid_cod -t $dur -pix_fmt $pix_fmt -b:v $bps -y $vid_last
			fi
			out "- create $output ..."
			# ffmpeg -loop 1 -i img.jpg -c:v libx264 -t 30 -pix_fmt yuv420p out.mp4
			# via https://trac.ffmpeg.org/wiki/Slideshow
			
			# ffmpeg -i input1.mp4 -i input2.webm -filter_complex "[0:v:0] [0:a:0] [1:v:0] [1:a:0] concat=n=2:v=1:a=1 [v] [a]" -map "[v]" -map "[a]" <encoding options> output.mkv
			# via https://trac.ffmpeg.org/wiki/Concatenate
			run_ffmpeg -i "$input" -i "$vid_last" -filter_complex "[0:v:0] [1:v:0] concat=n=2:v=1:a=0 [v]" -map "[v]" $fformat -pix_fmt $pix_fmt -y "$output"
			# 
			;;
		*)
			# assume it's a color
			# ffmpeg -i XX.mxf -vf "color=c=black:s=1920x1080:d=10 [pre] ; color=c=black:s=1920x1080:d=30 [post] ; [pre] [in] [post] concat=n=3" –y output.mxf
			# via http://hondrouthoughts.blogspot.be/2016/08/ffmpeg-for-adding-black-colourbars-tone.html
			out "- create $output ..."
			run_ffmpeg -i "$input" -vf "color=c=${col}:s=${width}x${height}:d=${dur} [post] ; [in] [post] concat=n=2" $fformat -pix_fmt $pix_fmt -y "$output"
			;;
		esac
		newdur=$(get_ffprobe "$output" "duration" | awk '{printf "%.2f", $1}')
		out "New duration: $newdur sec"
		;;

    PREPEND|prepend )
		width=$(get_ffprobe "$input" "width")
		height=$(get_ffprobe "$input" "height")
		pix_fmt=$(get_ffprobe "$input" "pix_fmt")
		showinfo_video $input
		run_ffmpeg -i "$input" -vf "color=c=${col}:s=${width}x${height}:d=${dur} [pre] ; [pre] [in] concat=n=2" $fformat -pix_fmt $pix_fmt -y "$output"
		showinfo_video $output
		;;

    EXTRACT|extract )
		showinfo_video $input
		run_ffmpeg -i "$input" -r 2 -q:v 2 -y "$output" 
		;;

    SCALE|scale )
		showinfo_video $input
	    width=$(get_ffprobe "$input" "width")
	    height=$(get_ffprobe "$input" "height")
	    pix_fmt=$(get_ffprobe "$input" "pix_fmt")
	    bname=$(basename "$input")
	    # scale=320:240:force_original_aspect_ratio=decrease,pad=320:240:(ow-iw)/2:(oh-ih)/2
        case $scale in
          BOX|box)
            log "SCALE with method [(letter)box]"
			run_ffmpeg -i "$input" -vf "scale=w=$wout:h=$hout:force_original_aspect_ratio=decrease, pad=$wout:$hout:($wout-iw)/2:($hout-ih)/2" $fformat -pix_fmt $pix_fmt -y "$output"
            ;;
          STRETCH|stretch)
            log "SCALE with method [stretch]"
            run_ffmpeg -i "$input" -vf "scale=w=1080:h=1920" $fformat -y "$output"
            ;;
          IMAGE|image)
            # create background
            log "SCALE with method [blur]"
            tmp_bg=$TMPDIR/$(basename "$input" | cut -c1-10).bg.png
            w2=$(expr $width / \( $blur \* 4 \) \* 4 )
            h2=$(expr $height / \( $blur \* 4 \) \* 4 )
            radius=5
            if [ $blur -le 5 ] ; then
              radius=2
            fi
            run_ffmpeg -i "$input" -vf "scale=w=$w2:h=$h2, boxblur=$radius:1, scale=w=1080:h=1920" $fformat -y "$tmp_bg"
            # now overlay
            run_ffmpeg -i "$tmp_bg" -i "$input" -filter_complex " [0:v][1:v] overlay=0:(H-h)/2" $fformat -y "$output"
            ;;
          *)
          die "Cannot scale with method [$scale]"
        esac
	    showinfo_video $output 
	    ;;

    BACK|back|BACKGROUND|background )
# ffmpeg -r 25 -loop 1 -i img/PHD.jpg -i mov/Paddington.mov -filter_complex "[1:v]scale=w=1080:h=-1 [pip]; [0:v][pip] overlay=0:500" -pix_fmt yuv420p -t 10 -b:v 5M  -y mov/test.mov

	    width=$(get_ffprobe "$input" "width")
	    height=$(get_ffprobe "$input" "height")
	    out "Resolution: $width x $height"
	    pix_fmt=$(get_ffprobe "$input" "pix_fmt")
	    vid_cod=$(get_ffprobe "$input" "codec_name")
	    out "Encoding  : $vid_cod ($pix_fmt)"
	    duration=$(get_ffprobe "$input" "duration" | awk '{printf "%.2f", $1}')
	    nbframes=$(get_ffprobe "$input" "nb_frames")
	    framerate=$(get_ffprobe "$input" "avg_frame_rate")
	    framerate=$(echo $framerate | sed 's#/1##g')
	    bname=$(basename "$input")
	    out "Duration  : $duration sec ($nbframes frames @ $framerate fps)"
	    log_out=$TMPDIR/$bname.scale.log
	    log "Log file = [$log_out]"

	    maxheight=$(expr $width \* 16 / 9)
	    log "max height = $maxheight"
	    if [ $height -lt $maxheight ] ; then
	      # height is smaller => letterbox = black top and bottom
	      log "create letterbox [$output] ..."
	      log "ffmpeg -i '$input' -vf 'scale=w=1080:h=-1, pad=1080:1920:0:(1920-ih)/2' $fformat -pix_fmt $pix_fmt -y '$output'"
	      ffmpeg -i "$input" -vf "scale=w=1080:h=-1, pad=1080:1920:0:(1920-ih)/2" $fformat -pix_fmt $pix_fmt -y "$output" 2> $log_out
	    else
	      # height is more => pilarbox = black left and right
	      log "create pillarbox [$output] ..."
	      ffmpeg -i "$input" -vf "scale=w=-1:h=1920, pad=1080:1920:(1080-iw)/2:0" $fformat -pix_fmt $pix_fmt -y "$output" 2> $log_out
	    fi
	    newdur=$(get_ffprobe "$output" "duration" | awk '{printf "%.2f", $1}')
	    out "New duration: $newdur sec"
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