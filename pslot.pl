#!/usr/bin/perl
# pslot.pl
#
# Copyright 2012 Brian Smith 
#
# version 0.3 Alpha - 10/09/12
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use Getopt::Std;

my ($hmc,$system,@out,$line,%sslots,%cslots,$ckey,$skey,%opts,$dotmode,%vios,%d,$s,$error,$mode,$lpar,$range,$min,$max);
my $doterror = "Warning: following slots not setup correctly:\\n";
my $scount = 0;
my $ccount = 0;
my $viocount = 1;

sub showusage{
	print "\nUsage $0 -h hmcserver -m managedsystem { -v | -f } [-l lpar] [-r min-max] [-d] [-s] \n";
	print " -h specifies hmcserver name (can also be username\@hmc) \n";
	print " -m specifies managed system name\n";
        print " { -v | -f } specify either -v (Virtual SCSI) or -f (Virtual Fibre Channel)\n";
	print " [-l lpar] only report/graph on specific lpar and its VIO servers\n";
	print " [-r min-max] only report/graph range of VIO server slots.  \n";
	print "    Example: \"-r 40-50\" will graph slot pairs that have VIO server slots between 40 to 50\n";
	print " -d turn on Graphviz dot output mode\n";
	print " -s Display graph left to right in Graphviz mode\n\n";
	print "Examples:\n";
	print "VSCSI graphviz mode:\n";
        print "   $0 -h hscroot\@hmcserver1 -m p520 -v -d -s\n";
	print "VSCSI text mode:      \n";
	print "   $0 -h hscroot\@hmcserver1 -m p520 -v\n";
	print "VFC graphviz mode:    \n";
	print "   $0 -h hscroot\@hmcserver1 -m p520 -f -d -s\n";
	print "VFC text mode:        \n";
	print "   $0 -h hscroot\@hmcserver1 -m p520 -f\n";
	print "VFC graphviz mode, only graph lpar1     \n";
	print "   $0 -h hscroot\@hmcserver1 -m p520 -l lpar1 -f -d -s\n";
	print "VSCSI graphviz mode, only graph slot pairs with VIO slots between 40-60\n";
	print "   $0 -h hscroot\@hmcserver1 -m p520 -r 40-60 -v -d -s\n\n";
	exit 1;
}

getopts ("vfdsl:r:h:m:", \%opts );
$hmc = $opts{h};
$system = $opts{m};
$lpar = $opts{l};
$range = $opts{r};
if($range){
  if ($range =~ /(\d+)-(\d+)/){
    $min = $1;
    $max = $2;
  }else{
    print "unrecognized option for -r flag:  $range\n";
    print "specify range of VIO server slots with an option like this:   -r 40-60\n";
    exit 3;
  }
}
if ($opts{d}) {$dotmode = 1;}else{$dotmode = 0;}

if ( ($hmc eq "") || ($system eq "") ){ showusage();}
if ($opts{v} && $opts{f}) {showusage();}
if (! $opts{v} && ! $opts{f}) {showusage();}
if ($opts{v}) {$mode = "VSCSI";}
if ($opts{f}) {$mode = "VFC";}

sub printnd{
  my $s = $_[0];
  if (! grep /\Q$s/, %d){
    print "$s";
    $d{$s} = "";
  }
}

if ($dotmode){ print "graph ${mode}_slots {\n"; }
if ($dotmode && $opts{s}){ print "rankdir=LR\n"; }

if ($mode eq "VSCSI"){
	@out = `ssh -q -o "BatchMode yes" $hmc 'lshwres -r virtualio --rsubtype scsi -m $system -F adapter_type,lpar_name,slot_num,state,remote_lpar_name,remote_slot_num | sort -r'`;
}
if ($mode eq "VFC"){
	@out = `ssh -q -o "BatchMode yes" $hmc 'lshwres -r virtualio --rsubtype fc --level lpar -m $system -F adapter_type,lpar_name,slot_num,state,remote_lpar_name,remote_slot_num | sort -r'`;
}

