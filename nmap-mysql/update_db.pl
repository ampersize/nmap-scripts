use strict;
use warnings;

use DBI;

use constant DEBUG => 1;

if (! $ARGV[0]) {
	print "Please provide an input file!\n";
	exit;
}

# mysql connect
my $dbh = DBI->connect('DBI:mysql:nmap', 'username', 'passowrd') || die "Could not connect to database: $DBI::errstr";

# open file
open(FH, "< $ARGV[0]");

while(<FH>) {
        my $line = $_;
        chomp($line);
        if ($line =~ /Status: /) {
                my (undef, $ip, $hostname, undef, $status) = split(" ", $line);
                print "[dd] Found $ip $hostname with status $status\n" if DEBUG;
		$hostname =~ s/\(|\)//g;
		# check if we already know this port
		my $query;
		my $th = $dbh->prepare(qq{SELECT COUNT(1) FROM hosts WHERE ip='$ip'});
		$th->execute();
		if ($th->fetch()->[0]) {
			$query = "UPDATE hosts SET hostname = '$hostname', status = '$status' WHERE ip = '$ip';";
		} else {
			$query = "INSERT into hosts (ip,hostname,status) VALUES ('$ip','$hostname', '$status');";
		}
		$th = $dbh->prepare(qq{$query});
		$th->execute();
        } elsif ( $line =~ /Ports: / ) {
                my (undef, $ip, $dns, undef, undef) = split(" ", $line);
		$line =~ s/.*Ports: //;
		my @services = split(",", $line);
		foreach my $service (@services) {
			my ( $port, $status, $proto, undef, $name, undef, $desc) = split("/", $service);
			$desc =~ s/'//g;
			print "[dd] Found a service which is $status on $ip - $port / $proto!\n" if DEBUG;
			my $query;
			my $th = $dbh->prepare(qq{SELECT COUNT(1) FROM services WHERE ip='$ip' and port='$port' and protocol='$proto'});
			$th->execute();
			if ($th->fetch()->[0]) {
				$query = "UPDATE services SET status='$status', description='$desc' WHERE ip='$ip' and port='$port' and protocol='$proto';";
			} else {
				$query = "INSERT into services (port,ip,name,protocol,status,description) VALUES ('$port','$ip','$name','$proto','$status','$desc');";
			}
			$dbh->do($query);
		}
	} else {
                next;
        }
}

# done
close(FH);
$dbh->disconnect();

