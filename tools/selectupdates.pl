#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only
use strict;
use JSON::XS;
use constant DAY => 86400;

our $dryrun = 1;
our @delay = (8*DAY);

sub haddelay($$)
{ my ($timestamp, $delay) = @_;
    print STDERR "$delay $timestamp\n"; # debug
    return ((time - $timestamp) > $delay);
}

sub submit($)
{ my ($pkg) = @_;
    print "submitting $pkg\n";
    if(!$dryrun) {
        system("tools/submitpackageupdate", $pkg);
    }
}

sub load_json($)
{ my $filename = shift;
    open(F, '<', $filename) or die $!;
    my $json;
    local $/=undef; $json=<F>;
    return decode_json($json);
}

my $versionclass = load_json("out/versionclass.json");
my $pkgmapdepcount = load_json("out/pkgmapdepcount");
#my $pkgmapsrcbin = load_json("out/pkgmapsrcbin");
#my %pkgmapbinsrc = ();
#foreach my $src (sort keys %$pkgmapsrcbin) {
#    foreach my $bin (@{$pkgmapsrcbin->{$src}}) {
#        $pkgmapbinsrc{$bin} = $src;
#    }
#}

sub getdepcount($)
{ my $pkg = shift;
    return $pkgmapdepcount->{$pkg}||0;
}

foreach my $pkg (sort keys (%{$versionclass})) {
    my $p = $versionclass->{$pkg};
    my $vercmp = $p->{vercmp};
    my $deps = getdepcount $pkg;
    if($vercmp == 255) {
        print "found new package $pkg - submitting right away\n";
        submit($pkg);
    } elsif ($vercmp == 65) {
        my $d = haddelay($p->{time}, $delay[0])||0;
        print "openSUSE patch update in $pkg $d $deps\n";
        if(!$d) { print "wait some longer with the update\n"; next }
        # patch-updates should remain compatible
        submit($pkg);
    } elsif ($vercmp == 63) {
        my $d = haddelay($p->{time}, $delay[0])||0;
        print "upstream patchlevel update in $pkg $d $deps\n";
        if(!$d) { print "wait some longer with the update\n"; next }
        # patchlevel-updates should remain compatible
        submit($pkg);
    }
        # TODO: check core-ness of $pkg
}