if ($#out == -1) {
  print "Error running command on HMC.  Verify SSH keys, HMC server name, and managed system names are correct.\n";
  exit 2;
}
foreach $line (@out){
  if ($line =~ /(\S+),(\S+),(\d+),(\d+),(\S*),(\S+)/){
    my $type  = $1;
    my $llpar = $2;
    my $lslot = $3;
    my $state = $4;
    my $rlpar = $5;
    my $rslot = $6;
    if ($type eq "client") {
      if (($lpar) && ($llpar ne $lpar)) {next;}
      if (($min) && ($rslot < $min)) {next;}
      if (($max) && ($rslot > $max)) {next;}
      push(@{$cslots{$ccount}}, $type,$llpar,$lslot,$state,$rlpar,$rslot);
      $ccount++;
    }elsif ($type eq "server"){
      if (($lpar) && ($rlpar ne $lpar)) {next;}
      if (($min) && ($lslot < $min)) {next;}
      if (($max) && ($lslot > $max)) {next;}
      push(@{$sslots{$scount}}, $type,$llpar,$lslot,$state,$rlpar,$rslot);
      $scount++;
    }else {
      print "Error - unrecognized slot type: $type on $llpar / $lslot \n";
    }
  }
}

foreach $skey (keys %sslots){
  my $match = "false";
  foreach $ckey (keys %cslots){
    # 0  -  type
    # 1  -  local lpar
    # 2  -  local slot
    # 3  -  state
    # 4  -  remote lpar
    # 5  -  remote slot
    # server remote lpar == client local lpar || server remote slot == any  &&
    # server local lpar  == client remote lpar &&
    # server remote slot == client local slot || server remote slot == any &&
    # server local slot  == client remote slot

    if (((@{$sslots{$skey}}[4] eq @{$cslots{$ckey}}[1]) || (@{$sslots{$skey}}[5] eq "any" )) && 
       ((@{$sslots{$skey}}[1] eq @{$cslots{$ckey}}[4])) && 
       ((@{$sslots{$skey}}[5] eq @{$cslots{$ckey}}[2])  || (@{$sslots{$skey}}[5] eq "any" ))  &&
       ((@{$sslots{$skey}}[2] eq @{$cslots{$ckey}}[5]))) {
         $match = "true";
         if ($dotmode){
           if (! exists $vios{@{$sslots{$skey}}[1]} ){
             push(@{$vios{@{$sslots{$skey}}[1]}}, $viocount);
             if ($viocount  % 2 ne 0) { 
               push(@{$vios{@{$sslots{$skey}}[1]}}, "#87CEEB");
             }else{
               push(@{$vios{@{$sslots{$skey}}[1]}}, "#90EE90");
             }
             $viocount++;
           }
           if (@{$vios{@{$sslots{$skey}}[1]}}[0] % 2 eq 0) {
             printnd "\"@{$sslots{$skey}}[1]\" -- \"@{$sslots{$skey}}[1].@{$sslots{$skey}}[2]\"\n";
             printnd "\"@{$sslots{$skey}}[1].@{$sslots{$skey}}[2]\" -- \"@{$cslots{$ckey}}[1].@{$cslots{$ckey}}[2]\"\n";
             printnd "\"@{$cslots{$ckey}}[1].@{$cslots{$ckey}}[2]\" -- \"@{$cslots{$ckey}}[1]\" \n";
           }else{
             printnd "\"@{$cslots{$ckey}}[1]\" -- \"@{$cslots{$ckey}}[1].@{$cslots{$ckey}}[2]\"\n";
             printnd "\"@{$cslots{$ckey}}[1].@{$cslots{$ckey}}[2]\" -- \"@{$sslots{$skey}}[1].@{$sslots{$skey}}[2]\"\n";
             printnd "\"@{$sslots{$skey}}[1].@{$sslots{$skey}}[2]\" -- \"@{$sslots{$skey}}[1]\" \n"
           }
           printnd "\"@{$sslots{$skey}}[1]\" [label=\"@{$sslots{$skey}}[1]\", color=\"@{$vios{@{$sslots{$skey}}[1]}}[1]\", fontsize=14,fontcolor=black,style=filled];\n";
           if (@{$sslots{$skey}}[5] eq "any" ) {
             printnd "\"@{$sslots{$skey}}[1].@{$sslots{$skey}}[2]\" [label=\"$mode\\nServer Adapter\\nRemote Client: ANY\\nSlot: @{$sslots{$skey}}[2]\", color=\"#FFD700\", fontsize=14,fontcolor=black,style=filled];\n";
           }else{
             printnd "\"@{$sslots{$skey}}[1].@{$sslots{$skey}}[2]\" [label=\"$mode\\nServer Adapter\\nSlot: @{$sslots{$skey}}[2]\", color=\"@{$vios{@{$sslots{$skey}}[1]}}[1]\", fontsize=14,fontcolor=black,style=filled];\n";
           }
           printnd "\"@{$cslots{$ckey}}[1].@{$cslots{$ckey}}[2]\" [label=\"$mode\\nClient Adapter\\nSlot: @{$cslots{$ckey}}[2]\",color=\"@{$vios{@{$sslots{$skey}}[1]}}[1]\", fontsize=14,fontcolor=black,style=filled];\n";
           printnd "\"@{$sslots{$skey}}[1]\" [shape=box, label=\"@{$sslots{$skey}}[1]\", color=\"@{$vios{@{$sslots{$skey}}[1]}}[1]\", fontsize=14,fontcolor=black,style=filled];\n";
           printnd "\"@{$cslots{$ckey}}[1]\" [shape=box, label=\"LPAR\\n@{$cslots{$ckey}}[1]\", color=\"#A9A9A9\", fontsize=14,fontcolor=black,style=filled];\n";
         }else{
           printf "OK    @{$sslots{$skey}}[0] adapter %15s / %-5s", @{$sslots{$skey}}[1], @{$sslots{$skey}}[2];
           printf " -> %15s / %-5s\n",  @{$cslots{$ckey}}[1], @{$cslots{$ckey}}[2];
         }
    }
  }
  if ($match eq "false") { 
    $error  = sprintf "@{$sslots{$skey}}[0] adapter %15s / %-5s", @{$sslots{$skey}}[1], @{$sslots{$skey}}[2];
    $error .= sprintf " isn't a complete pair, client: @{$sslots{$skey}}[4] / @{$sslots{$skey}}[5]\n";
    $doterror .= "$error";    
    if (! $dotmode) {print "ERROR $error"};
  }
}

