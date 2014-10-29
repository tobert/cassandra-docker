#!/usr/bin/perl

=head1 NAME

cassandra-runner.pl - a script to configure & run Cassandra in Docker

=head1 SYNOPSIS

This program detects and sets up cassandra inside docker automatically.

/bin/cassandra-runner.pl [--conf yaml] [--data dir] [--name name] [--seeds ip] [--listen ip] [--xmx 1G] [--xmn 100M] [--noconfig] [--nomkdir] [--dump] [--showip]

    --conf specify the location of cassandra.yaml
    --data where to put the data directories
    --name cassandra cluster name
    --seeds comma separated list of gossip seeds
    --listen address to listen on (rpc, storage, jmx)
	--xmx set the JVM heap size (MAX_HEAP_SIZE)
	--xmn set the JVM new size (HEAP_NEWSIZE)
    --noconfig do not modify the config file
    --nomkdir do not create directories
    --dump dump the settings that will change in cassandra.yaml
    --showip show the IP of the container

Defaults:

    --conf /opt/cassandra/conf/cassandra.yml
    --data /var/lib/cassandra
    --name "Cassandra in Docker"
    --seeds <IP of the default interface>
    --listen <IP of the default interface>
	--xmx $ENV{MAX_HEAP_SIZE} / env.sh
	--xmn $ENV{HEAP_NEWSIZE} / env.sh

=head1 SETTINGS

A few settings can be provided and persisted across container executions in
the bound volume. A directory is created there called 'etc', so if you
docker run -v /tmp/foo:/var/lib/cassandra, you'll get a /tmp/foo/etc. There
are some files that are used to make persistent changes to the environment
without having to hack on the Docker image.

=over 4

=item env.sh

If this file exists, it will be spliced into cassandra-env.sh where the
MAX_HEAP_SIZE and HEAP_NEWSIZE settings usually go. If both --xmx and
--xmn are specified on the command line and no env.sh exists, it will
be created to persist those settings across containers. Once created,
env.sh is not overwritten.

   MAX_HEAP_SIZE=1G
   HEAP_NEWSIZE=100M

=back

=head1 TODO

Break up the main body into functions.

=head1 AUTHOR

Al Tobey <atobey@datastax.com>

=cut

use strict;
use warnings;
use YAML ();
use Getopt::Long;
use File::Spec;
use File::Path ();
use File::Copy ();
use Pod::Usage;
use POSIX;

our($confname, $storage, $name, $listen, $xmx, $xmn, $seeds);
our($opt_noconfig, $opt_nomkdirs, $opt_dump, $opt_showip, $opt_help);

# set it twice to silence useless warning
local $YAML::UseHeader = 0; $YAML::UseHeader = 0;

GetOptions(
	"conf:s"   => \$confname,
	"data:s"   => \$storage,
	"name:s"   => \$name,
	"seeds:s"  => \$seeds,
	"listen:s" => \$listen,
	"xmx"      => \$xmx,
	"xmn"      => \$xmn,
	"noconfig" => \$opt_noconfig,
	"nomkdirs" => \$opt_nomkdirs,
	"dump"     => \$opt_dump,
	"showip"   => \$opt_showip,
	"help"     => \$opt_help, "h" => \$opt_help
);

if ($opt_help) {
	pod2usage();
}

# defaults
$confname ||= "/opt/cassandra/conf/cassandra.yaml";
$storage  ||= "/var/lib/cassandra";
$listen   ||= get_default_ip();
$xmx      ||= $ENV{MAX_HEAP_SIZE};
$xmn      ||= $ENV{HEAP_NEWSIZE};
$seeds    ||= $ENV{SEEDS} || $listen;

# show the IP of the current machine and exit
# this defaults to the default interface, but can be overridden with --listen
if ($opt_showip) {
	print "$listen\n";
	exit 0;
}

my %new = (
	'data_file_directories'  => [File::Spec->catdir($storage, "data")],
	'commitlog_directory'    => [File::Spec->catdir($storage, "commit")],
	'saved_caches_directory' => File::Spec->catdir($storage, "saved_caches"),
	'rpc_address'            => $listen,
	'listen_address'         => $listen,
	'cluster_name'           => "Cassandra in Docker"
);

# rather than trying to find the right part of the data structure from the
# YAML, just overwrite the whole thing
$new{'seed_provider'} = [{
	'class_name' => 'org.apache.cassandra.locator.SimpleSeedProvider',
    'parameters' => [{ 'seeds' => $seeds }]
}];

# set up the state directory on the volume
our $statedir = File::Spec->catdir($storage, "etc");
File::Path::mkpath($statedir);
our $newconf = File::Spec->catfile($statedir, "cassandra.yaml");

# create directories on the volume
unless ($opt_nomkdirs) {
	foreach my $key (keys %new) {
		# cheezy: assume anything starting with / is a path to be made
		if ($key =~ /^\//) {
			File::Path::mkpath($new{$key});
		}
	}
}

# for debugging, print the config that will change and exit
if ($opt_dump) {
	print YAML::Dump(\%new);
	exit 0;
}

# generate a name for the old file
my $oldconf = $confname . ".orig";
if (-e $oldconf) {
	$confname = $oldconf;
}

# load the data from the original cassandra.yaml
my $confdata = slurp($confname);
my $conf = YAML::Load($confdata);

# work around bug with comments after YAML values
$conf->{'max_hint_window_in_ms'} = 10800000;

# copy modified values into the config hash
foreach my $key (keys %new) {
	$conf->{$key} = $new{$key};

	# write out the current values to the state dir
	unless (ref $new{$key}) {
		open(my $fh, "> $statedir/$key.txt") or next;
		print $fh $new{$key};
		close $fh;
	}
}

