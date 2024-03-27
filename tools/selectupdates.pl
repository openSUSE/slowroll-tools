#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only
use strict;
use JSON::XS;
use LWP::Simple qw(get);
use IO::Uncompress::Gunzip qw(gunzip);
use constant DAY => 86400;
use lib "lib";
use common;

our $dryrun = $ENV{DRYRUN}//1;
our @delay = (8*DAY, 80*DAY, 150*DAY);
our $changelogurl = 'http://stage3.opensuse.org:18080/cgi-bin/getchangelog?path=';
our @baseurl = ('/source/tumbleweed/repo/oss/', # needs trailing slash
        '/slowroll/repo/src-oss/');
our $changelogdir = "cache/changelog";
our %exceptions;
for my $t ("major", "minor", "never") {
    $exceptions{$t} = load_list_map "in/$t-update-exceptions";
}

sub haddelay($$)
{ my ($timestamp, $delay) = @_;
    diag "$delay $timestamp"; # debug
    return ((time - $timestamp) > $delay);
}

my %repo;
for my $repo (qw(factory slo slos)) {
    $repo{$repo} = load_json("cache/view/$repo.json");
}
my $versionclass = load_json("out/versionclass.json");
my $pkgmapdepcount = load_json("out/pkgmapdepcount");
my @pkgs;
foreach(qw(tumbleweed slowroll)) { push(@pkgs, load_json("cache/$_/primary.pkgs")) }
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


sub getdiff($)
{ my $pkg = shift;
    my @url;
    my @p;
    my @changelog;
    my @changelogf;
    for my $i (0,1) {
        $p[$i] = $pkgs[$i]{$pkg};
        $url[$i] =  $baseurl[$i].$p[$i]{href};
        $changelogf[$i] = "$changelogdir/$i.$pkg-$p[$i]{version}{ver}-$p[$i]{version}{rel}";
    }
    mkdir($changelogdir);
    mkdir($changelogdir."diff");
    my $difffilename = "${changelogdir}diff/$pkg-$p[0]{version}{ver}-$p[0]{version}{rel}-$p[1]{version}{ver}-$p[1]{version}{rel}";
    diag "getdiff @url $difffilename";
    my $diff = cache_or_run($difffilename, sub {
        for my $i (0,1) {
            $changelog[$i] = cache_or_run($changelogf[$i],
                #sub{ `rpm -qp --changelog $url[$i]` # too slow
                sub {
                    my $gz = get($changelogurl.$url[$i]);
                    my $c;
                    gunzip(\$gz, \$c);
                    return $c;
            });
        }
        return `diff -u $changelogf[1] $changelogf[0] | grep --text ^+[^+]`;
    });
    return $diff;
}

sub submit($$)
{ my ($pkg, $rev) = @_;
    print "submitting $pkg $rev\n";
    if(!$dryrun) {
        system("tools/submitpackageupdate", $pkg, $rev);
        # TODO store $pkgs[0]->{$pkg}{diff} for consumption by users - e.g. RSS feed
    }
}

foreach my $pkg (sort keys (%{$versionclass})) {
    my $repopkg = $repo{factory}{$pkg};
    next unless $repopkg;
    diag("checking $pkg");
    my $slorepopkg = $repo{slos}{$pkg} || $repo{slo}{$pkg} ;
    if($slorepopkg && $slorepopkg->{md5} eq $repopkg->{md5}) {
        diag("skip already submitted");
	next;
    }
    my $p = $versionclass->{$pkg};
    my $vercmp = $p->{vercmp};
    next unless $vercmp;
    next if $exceptions{never}{$pkg};
    my $deps = getdepcount $pkg;
    my $diff = getdiff($pkg) unless $vercmp == 255 or $vercmp == 66;
    if($vercmp == 255) {submit($pkg, "latest")}
    next unless $diff;
    $diff =~ m!\A\+"obs://build\.opensuse\.org/openSUSE:Factory/standard/([0-9a-f]*)!;
    my $rev = $1 // die "did not find disturl for $pkg";
    $pkgs[0]->{$pkg}{diff} = $diff;
    my $delay = $delay[0];
    if($vercmp == 255) {
        diag "found new package $pkg - submitting right away";
        $delay = 0;
    } elsif ($vercmp == 65) {
        diag "openSUSE patch update in $pkg $deps";
        # patch-updates should remain compatible
        $delay *= 0.7;
    } elsif ($vercmp == 63) {
        diag "upstream patchlevel update in $pkg $deps";
        # patchlevel-updates should remain compatible
    } elsif ($vercmp >= 3) {
        diag "upstream patchlevel update in $pkg $deps";
        # TODO patchlevel update
    } elsif ($vercmp == 2 && $exceptions{minor}{$pkg}) {
        diag "upstream minor update exception for $pkg"
    } elsif ($exceptions{major}{$pkg}) {
        diag "upstream major update exception for $pkg"
    } else {
        $delay = $delay[3-$vercmp];
    }
    if($diff =~ /(?:boo|bsc)#\d/) {
        $delay *= 0.7;
    }
    if($diff =~ /reproducible/i) { $delay *= 0.7 }
    if($diff =~ /CVE-20/) {
        if($vercmp >=3 or $delay<10*DAY) {
            $delay = 1;
        } else {
            print "Warning: CVE $diff waiting $delay - manual action might be needed\n";
	}
    }
    if($diff =~ /fixed/i) { $delay *= 0.9 }
    if($diff =~ /incompatib/i) { $delay *= 1.5 }
    # check core-ness of $pkg
    if($deps > 10000) {
        $delay *= 2;
    }
    # TODO: consider if a package is in SLE or DVD
    # TODO: consider open bugreports
    # TODO: consider if we need a new dep for $pkg - might not be declared in .spec
    if(!haddelay($p->{time}, $delay)) {
        diag "wait some longer with the update of $pkg";
        next
    }
    diag "Diff for $pkg: $diff\n----";
    diag "submit $pkg $rev now after $delay s delay";
    submit($pkg, $rev);
}
