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

sub load_json($)
{ my $filename = shift;
    return decode_json(load_file($filename));
}

sub encode_pretty_json($)
{
    my $coder = JSON::XS->new->pretty->canonical;
    $coder->encode(shift);
}

sub cache_or_run($&)
{ my ($cachefilename, $sub) = @_;
    if(-e $cachefilename) {
        return load_file($cachefilename);
    } else {
        my $ret = &$sub;
        store_file($cachefilename, $ret);
        return $ret
    }
}

1;
