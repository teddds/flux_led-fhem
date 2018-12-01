# Id ##########################################################################
# $Id:  $

# copyright ###################################################################
#
# 32_FluxLED.pm
#
# Copyright by igami
#
# This file is part of FHEM.
#
# FHEM is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# FHEM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FHEM.  If not, see <http://www.gnu.org/licenses/>.

# packages ####################################################################
package main;
  use strict;
  use warnings;

  use Blocking;
  use Color;

# variables ###################################################################
my $FluxLED_path = "/opt/fhem/FHEM/lib/flux_led/flux_led.py";
my %FluxLED_preset = (
    "seven_color_cross_fade" => 37
  , "red_gradual_change" => 38
  , "green_gradual_change" => 39
  , "blue_gradual_change" => 40
  , "yellow_gradual_change" => 41
  , "cyan_gradual_change" => 42
  , "purple_gradual_change" => 43
  , "white_gradual_change" => 44
  , "red_green_cross_fade" => 45
  , "red_blue_cross_fade" => 46
  , "green_blue_cross_fade"    => 47
  , "seven_color_strobe_flash" => 48
  , "red_strobe_flash" => 49
  , "green_strobe_flash" => 50
  , "blue_stobe_flash" => 51
  , "yellow_strobe_flash" => 52
  , "cyan_strobe_flash" => 53
  , "purple_strobe_flash" => 54
  , "white_strobe_flash" => 55
  , "seven_color_jumping" => 56
);

# forward declarations ########################################################
sub FluxLED_Initialize($);

sub FluxLED_Define($$);
sub FluxLED_Undefine($$);
sub FluxLED_Set($@);
sub FluxLED_Get($@);

sub FluxLED_statusRequest($;$);
sub FluxLED_blocking_statusRequest($);
sub FluxLED_done($);
sub FluxLED_aborted($);

# initialize ##################################################################
sub FluxLED_Initialize($) {
  my ($hash) = @_;
  my $TYPE = "FluxLED";

  $hash->{DefFn}    = $TYPE."_Define";
  $hash->{UndefFn}  = $TYPE."_Undefine";
  $hash->{SetFn}    = $TYPE."_Set";
  $hash->{GetFn}    = $TYPE."_Get";
  $hash->{AttrFn}   = $TYPE."_Attr";
	
  $hash->{AttrList} = ""
    . "disabled:0,1 "
    . "interval "
    . "path "
	. "defaultDimDelta "
    . "defaultColorOnStart:colorpicker "
    . "defaultCustomPresetOnStart "
    . "defaultPresetOnStart:"
		. "seven_color_cross_fade,"
		. "red_gradual_change,"
		. "green_gradual_change,"
		. "blue_gradual_change,"
		. "yellow_gradual_change,"
		. "cyan_gradual_change,"
		. "purple_gradual_change,"
		. "white_gradual_change,"
		. "red_green_cross_fade,"
		. "red_blue_cross_fade,"
		. "green_blue_cross_fade,"
		. "seven_color_strobe_flash,"
		. "red_strobe_flash,"
		. "green_strobe_flash,"
		. "blue_stobe_flash,"
		. "yellow_strobe_flash,"
		. "cyan_strobe_flash,"
		. "purple_strobe_flash,"
		. "white_strobe_flash,"
		. "seven_color_jumping "
    . "defaultRamp "
    . "customPreset:textField-long "
    . $readingFnAttributes
  ;
}

# regular Fn ##################################################################
sub FluxLED_Define($$) {
  my ($hash, $def) = @_;
  my ($SELF, $TYPE, $MODE, @CONTROLLERS) = split(/[\s]+/, $def);

  return(
    "Usage: define <name> $TYPE <(RGB|RGBW|W)> <CONTROLLERS> [<CONTROLLERS2> ...]"
  ) if($MODE !~ m/^(RGB|RGBW|W)$/ || @CONTROLLERS < 1);

  $hash->{MODE} = $MODE;
  $hash->{CONTROLLERS} = join(" ", @CONTROLLERS);
  $hash->{PATH} = AttrVal($SELF, "path", $FluxLED_path);
  $hash->{INTERVAL} = AttrVal($SELF, "interval", 5);

  readingsSingleUpdate($hash, "state", "Initialized", 1);

  FluxLED_statusRequest($hash);

  return;
}

