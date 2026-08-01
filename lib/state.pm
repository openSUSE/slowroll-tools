use strict;
use common;

# Per-package record of which version we put into which project.
#
#   state/<project>/<package>    one key=value per line
#
# One file per package on purpose: every writer touches exactly one package, so
# a temp file plus rename is atomic and no locking is needed anywhere.
#
# These files are NEVER sourced or eval'd. The values come out of rpm and OBS
# metadata, and "package naming conventions forbid that character" is not a
# security boundary - so both writing and reading validate, and the shell
# accessor (tools/pkgstate) prints one bare value at a time rather than
# key=value text that a caller might be tempted to eval.

our $statedir = $ENV{statedir} || 'state';

our $KEY_RE = qr/\A[a-z]+\z/;
our $VAL_RE = qr{\A[a-zA-Z0-9:._+@~/-]*\z};

sub state_dir($)
{ my $prj = shift;
    die "invalid project name '$prj'" unless defined($prj) && $prj =~ $VAL_RE && length($prj);
    return "$statedir/$prj";
}

sub state_file($$)
{ my ($prj, $pkg) = @_;
    die "invalid package name '$pkg'" unless defined($pkg) && $pkg =~ $VAL_RE && length($pkg);
    die "invalid package name '$pkg'" if $pkg =~ m{/} || $pkg =~ m/\A\./;
    return state_dir($prj)."/$pkg";
}

# -> hashref, empty if we have no record
sub state_load($$)
{ my ($prj, $pkg) = @_;
    my $f = state_file($prj, $pkg);
    return {} unless -e $f;
    my %h;
    for my $line (split("\n", load_file($f))) {
        next unless length($line);
        my ($k, $v) = $line =~ m/\A([a-z]+)=(.*)\z/;
        if(!defined($k) || $v !~ $VAL_RE) {
            diag("ignoring unparsable line in $f: $line");
            next;
        }
        $h{$k} = $v;
    }
    return \%h;
}

sub state_store($$$)
{ my ($prj, $pkg, $h) = @_;
    my $f = state_file($prj, $pkg);
    my $out = '';
    for my $k (sort keys %$h) {
        my $v = $h->{$k};
        next unless defined($v);
        die "invalid state key '$k' for $prj/$pkg" unless $k =~ $KEY_RE;
        die "invalid state value for $k of $prj/$pkg: '$v'" unless $v =~ $VAL_RE;
        $out .= "$k=$v\n";
    }
    my $dir = state_dir($prj);
    system('mkdir', '-p', $dir) == 0 or die "cannot create $dir\n";
    store_file("$f.new", $out);
    rename("$f.new", $f) or die "error writing $f : $!";
    return 1;
}

# merge new fields into whatever is already recorded
sub state_update($$$)
{ my ($prj, $pkg, $h) = @_;
    my $old = state_load($prj, $pkg);
    return state_store($prj, $pkg, {%$old, %$h});
}

sub state_list($)
{ my $prj = shift;
    my $dir = state_dir($prj);
    opendir(my $dh, $dir) or return ();
    my @pkgs = sort grep { !m/\A\./ && !m/\.new\z/ && -f "$dir/$_" } readdir($dh);
    closedir($dh);
    return @pkgs;
}

1;
