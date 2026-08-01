#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only
# zypper -n in perl-XML-Bare perl-JSON-XS

use strict;
use XML::Bare;
use JSON::XS;
use FindBin;
use lib "$FindBin::RealBin/../lib"; # tools/diffdistro runs us from cache/*/
use rpm;
$|=1;
my $xmlgz = shift;
# optional: only keep packages of this arch. The update repo indexes binaries
# and sources in one primary.xml, and we want the source names from it.
my $wantarch = shift;
my $decompressor = decompressor($xmlgz);
my $xml = `$decompressor -cd $xmlgz`;
my $ref = new XML::Bare(text => $xml) ->parse();
my $coder = JSON::XS->new->pretty->canonical;
#print $coder->encode($ref);


my $pkgs = $ref->{metadata}->{package};
my %extract=();
foreach my $pkg (@$pkgs) {
  #print("$pkg->{name}{value} $pkg->{version}{ver}{value} $pkg->{version}{rel}{value} $pkg->{location}{href}{value} $pkg->{format}{'rpm:sourcerpm'}{value} $pkg->{time}{file}{value}\n");
  #die;
  next if defined($wantarch) && ($pkg->{arch}{value}//'') ne $wantarch;
  $extract{$pkg->{name}{value}} = {
    version => {
    epoch => $pkg->{version}{epoch}{value},
    ver => $pkg->{version}{ver}{value},
    rel => $pkg->{version}{rel}{value},
    },
    href => $pkg->{location}{href}{value},
    time => $pkg->{time}{file}{value},
  }
}

print $coder->encode(\%extract);