sub FluxLED_Undefine($$) {
  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);
  BlockingKill($hash->{helper}{RUNNING_PID}) if(defined($hash->{helper}{RUNNING_PID}));
  return;
}

sub FluxLED_Set($@) {
  my ($hash, @a) = @_;
  my $TYPE = $hash->{TYPE};
  my $MODE = $hash->{MODE};
  my $PATH = $hash->{PATH};

  return("\"set $TYPE\" needs at least one argument") if(@a < 2);

  my $SELF     = shift @a;
  my $argument = shift @a;
  my $value    = join(" ", @a) if (@a);
  my %FluxLED_sets_hidden = (
      "RGB_OFF"       => "RGB_OFF:textField"
  );
  my %FluxLED_sets = (
      "on"            => "on:textField"
    , "off"           => "off:noArg"
    , "statusRequest" => "statusRequest:noArg"
  );

  if($MODE =~ m/RGB/){
    my $preset = join(",", (AttrVal($SELF, "customPreset", "") =~ m/([A-Za-z-_.]+):/g));
    $preset .= "," if($preset);

    %FluxLED_sets = (
        %FluxLED_sets
      , "RGB"    => "RGB:textField"
      , "custom" => "custom:textField"
      , "preset" => "preset:"
                  . "$preset"
                  . "seven_color_cross_fade,"
                  . "red_gradual_change,"
                  . "green_gradual_change,"
                  . "blue_gradual_change,"
                  . "yellow_gradual_change,"
                  . "cyan_gradual_change,"
                  . "purple_gradual_change,"
                  . "white_gradual_change,"
                  . "red_green_cross_fade,"
                  . "red_blue_cross_fade,"
                  . "green_blue_cross_fade,"
                  . "seven_color_strobe_flash,"
                  . "red_strobe_flash,"
                  . "green_strobe_flash,"
                  . "blue_stobe_flash,"
                  . "yellow_strobe_flash,"
                  . "cyan_strobe_flash,"
                  . "purple_strobe_flash,"
                  . "white_strobe_flash,"
                  . "seven_color_jumping"
      , "speed" => "speed:slider,0,1,100"
	  , "dim" => "dim:slider,0,1,100"
	  , "dimUp" => "dimUp:textField"
	  , "dimDown" => "dimDown:textField"
    );
  }
  if($MODE =~ m/W/){
    %FluxLED_sets = (
        %FluxLED_sets
      , "white" => "white:slider,0,1,100"
    );
  }
  
  

  return(
    "Unknown argument $argument, choose one of "
    . join(" ", sort(values %FluxLED_sets))
  ) unless(
	exists($FluxLED_sets{$argument}) or
	exists($FluxLED_sets_hidden{$argument})
  );

  my $CONTROLLERS = $hash->{CONTROLLERS};
  my $cmd;

  #Log3($SELF, 3, "Argument: $argument Value: $value");
  
  if($argument =~ m/^(on|off)$/){
    $cmd = "$PATH --$argument $CONTROLLERS";
	my $action = $1;
	my $color_preset = undef;
	
	my ($_color, $_ramp) = FluxLED_getPresetRamp($hash,$value);
	if($_color){
		$color_preset = $_color;
	}	
	
	#Log3($SELF, 3, "SET ON/OFF: action: $action  color_preset: $color_preset ramp: $_ramp ");

	if(!$action){
		return;
	}
	
	my $dim = ReadingsVal($SELF, "dim", "100");
	my $defaultColorOnStart = AttrVal($SELF, "defaultColorOnStart", undef);
	if($defaultColorOnStart){
		$defaultColorOnStart = FluxLED_GetDimmedColor($hash,$defaultColorOnStart,$dim);
	}else{
		$defaultColorOnStart = ReadingsVal($SELF, "LastChoosedColor", "FFFFFF");
	}
	my $defaultPresetOnStart = AttrVal($SELF, "defaultPresetOnStart", undef);
	my $defaultCustomPresetOnStart = AttrVal($SELF, "defaultCustomPresetOnStart", undef);
	my $fadeDuration = AttrVal($SELF, "defaultRamp", "");
	
	if($_ramp){
		$fadeDuration = $_ramp;
	}

	#Prüfen welche Farbe bzw Preset geladen werden soll
	if($color_preset){
		if(FluxLED_isColor($hash,$color_preset)){
			$defaultColorOnStart = $color_preset;
			$defaultPresetOnStart = undef;
			$defaultCustomPresetOnStart = undef;
		}elsif(FluxLED_isCustomPreset($hash,$color_preset)){
			$defaultColorOnStart = undef;
			$defaultPresetOnStart = undef;
			$defaultCustomPresetOnStart = $color_preset;
		}elsif(FluxLED_isPreset($hash,$color_preset)){
			$defaultColorOnStart = undef;
			$defaultPresetOnStart = $color_preset;
			$defaultCustomPresetOnStart = undef;
		}
	}
	
	#Log3($SELF, 3, "SET ON/OFF: defaultColorOnStart: $defaultColorOnStart defaultPresetOnStart: $defaultPresetOnStart defaultCustomPresetOnStart: $defaultCustomPresetOnStart ");
	
	if($action eq "on"){
		if($defaultCustomPresetOnStart){
			return FluxLED_Set($hash, $SELF, "preset", $defaultCustomPresetOnStart);
		}elsif($defaultPresetOnStart){
			return FluxLED_Set($hash, $SELF, "preset", $defaultPresetOnStart);
		}elsif($defaultColorOnStart){
			return FluxLED_Set($hash, $SELF, "RGB", "$defaultColorOnStart $fadeDuration");
		}
	}elsif($action eq "off"){	
		#Wir faden auf Schwarz, damit wir nach dem nächsten einschalten erneut faden können
		return FluxLED_Set($hash, $SELF, "RGB_OFF", "000000 $fadeDuration");
	}	
	
	readingsSingleUpdate($hash, "state", $action, 1);
  }
  elsif($argument eq "RGB" or $argument eq "RGB_OFF"){
	
	my $color = $value;
	my $fadeDuration = AttrVal($SELF, "defaultRamp", undef);
	
	#Prüfen ob nur eine farbe oder auch eine ramp geliefert wird
	my ($_color, $_ramp) = FluxLED_getPresetRamp($hash,$value);
	if($_color){
		$color = $_color;
	}	
	
	if($_ramp){
		$fadeDuration = $_ramp;
	}
	
	if(!FluxLED_isColor($hash,$color)){
		#Log3($SELF, 3, "SET $argument: color: $color  Color not valid.");
		return;
	}
	
	#Log3($SELF, 3, "SET $argument: color: $color  ramp: $fadeDuration");
  
    my ($R, $G, $B) = Color::hex2rgb($color);
	my ($H, $S, $V) = FluxLED_GetHSV($color);
	
	
	my $f = "";
	if($fadeDuration){
		$f = " -f $fadeDuration "
	}
	
	$cmd = "$PATH --on --color $R,$G,$B $f $CONTROLLERS";
	  
	if($argument eq "RGB_OFF"){
	  $cmd = "$PATH --off --color $R,$G,$B $f $CONTROLLERS";
	}
  
	
	#Log3($SELF, 3, "SET RGB: Rot: $R Gruen: $G Blau: $B Brightness: $V");
	
    readingsBeginUpdate($hash);
	if($argument eq "RGB_OFF"){
		readingsBulkUpdateIfChanged($hash, "state", "off", 0);
	}else{
		readingsBulkUpdateIfChanged($hash, "state", "on", 1);
		readingsBulkUpdate($hash, "LastChoosedColor", $color, 1);
		readingsBulkUpdate($hash, "dim", int($V*100), 1);
	}
    readingsBulkUpdate($hash, "RGB", $color, 1);
	#Log3($SELF, 3, "SET $argument: color: $color  ramp: $fadeDuration");
	readingsEndUpdate($hash, 1);
  }
  elsif($argument eq "custom"){
    my ($type, $colorlist) = split(/[\s]+/, $value, 2);
    my @colorlist = split(/[\s]+/, $colorlist);
	#Log3($SELF, 3, "SET Custom: $value");
	
    foreach (@colorlist){
      $_ = join(",", Color::hex2rgb($_)) if(FluxLED_isColor($hash,$_));
      $_ = "($_)";
    }

    $colorlist = join(" ", @colorlist);
    my $speed = ReadingsVal($SELF, "speed", 100);
    $cmd = "$PATH --on --$argument $type $speed \"$colorlist\" $CONTROLLERS";

    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, ".custom_type", $type, 0);
    readingsBulkUpdate($hash, ".custom_colorlist", $colorlist, 0);
    readingsBulkUpdateIfChanged($hash, "state", "on", 1);
    readingsBulkUpdate($hash, "preset", $argument, 1);
    readingsEndUpdate($hash, 1);
  }
  elsif($argument eq "preset"){
	my $cp = FluxLED_isCustomPreset($hash, $value);
	my $p = FluxLED_isPreset($hash, $value);
	if($cp){
		FluxLED_Set($hash, $SELF, "custom", $cp);
		return;
	}elsif($p){
	
		my $speed = ReadingsVal($SELF, "speed", 100);
		$cmd = "$PATH --on --$argument $p $speed $CONTROLLERS";
		
		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, "preset", $value, 1);
		readingsBulkUpdateIfChanged($hash, "state", "on", 1);
		readingsEndUpdate($hash, 1);
	}
  }
  elsif($argument eq "speed"){
    my $preset = ReadingsVal($SELF, "preset", "seven_color_cross_fade");

	#Log3($SELF, 3, "SET Speed: $value");
	
    if($preset eq "custom"){
      my $type = ReadingsVal($SELF, ".custom_type", "gradual");
      my $colorlist = ReadingsVal($SELF, ".custom_colorlist", "(0,0,0)");
      $cmd = "$PATH --on --custom $type $value \"$colorlist\" $CONTROLLERS";
    }
    else{
      $preset = $FluxLED_preset{$preset};
      $cmd = "$PATH --on --preset $preset $value $CONTROLLERS";
    }

    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "speed", $value, 1);
    readingsBulkUpdateIfChanged($hash, "state", "on", 1);
    readingsEndUpdate($hash, 1);
  }
  elsif($argument eq "dim"){
	my $color = ReadingsVal($SELF, "LastChoosedColor", "FFFFFF");
	my $fadeDuration = AttrVal($SELF, "defaultRamp", undef);
	my $dimvalue = $value;
	#Prüfen ob nur eine Dimwert oder auch eine ramp geliefert wird
	if($value =~ m/^(\d*)\s*?([\d\.]*?)$/){
		$dimvalue = $1;
		if($2){
			$fadeDuration = $2;
		}
	}
	
	my $dimcolor = FluxLED_GetDimmedColor($hash,$color,$dimvalue);
	
	my ($R, $G, $B) = Color::hex2rgb($dimcolor);
	
	#Log3($SELF, 3, "GET hsv2rgb: R: $R G: $G B: $B");
	
	my $f = "";
	if($fadeDuration){
		$f = " -f $fadeDuration "
	}
	
    $cmd = "$PATH --on --color $R,$G,$B $f $CONTROLLERS";

	readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "dim", $dimvalue, 1);
    readingsBulkUpdateIfChanged($hash, "state", "on", 1);
    readingsEndUpdate($hash, 1);
	
  }
   elsif($argument eq "dimUp"){
   
	my $deltaDim = FluxLED_GetDimDelta($hash,$value);
	my $currentDim = ReadingsVal($SELF, "dim", 100);
	my $dim = undef;
	if($currentDim + $deltaDim > 100){
		$dim = 100;
	}elsif($currentDim + $deltaDim < 0){
		$dim = 0;
	}else{
		$dim = $currentDim + $deltaDim;
	}	
	return FluxLED_Set($hash, $SELF, "dim", "$dim 0.1");
  }
  elsif($argument eq "dimDown"){
   
	my $deltaDim = FluxLED_GetDimDelta($hash,$value);
	my $currentDim = ReadingsVal($SELF, "dim", 100);
	my $dim = undef;
	if($currentDim - $deltaDim > 100){
		$dim = 100;
	}elsif($currentDim - $deltaDim < 0){
		$dim = 0;
	}else{
		$dim = $currentDim - $deltaDim;
	}	
	return FluxLED_Set($hash, $SELF, "dim", "$dim 0.1");
  }
  elsif($argument eq "white"){
  
	my $fadeDuration = AttrVal($SELF, "defaultRamp", undef);
	my $f = "";
	if($fadeDuration){
		$f = " -f $fadeDuration "
	}
    $cmd = "$PATH --on --warmwhite $value $f $CONTROLLERS";
	#Log3($SELF, 3, "Set White: $value");
	
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "white", $value, 1);
    readingsBulkUpdateIfChanged($hash, "state", "on", 1);
    readingsEndUpdate($hash, 1);
  }

  FluxLED_statusRequest($hash, $cmd);

  return;
}

