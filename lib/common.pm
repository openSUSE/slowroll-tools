use strict;
use JSON::XS;

sub load_file($)
{ my $filename = shift;
    open(my $f, '<', $filename) or die "error reading $filename : $!";
    local $/=undef; 
    return scalar <$f>;
}

sub store_file($$)
{ my ($filename, $data) = @_;
    open(my $f, '>', $filename) or die "error writing $filename : $!";
    print $f $data;
    close $f;
}

sub load_list_map($)
{
    my %ret;
    for my $line (split("\n", load_file(shift))) {
        $line =~ s/#.*//; # our in/ lists document themselves in comments
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next unless length($line);
        $ret{$line} = 1;
    }
    return \%ret;
}

# load a file with a space-separated group of words per line
sub load_list_of_lists($)
{
    my @ret;
    for my $line (split("\n", load_file(shift))) {
        $line =~ s/#.*//; # our in/ lists document themselves in comments
        my @words = split(' ', $line);
        push(@ret, \@words) if @words;
    }
    return \@ret;
}

sub load_json($)
{ my $filename = shift;
    return decode_json(load_file($filename));
}

sub encode_pretty_json($)
{
    my $coder = JSON::XS->new->pretty->canonical;
    $coder->encode(shift);
}

# check freshness of a cache file
sub is_fresh($$)
{ my ($cachefilename, $expiry) = @_;
    $expiry //= 7*24*60*60; # default 7d
    my $mtime = (stat($cachefilename))[9];
    return $mtime + $expiry > time;
}

sub cache_or_run($&;$)
{ my ($cachefilename, $sub, $expiry) = @_;
    if(-e $cachefilename && is_fresh($cachefilename, $expiry)) {
        return load_file($cachefilename);
    } else {
        my $ret = &$sub;
        store_file($cachefilename, $ret);
        return $ret
    }
}

sub min($$) {
    return ($_[0] < $_[1])?$_[0]:$_[1];
}

sub diag($) {
    print STDERR $_[0],"\n" if $ENV{DEBUG};
}

1;