foreach $ckey (keys %cslots){
  my $match = "false";
  foreach $skey (keys %sslots){
    if (((@{$sslots{$skey}}[4] eq @{$cslots{$ckey}}[1]) || (@{$sslots{$skey}}[5] eq "any" )) &&
        ((@{$sslots{$skey}}[1] eq @{$cslots{$ckey}}[4])) &&
        ((@{$sslots{$skey}}[5] eq @{$cslots{$ckey}}[2])  || (@{$sslots{$skey}}[5] eq "any" ))  &&
        ((@{$sslots{$skey}}[2] eq @{$cslots{$ckey}}[5]))) {
          $match = "true";
          if (! $dotmode){
            printf "OK    @{$cslots{$ckey}}[0] adapter %15s / %-5s", @{$cslots{$ckey}}[1], @{$cslots{$ckey}}[2];
            printf " -> %15s / %-5s\n", @{$cslots{$ckey}}[4], @{$cslots{$ckey}}[5];
          }
      }
    }
    if ($match eq "false") { 
    $error  = sprintf "@{$cslots{$ckey}}[0] adapter %15s / %-5s", @{$cslots{$ckey}}[1], @{$cslots{$ckey}}[2];
    $error .= sprintf " isn't a complete pair, server: @{$cslots{$ckey}}[4] / @{$cslots{$ckey}}[5]\n"; 
    $doterror .= "$error";
    if (! $dotmode) {print "ERROR $error"};
  }
}

if ($dotmode){ 
  if ($doterror ne "Warning: following slots not setup correctly:\\n"){
    $doterror =~ s/\r?\n/\\n/g;
    print "\"doterrors\" [ shape=box, label=\"$doterror\", color=\"#FF0000\", fontsize=14, fontcolor=black, style=filled];\n";
  }
  print "labelloc=\"t\"\n";
  print "label=\"pslot_${mode} by Brian Smith\"\n";
  print "}\n"; 
}
