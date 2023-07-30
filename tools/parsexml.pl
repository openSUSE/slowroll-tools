#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only
# zypper -n in perl-XML-Bare perl-JSON-XS

use strict;
use XML::Bare;
use JSON::XS;
my $xmlgz = shift;
my $xml = `gzip -cd $xmlgz`;
my $ref = new XML::Bare(text => $xml) ->parse();
my $coder = JSON::XS->new->pretty->canonical;
#print $coder->encode($ref);


my $pkgs = $ref->{metadata}->{package};
foreach my $pkg (@$pkgs) {
  print("$pkg->{name}->{value} $pkg->{version}->{ver}->{value} $pkg->{version}->{rel}->{value} $pkg->{format}->{'rpm:sourcerpm'}->{value} $pkg->{time}->{file}->{value}\n");
  #die;
}