sub FluxLED_isColor(@){
	my ($hash, $color) = @_;
	my $SELF = $hash->{NAME};
	if(!$color){
		#Log3($SELF, 3, "FluxLED_isColor: $color - Kein Parameter übergeben");
		return 0;
	}
	if($color =~ m/[0-9A-Fa-f]{6}/){
		#Log3($SELF, 3, "FluxLED_isColor: $color - True");
		return 1;
	}
	
	#Log3($SELF, 3, "FluxLED_isColor: $color - False");
	return 0;
}


sub FluxLED_isPreset(@){
	my ($hash, $preset) = @_;
	my $SELF = $hash->{NAME};
	if(!$preset){
		#Log3($SELF, 3, "FluxLED_isPreset: $preset - Kein Parameter übergeben");
		return 0;
	}
	
	if($FluxLED_preset{$preset}){
		#Log3($SELF, 3, "FluxLED_isPreset: $preset - True");
		return $FluxLED_preset{$preset};
	}
	
	#Log3($SELF, 3, "FluxLED_isPreset: $preset - False");
	return 0;
}


sub FluxLED_getPresetRamp(@){
	my ($hash, $str) = @_;
	my $SELF = $hash->{NAME};
	my $preset = undef; 
	my $ramp = undef;
	
	if($str and $str =~ m/^\s*([A-Za-z0-9]+)\s*(\d*)/){
		if(FluxLED_isPreset($hash,$1) or FluxLED_isColor($hash,$1) or FluxLED_isCustomPreset($hash,$1)){
			$preset = $1;
			#Log3($SELF, 3, "FluxLED_getPresetRamp: Preset/Color: $1");
		}else{
			#Log3($SELF, 3, "FluxLED_getPresetRamp: Prest Color nicht definiert $1");
		}
		if($2){
			$ramp = $2;
			#Log3($SELF, 3, "FluxLED_getPresetRamp: Ramp: $2");
		}else{
			#Log3($SELF, 3, "FluxLED_getPresetRamp: Ramp nicht definiert $2");
		}
	}else{
		#Log3($SELF, 3, "FluxLED_getPresetRamp: Nicht erkanntes Format $str -> m/^\\s*([A-Za-z0-9]+)\\s*(\\d*)/");
	}
	
	return ($preset, $ramp);
}

