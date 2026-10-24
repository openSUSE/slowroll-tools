use strict;
use common;

our (%coupledupdate, %coupledrebuild); # trigger pkg => [coupled pkgs]
for (["updates", \%coupledupdate], ["rebuilds", \%coupledrebuild]) {
    my ($file, $map) = @$_;
    for my $group (@{load_list_of_lists("in/coupled-$file")}) {
        my ($trigger, @rest) = @$group;
        push(@{$map->{$trigger}}, @rest);
    }
}
our $neverupdate = load_list_map "in/never-update-exceptions";
our %submittednow; # avoid double-submits and endless coupling recursion

# returns exit code
sub submitsingle($$$)
{ my ($pkg, $rev, $force) = @_;
    local $ENV{FORCE} = $force ? 1 : "";
    system("tools/submitpackageupdatesingle", $pkg, $rev);
    die "$pkg: $!\n" if $? == -1;
    die "$pkg: killed by signal ".($? & 127)."\n" if $? & 127;
    return $? >> 8;
}

# $submitone->($pkg, $rev, $force) returns exit code, 0 triggers coupled pkgs
sub submitcoupled($$$;$);
sub submitcoupled($$$;$)
{ my ($pkg, $rev, $force, $submitone) = @_;
    $submitone //= \&submitsingle;
    return 0 if $submittednow{$pkg}++;
    my $ret = $submitone->($pkg, $rev, $force);
    return $ret if $ret;
    for my $coupled (@{$coupledupdate{$pkg} // []}) {
        next if $neverupdate->{$coupled};
        diag "updating $coupled coupled to $pkg";
        submitcoupled($coupled, "latest", 0, $submitone);
    }
    for my $coupled (@{$coupledrebuild{$pkg} // []}) {
        next if $neverupdate->{$coupled};
        next if $submittednow{$coupled}++;
        print "rebuilding $coupled coupled to $pkg\n";
        $submitone->($coupled, "latest", 1);
    }
    return 0;
}

1;
