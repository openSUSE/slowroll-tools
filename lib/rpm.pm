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

1;