# rename the old file, but only if it's not the same name
if ($oldconf ne $confname && ! -e $oldconf) {
	rename($confname, $oldconf);
}

# write the new YAML out to the statedir
open(my $out, "> $newconf") or die "Could not open $confname for writing: $!";
print $out YAML::Dump($conf);
close $out;

# symlink into the original location
# this leaves the actual file visible from outside the container
# on the bind volume
unless ($opt_noconfig) {
	symlink($newconf, $confname);
}

my $envsh = File::Spec->catfile($statedir, "env.sh");

# create env.sh if it doesn't exist to persist the settings
# both xmx and xmn must be set for it to work, so only persist
# if they're both passed in
if (! -r $envsh && $xmx && $xmn) {
	open(my $cfh, "> $envsh") or die "Could not open $envsh for write: $!";
	print $cfh "MAX_HEAP_SIZE=\"$xmx\"\nHEAP_NEWSIZE=\"$xmn\"\n";
	close $cfh;
}

# if env.sh exists in the statedir, it will be spliced into
# cassandra-env.sh where the memory settings are normally made
# This was chosen over copying a full cassandra-env.sh to make
# it work across most releases of Cassandra without having to
# have users rewrite their cassandra-env.sh.
if (-r $envsh) {
	splice_cassandra_env("/opt/cassandra/conf/cassandra-env.sh", $envsh);
}

# write to a 'logs' directory next to the data dirs
my $logdir = File::Spec->catdir($storage, "logs");
unless (-d $logdir) {
	File::Path::mkpath($logdir);
}

# try to drop root privileges before running C*
# if it fails for whatever reason, continue as root
try_drop_root();

# start cassandra!
system("/opt/cassandra/bin/cassandra -f >$logdir/stdout 2>$logdir/stderr");

# sleep forever
while (1) {
	sleep 1;
}

# get the default IP of the machine at run time
# find the default route and use that if available
# if there isn't a default route (rare), use the first
# interface that has an rfc1918 address
sub get_default_ip {
	open(my $ifh, "/bin/ip route show |") or die "Could not execute /bin/ip route show: $!";
	my %routes;
	while (my $line = <$ifh>) {
		my @parts = split /\s+/, $line;
		for (my $i=0; $i<$#parts; $i++) {
			if ($parts[$i] eq "dev" && defined($parts[$i+1]) && length($parts[$i+1]) > 0) {
				if ($parts[$i+1] =~ /^(?:lo|dummy)/) {
					next;
				}

				$routes{$parts[0]} = $parts[$i+1];
				last;
			}
		}
	}
	close $ifh;

	my $iface = "eth0";
	if (exists $routes{default}) {
		$iface = $routes{default};
	}
	# otherwise, guess it's the first interface with an rfc1918 address
	else {
		foreach my $net (%routes) {
			if ($net =~ /^(?:192|172|10)\./) {
				$iface = $routes{$net};
			}
		}
	}

	my $address = "127.0.0.1";
	open(my $fh, "/bin/ip addr show $iface |") or die "Could not run /bin/ip addr show $iface: $!";
	while (my $line = <$fh>) {
		#    inet 192.168.42.10/24 brd 192.168.42.255 scope global enp10s0
		if ($line =~ /\s*inet\s+(\S+)\/\d+/) {
			$address = $1;
		}
	}
	close $fh;

	return $address;
}

sub slurp {
	my $file = shift;
	open(my $fh, "< $file") or die "could not open $file for read: $!";
	local $/ = undef;
	my $data = <$fh>;
	close $fh;
	return $data;
}

# get the uid/gid for cassandra:cassandra if available otherwise return 0,0
# The DSC packages create a cassandra user/group so it should always
# run as a user.
sub get_user_ids {
	my $ids = [0,0];
	open(my $pfh, "< /etc/passwd") or return($ids);
	while (my $line = <$pfh>) {
		my @u = split /:/, $line;
		if ($u[0] eq "cassandra") {
			$ids->[0] = $u[2];
			$ids->[1] = $u[3];
			last;
		}
	}
	close $pfh;
	return $ids;
}

sub try_drop_root {
	my $ids = get_user_ids();
	if ($ids->[0] == 0) {
		return;
	}

	system("chown -R $ids->[0]:$ids->[1] $storage");
	POSIX::setgid($ids->[1]);
	POSIX::setuid($ids->[0]);
}

sub splice_cassandra_env {
	my($target, $envsh) = @_;

	open(my $in, "< $target") or die "Could not open $target for read: $!";

	my $buf = "";
	my $in_old_envsh = undef;
	while (my $line = <$in>) {
		if ($in_old_envsh) {
			if ($line =~ /^# ____END_ENVSH____/) {
				$in_old_envsh = undef;
				next;
			}
		}

		# skip the old envsh block
		if ($line =~ /^# ____BEGIN_ENVSH____/) {
			$in_old_envsh = 1;
			next;
		}

		# this has to be there or there's no other good way to find
		# the right place in the file to inject the code :/
		if ($line =~ /^\s*#?\s*MAX_HEAP_SIZE=.*$/) {
			$buf .= "\n\n# ____BEGIN_ENVSH____\n";
			$buf .= slurp($envsh);
			$buf .= "\n# ____END_ENVSH____\n\n";
		}

		$buf .= $line;
	}
	close $in;

	open(my $out, "> $target") or die "Could not open $target for write: $!";
	print $out $buf;
	close $out;
}

# vim: et ts=4 sw=4 ai smarttab