sub FluxLED_isCustomPreset(@){
	my ($hash, $preset) = @_;
	my $SELF = $hash->{NAME};
	if(!$preset){
		#Log3($SELF, 3, "FluxLED_isCustomPreset: $preset - Kein Parameter übergeben");
		return 0;
	}
	
	my $_customPresets = AttrVal($SELF, "customPreset", undef);
	if(!$_customPresets){
		#Log3($SELF, 3, "FluxLED_isCustomPreset: $preset - Keine CustomPreset erstellt");
		return 0;
	}
	
    
    if($_customPresets =~ m/$preset:((jump|gradual|strobe)(\s+[0-9A-Fa-f]{6})+)/){
		#Log3($SELF, 3, "FluxLED_isCustomPreset: $preset - True");
		return $1;
	}
	#Log3($SELF, 3, "FluxLED_isCustomPreset: $preset - False - Liste: $_customPresets");
	return 0;
}

sub FluxLED_GetDimDelta(@){
	my ($hash, $str) = @_;
	my $SELF = $hash->{NAME};
	my $delta = undef; 
	#Log3($SELF, 3, "FluxLED_GetDimDelta: $str");
	if($str and $str =~ m/^(\d*)/){
		$delta = $1;
	}else{
		$delta = AttrVal($SELF, "defaultDimDelta", 5);
	}
	#Log3($SELF, 3, "FluxLED_GetDimDelta: Delta -> $delta");
	return $delta;
}

