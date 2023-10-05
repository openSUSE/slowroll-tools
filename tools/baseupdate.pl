#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only
# run after tools/getrepoviews to have a fresh cache of package versions
use strict;
use lib "lib";
use common;

our $dryrun = 0;#$ENV{DRYRUN}//1;

my %repo;
for my $repo (qw(factory slob slo slos)) {
    $repo{$repo} = load_json("cache/view/$repo.json");
}

sub submit($$)
{ my ($pkg, $rev) = @_;
    if(!$dryrun) {
        my $src  = "openSUSE:Factory";
        my $dest = "openSUSE:ALP:Experimental:Slowroll:Base";
        print "osc release $src --target-project=$dest '$pkg' --target-repository=standard -r standard\n";
        #system("tools/releasepackage", $pkg, $rev);
    }
}

foreach my $pkg (sort keys (%{$repo{factory}})) {
    next if $pkg=~/:/;
    my $repopkg = $repo{factory}{$pkg};
    next unless $repopkg;
    my $slorepopkg = $repo{slob}{$pkg};
    my $rev=$repopkg->{md5};
    if($slorepopkg && $slorepopkg->{md5} eq $rev) {
        diag("skip already submitted");
	next;
    }
    diag "submit $pkg $rev now";
    submit($pkg, $rev);
}
