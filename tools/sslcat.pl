#!/usr/bin/perl -w
use strict;
use IO::Socket::SSL;
$|=1;
our $apisock;

sub openapisock() {
    $apisock = IO::Socket::SSL->new($ENV{OBSAPI}||'api.opensuse.org:443');
}

sub diag($)
{
    #print(@_, "\n");
}

my $listensock = IO::Socket::INET->new(
	LocalAddr => '127.0.0.1:40080',
	ReusePort => 1,
	Listen => 10,
);

sub readheaders($)
{ my $sock = shift;
    my @req;
    while(my $line=<$sock>) {
        diag "< $line";
        push(@req, $line);
        last if($line=~m/^\r?\n/);
    }
    return @req;
}
sub parseheaders(@)
{
    my %header = ();
    foreach(@_) {m/^([^:]+): ([^\r\n]*)/ and $header{lc($1)}=$2}
    return \%header;
}

my $lasttime = 0;

while(my $sock=$listensock->accept) {
    # read request
    my @req = readheaders($sock);
    my $reqheader = parseheaders(@req);
    my $reqdata = "";
    if(defined $reqheader->{"content-length"}) {
        read($sock, $reqdata, $reqheader->{"content-length"});
    }
    #print "Full Req: @req\n"
    # forward request
    openapisock if ! $apisock || $lasttime<time-15;
    my $ret = print $apisock @req,$reqdata;
    diag "API ret: $ret";
    # read response
    my @respheaders = readheaders($apisock);
    if(!@respheaders) { # old socket expired - need to re-open and retry
        openapisock;
        print $apisock @req;
        @respheaders = readheaders($apisock);
    }
    diag "API headers: ".scalar(@respheaders);
    $lasttime = time;
    my $respheader = parseheaders(@respheaders);
    my $respdata="";
    if(defined $respheader->{"content-length"}) {
        read($apisock, $respdata, $respheader->{"content-length"});
    } elsif($respheader->{"transfer-encoding"} eq "chunked") {
        my $bytes;
        while(1) {
            $bytes = <$apisock>;
            $respdata.=$bytes;
            $bytes =~ s/\r\n//;
            diag("reading 0x$bytes response body");
            read($apisock, $respdata, hex($bytes), length($respdata)) if hex($bytes);
            diag("respdata=$respdata");
            my $crlf = <$apisock>;
            $respdata.=$crlf;
            last if(hex($bytes) <= 0);
        }
        diag("done reading response");
    }
    # forward response
    print $sock @respheaders,$respdata
}