sub FluxLED_GetHSV(@){
	my ($color) = @_;
	my ($r, $g, $b) = Color::hex2rgb($color);
	$r /= 255.0 if( $r > 1 );
	$g /= 255.0 if( $g > 1 );
	$b /= 255.0 if( $b > 1 );
	return Color::rgb2hsv($r,$g,$b);
}

sub FluxLED_GetDimmedColor(@){
	my ($hash, $color, $dim) = @_;
	$dim /= 100.0 if( $dim > 1 );
	
	my ($H, $S, $V) = FluxLED_GetHSV($color);
	
	#Log3($hash->{NAME}, 3, "GET hex2hsv: H: $H S: $S V: $V Bright: $dim");
	
	my ($_r, $_g, $_b) = Color::hsv2rgb($H, $S, $dim);
	#Log3($hash->{NAME}, 3, "GET hsv2rgb: R: $_r G: $_g B: $_b");
	
	$_r *= 255.0 if( $_r <= 1 );
	$_g *= 255.0 if( $_g <= 1 );
	$_b *= 255.0 if( $_b <= 1 );
	
	
	$_r = int($_r);
	$_g = int($_g);
	$_b = int($_b);
	
	#Log3($hash->{NAME}, 3, "GET hsv2rgb: R: $_r G: $_g B: $_b  	");
	
	return Color::rgb2hex($_r, $_g, $_b);
}

