#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only
use strict;
use JSON::XS;

sub cmpverpart($$)
{ my ($v1, $v2) = @_;
    return 0 if $v1 eq $v2;
    my @v1 = split("[-._+~]", $v1);
    my @v2 = split("[-._+~]", $v2);
    for my $i (0..$#v1) {
        if($v1[$i] ne $v2[$i]) {
            return 1+$i;
        }
    }
    return 63;
}

sub cmpversion($$)
{ my ($v1, $v2) = @_;
    if($v1->{epoch} ne $v2->{epoch}) {
        return 1;
    } elsif(my $pv = cmpverpart($v1->{ver}, $v2->{ver})) {
        return $pv;
    } elsif(my $pr = cmpverpart($v1->{rel}, $v2->{rel})) {
        return $pr+64;
    } else {
        return 0;
    }
}


my @files = <cache/*/primary.pkgs>;
#print "@files\n";
my @jsons = ();
foreach my $fname (@files) {
    open(my $f, "<", $fname) or die "error reading $fname";
    local $/=undef;
    my $json = <$f>;
    push(@jsons, decode_json $json);
}

foreach my $pkg (sort keys (%{$jsons[0]})) {
    my $p0 = $jsons[0]->{$pkg};
    print "$pkg $p0->{version}{ver} ";
    if (exists $jsons[1]{$pkg}) {
        my $p1 = $jsons[1]->{$pkg};
        my $vercmp = cmpversion($p0->{version}, $p1->{version});
        print "$p1->{version}{ver} $vercmp\n";
    } else {
        print "\n";
    }
}

