#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only
# usage: tools/versionclassifier.pl [--state PRJ] TUMBLEWEED.pkgs SLOWROLL.pkgs [MORE.pkgs ...]
#
# Classifies how far each Tumbleweed package is from what Slowroll has.
# The first file is Tumbleweed; every other file, plus the optional state
# directory of a project, is somewhere Slowroll might already have the package.
# We report the *closest* of them to Tumbleweed, because a package that was
# updated out of band is no longer at the base snapshot version and should not
# keep being classified as a major update forever.

use strict;
use JSON::XS;
use lib "lib";
use common;
use cmpver;
use state;

my $stateprj;
my @files;
while(defined(my $a = shift @ARGV)) {
    if($a eq '--state') { $stateprj = shift @ARGV }
    else { push(@files, $a) }
}
die "usage: $0 [--state PRJ] TW.pkgs SLO.pkgs [...]\n" unless @files >= 2;

my $tw = load_json(shift @files);
my @slo = map { load_json($_) } @files;

# cmpversion says *where* two versions differ, not which is bigger: 0 is
# identical, 255 is absent, and otherwise a larger number means the difference
# is further right, i.e. smaller. So rank by closeness to Tumbleweed and keep
# the best - no rpm version comparison needed.
sub rank($)
{ my $v = shift;
    return 1e9 if $v == 0;
    return -1 if $v == 255;
    return $v;
}

my %pkgdata = ();
foreach my $pkg (sort keys (%$tw)) {
    my $vercmp = 255;
    for my $j (@slo) {
        next unless exists $j->{$pkg};
        my $v = cmpversion($tw->{$pkg}{version}, $j->{$pkg}{version});
        $vercmp = $v if rank($v) > rank($vercmp);
    }
    if(defined $stateprj) {
        if(my $sv = state_version($stateprj, $pkg)) {
            my $v = cmpversion($tw->{$pkg}{version}, $sv);
            diag("$pkg: state says $sv->{ver}-$sv->{rel} -> vercmp $v") if $v != $vercmp;
            $vercmp = $v if rank($v) > rank($vercmp);
        }
    }
    $pkgdata{$pkg} = {
         time=>$tw->{$pkg}{time},
         # 0+ so this is always a JSON number: interpolating it into the diag
         # above would otherwise make JSON::XS emit it as a string
         vercmp=>0+$vercmp,
    };
}
print encode_pretty_json(\%pkgdata);