sub FluxLED_Get($@) {
  my ($hash, @a) = @_;
  my $TYPE = $hash->{TYPE};
  my $PATH = $hash->{PATH};

  return("\"get $TYPE\" needs at least one argument") if(@a < 1);

  my $SELF = shift @a;
  my $argument = shift @a;
  my $value = join(" ", @a) if (@a);
  my %FluxLED_gets = (
      "clock"      => "clock:noArg"
    , "controllers" => "controllers:noArg"
  );

  return(
    "Unknown argument $argument, choose one of "
    . join(" ", sort(values %FluxLED_gets))
  ) unless(exists($FluxLED_gets{$argument}));

  my $CONTROLLERS = $hash->{CONTROLLERS};
  my $ret;

  if($argument eq "clock"){
    $ret = `$PATH --getclock $CONTROLLERS`;
    my @ret =  split(/[\s]+/, $ret);
    $ret = @ret == 5 ? "$ret[3] $ret[4]" : undef;
  }
  elsif($argument eq "controllers"){
    $ret = `$PATH --scan`;
  }

  return $ret;
}

sub FluxLED_Attr(@) {
  my ($cmd, $SELF, $attribute, $value) = @_;
  my $hash = $defs{$SELF};
  my $TYPE = $hash->{TYPE};

  #Log3($SELF, 5, "$TYPE ($SELF) - entering FluxLED_Attr");

  if($attribute eq "interval"){
    if($cmd eq "delete" || !looks_like_number($value) || $value < 30){
      delete($hash->{INTERVAL});
    }
    else{
      $hash->{INTERVAL} = $value;

      RemoveInternalTimer($hash);

      return if(IsDisabled($SELF));

      InternalTimer(
        gettimeofday() + $hash->{INTERVAL}, "FluxLED_statusRequest", $hash
      );
    }
  }
  elsif($attribute eq "customPreset" && $cmd eq "set"){
    return(
        "$SELF: Value \"$value\" is not allowed for preset!\n"
      . "Must be a space-separated list of "
      . "\"<preset>:<jump|gradual|strobe> <RRGGBB> <RRGGBB> ...\" rows.\n"
      . "e.g. RGB:gradual 000000 FF0000 000000 00FF00 000000 0000FF\n"
      . "Only these characters are allowed: [alphanumeric - _ .]"
      ) if($value !~ m/^(\s*([A-Za-z-_.]+):(jump|gradual|strobe)(\s+[0-9A-Fa-f]{6})+)+$/);
  }
  elsif($attribute eq "path"){
    $hash->{PATH} = $cmd eq "set" ? $value : $FluxLED_path;
  }

  return;
}

