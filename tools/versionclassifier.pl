#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only
use strict;
use JSON::XS;
use lib "lib";
use common;
use cmpver;

my @files = @ARGV;
#print "@files\n";
my @jsons = ();
foreach my $fname (@files) {
    push(@jsons, load_json($fname));
}

my %pkgdata = ();
foreach my $pkg (sort keys (%{$jsons[0]})) {
    my $p0 = $jsons[0]->{$pkg};
    my $vercmp = 255;
    my $ver1 = "";
    if (exists $jsons[1]{$pkg}) {
        my $p1 = $jsons[1]->{$pkg};
        $ver1 = $p1->{version}{ver};
        $vercmp = cmpversion($p0->{version}, $p1->{version});
    }
    #print STDERR join("\t", $p0->{time}, $vercmp, $pkg, $p0->{version}{ver}, $ver1), "\n";
    $pkgdata{$pkg} = {
         time=>$p0->{time},
         vercmp=>$vercmp,
    };
}
print encode_pretty_json(\%pkgdata);
