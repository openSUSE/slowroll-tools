use Fcntl qw(:flock);

sub lock($) {
    my ($fname) = @_;
    open(my $fh, ">>", $fname) or die "Cannot open lockfile $fname - $!";
    flock($fh, LOCK_EX) or die "Cannot lock $fname - $!\n";
    print $fh $$,"\n";
    return $fh;
}

sub unlock($) {
    my ($fh) = @_;
    truncate($fh, 0);
    flock($fh, LOCK_UN) or die "Cannot unlock - $!\n";
}

1;