# blocking Fn #################################################################
sub FluxLED_statusRequest($;$) {
  my ($hash, $cmd) = @_;
  my $SELF = $hash->{NAME};
  my $TYPE = $hash->{TYPE};
  my $interval = InternalVal($SELF, "INTERVAL", undef);
  my $timeout = AttrVal($SELF, "timeout", "default");
  $timeout = 60 unless(looks_like_number($timeout));
  my $PATH = $hash->{PATH};
  
  #Log3($SELF, 3, "$TYPE ($SELF) CMD: $cmd - entering FluxLED_statusRequest");

  BlockingKill($hash->{helper}{RUNNING_PID})
    if(defined($hash->{helper}{RUNNING_PID}));

  if($interval){
    RemoveInternalTimer($hash);
    InternalTimer(gettimeofday() + $interval, "FluxLED_statusRequest", $hash);
  }

  unless(-X $PATH){
    readingsSingleUpdate($hash, "state", "error", 1);
    Log3(
        $SELF, 1, "$TYPE ($SELF) - "
      . "please check if flux_led ist installed and available at path $PATH"
    );

    return;
  }

 # Log3($SELF, 5, "$TYPE ($SELF) - BlockingCall FluxLED_blocking_statusRequest");
 
  
	my $arg = $cmd ? "$SELF||$cmd" : $SELF;

	  $hash->{helper}{RUNNING_PID} = BlockingCall(
		  "FluxLED_blocking_statusRequest", $arg, "FluxLED_done"
		, $timeout, "FluxLED_aborted", $SELF
	  # ) unless(exists($hash->{helper}{RUNNING_PID}));
	  );

	  return;
  

  
}

