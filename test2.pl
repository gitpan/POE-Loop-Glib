use Glib;
use POE;


use Data::Dumper;
print Dumper \%INC;
my $count;
my $session = POE::Session->create (
	inline_states => {
		_start => sub {
			my ($kernel) = $_[KERNEL];

			$kernel->alias_set ('foo');
			$kernel->delay_add ('foo', 2);
		},
		foo => sub {
			my ($kernel) = $_[KERNEL];

			print "POE FOO $count\n";
			warn "depth is " . Glib::main_depth;
			$count++;
			$kernel->delay_add ('foo', 2) unless ($count > 5);
		},
	},
);

POE::Kernel->run();

1;
