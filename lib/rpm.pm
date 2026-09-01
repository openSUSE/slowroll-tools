use strict;

# helpers for rpms and rpm-md repository metadata

# An OBS disturl looks like
#   obs://build.opensuse.org/openSUSE:Factory/standard/<md5>-<package>
# where <package> can carry a multibuild flavor, e.g. adwaita-qt:qt6

# disturl -> the package name OBS knows.
# This is the only reliable way to get from a binary rpm back to the package
# it was built from. The binary name is not it, and neither is %{sourcerpm}:
# OBS package adwaita-qt builds a binary called adwaita-qt6 whose
# %{sourcerpm} is adwaita-qt6-src, and none of those three names are equal.
sub disturl2pkg($)
{ my $disturl = shift;
    return undef unless defined($disturl);
    return undef unless $disturl =~ m,/[0-9a-f]+-([^/]+)$,;
    my $pkg = $1;
    $pkg =~ s/:.*//; # drop the multibuild flavor
    return $pkg;
}

# disturl -> the source revision it was built from
sub disturl2rev($)
{ my $disturl = shift;
    return undef unless defined($disturl);
    return $disturl =~ m,/([0-9a-f]+)-[^/]+$, ? $1 : undef;
}

# repodata is published as .gz or .zst depending on the repo
sub decompressor($)
{ my $filename = shift;
    return $filename =~ m/\.gz$/ ? 'gzip' : 'zstd';
}

# tools/getprimary only re-downloads when repomd.xml changed, but it keeps
# every hashed primary it ever fetched. Drop the ones we no longer link to.
sub prune_old_primaries($$)
{ my ($dir, $current) = @_;
    my $keep = (stat($current))[1] or return;
    for my $f (glob("$dir/*-primary.xml.*")) {
        next if (stat($f))[1] == $keep;
        diag("pruning stale $f");
        unlink($f);
    }
}

1;