sub FluxLED_blocking_statusRequest($) {
  my ($SELF, $cmd) = split("\\|\\|", shift);
  my ($hash) = $defs{$SELF};
  my $TYPE = $hash->{TYPE};
  my $IP = (split(" ", $hash->{CONTROLLERS}))[0];
  my $PATH = $hash->{PATH};
  
  my $ret = `$cmd` if($cmd);
  
  
  my @ret = split("\n", `$PATH $IP --timers`);
  #Log3($SELF, 3, "ret - entering FluxLED_blocking_statusRequest");
  
  my $tmp = $ret[0];

  #Log3($SELF, 3, "$TYPE ($SELF) $tmp - entering FluxLED_blocking_statusRequest");

  if($ret[0] =~ m/(ON|OFF)\s+\[Warm White: (\d+)% Color: \((\d+), (\d+), (\d+)/){
  
 # Log3($SELF, 3, "Werte: $2 $3 $4 $5 Ende");
  
    $ret[7] = "white|$2";
	$ret[8] = "RGB|" . Color::rgb2hex($3, $4, $5);
  }
  elsif($ret[0] =~ m/(ON|OFF)\s+\[Pattern: ([A-Za-z ]+) \(Speed (\d+)%/){
    $ret[7] = "preset|" . lc($2);
    $ret[8] = "speed|$3";
    $ret[7] =~ s/\s+/_/g;
  }
  elsif($ret[0] =~ m/(ON|OFF)\s+\[Custom pattern \(Speed (\d+)%/){
    $ret[7] = "preset|custom";
    $ret[8] = "speed|$2";
  }
  else{
    return("state|error");
  }

  $ret[0] = "state|" . lc($1);

  for(my $i = 1; $i < 7; $i++){
    $ret[$i] = "timer-$i|" . (split(": ", $ret[$i]))[1];
  }

  return (join("||", $SELF, @ret));
}

sub FluxLED_done($) {
  my ($string) = @_;
  my ($SELF, @readings) = split("\\|\\|", $string);
  my ($hash) = $defs{$SELF};
  my $TYPE = $hash->{TYPE};

  #Log3($SELF, 3, "$TYPE ($SELF) - entering FluxLED_done");

  unless(@readings){
    delete($hash->{helper}{RUNNING_PID});
	return;
  }

  readingsBeginUpdate($hash);

  foreach (@readings){
    my ($reading, $value) = split("\\|", $_);

    readingsBulkUpdate($hash, $reading, $value);
  }

  readingsEndUpdate($hash, 1);

  delete($hash->{helper}{RUNNING_PID});
  return;
}

sub FluxLED_aborted($) {
  my ($SELF) = @_;
  my $hash = $defs{$SELF};
  my $TYPE = $hash->{TYPE};

  #Log3($SELF, 1, "$TYPE ($SELF) - entering FluxLED_aborted");

  delete($hash->{helper}{RUNNING_PID});

  readingsSingleUpdate($hash, "state", "error", 1);

  return;
}

1;

# commandref ##################################################################
=pod
=item device
=item summary    controlls different WLAN LED Controller
=item summary_DE steuert verschiedene WLAN LED Controller

=begin html

<a name="FluxLED"></a>
<h3>FluxLED</h3>
( en | <a href="commandref_DE.html#FluxLED"><u>de</u></a> )
<div>
  <ul>
    FluxLED steuert über das
    <a href="https://github.com/beville/flux_led">
      <u>flux_led.py Skript</u>
    </a> verschiedene WLAN LED Controller.<br>
    <br>
    Vorraussetzungen:
    <ul>
      Es wird das
      <a href="https://github.com/beville/flux_led">
        <u>flux_led.py Skript</u>
      </a>
      benötig.<br>
      Dies kann über git installiert werden:<br>
      <code>"sudo git clone https://github.com/beville/flux_led.git /opt/flux_led"</code>
      .
    </ul>
    <br>
    <a name="FluxLEDdefine"></a>
    <b>Define</b>
    <ul>
      <code>
        define &lt;name&gt; FluxLED
        &lt;(RGB|RGBW|W)&gt; &lt;CONTROLLER1&gt; [&lt;CONTROLLER2&gt; ...]
      </code><br>
      Es muss angegebenen werden ob der Controller als RGB, RGBW oder W
      betrieben wird. Danach werden durch Leerzeichen getrennt die IP Adressen
      aller Controller angegebenen die zusammen geschaltet werden sollen. Bei
      einem statusRequest wird immer nur der erste Controller ausgelesen.
    </ul><br>
    <a name="FluxLEDset"></a>
    <b>Set</b>
    <ul>
      <li>
        <code>on</code><br>
        Schalatet alle Controller ein, dabei wird der letze Zustand wiederhergestellt.
      </li>
      <li>
        <code>off</code><br>
        Schalatet alle Controller aus.
      </li>
      <li>
        <code>statusRequest</code><br>
        Fragt den Status vom ersten Controller ab.
      </li>
      <li>
        <code>RGB RRGGBB</code><br>
        Schaltet die Controller auf die angegebene Farbe.
      </li>
      <li>
        <code>custom &lt;(jump|gradual|strobe)&gt; RRGGBB&gt; RRGGBB&gt; ... </code><br>
        Startet eine benutzerdefinierte Sequenz.
      </li>
      <li>
        <code>preset</code><br>
        Startet eine vorgegebene Sequenz.
      </li>
      <li>
        <code>speed</code><br>
        Legt die Geschwindigkeit für die letzte Sequenz fest.
      </li>
      <li>
        <code>white</code><br>
        Schaltet den Weiß-Kanal auf den angegebenen Wert.
      </li>
    </ul><br>
    <a name="FluxLEDreadings"></a>
    <b>Readings</b><br>
    <ul>
      <li>
        <code>state (on|off|error)</code><br>
      </li>
      <li>
        <code>speed</code><br>
        Geschwindigkeit der Sequenz.
      </li>
      <li>
        <code>present</code><br>
        Zuletzt benutze Sequenz.
      </li>
      <li>
        <code>timer-(1..6)</code><br>
        Die auf dem Controller eingestellten Timer.
      </li>
    </ul><br>
    <a name="FluxLEDattr"></a>
    <b>Attribute</b>
    <ul>
      <li>
        <code>customPreset</code><br>
        Eine Leerzeichen-getrennte Liste von
        "&lt;preset&gt;:&lt;(jump|gradual|strobe)&gt; &lt;RRGGBB&gt;
        &lt;RRGGBB&gt; ..." Reihen.
      </li>
      <li>
        <code>disable 1</code><br>
        Es werden keine weitere statusRequest durchgeführt.
      </li>
      <li>
        <code>interval &lt;interval&gt;</code><br>
        Legt fest in welchem Abstand der Controller abgefragt werden soll.<br>
        Wenn das Attribut nicht gesetzt, erfolgt dies nur nach dem absetzen
        eines Befehls. Ein Regelmäßiges Abfragen kann sinnvoll sein, wenn man
        den Controller noch anders steuert.
      </li>
      <li>
        <code>path</code><br>
        Pfad unter dem das flux_led.py Skript erreichba ist.<br>
        Die Vorgabe ist "/opt/fhem/flux_led/flux_led.py".
      </li>
      <li>
        <a href="#readingFnAttributes">
          <u><code>readingFnAttributes</code></u>
        </a>
      </li>
    </ul>
  </ul>
</div>

=end html
=cut
