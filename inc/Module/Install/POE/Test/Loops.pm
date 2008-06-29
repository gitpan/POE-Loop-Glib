#line 1
package Module::Install::POE::Test::Loops;

use 5.005;
use strict;
use Module::Install::Base;
use POE::Test::Loops;
use File::Spec;
use Carp ();

#line 14

use vars qw{$VERSION @ISA};
$VERSION = '0.02';
@ISA     = qw{Module::Install::Base};


#line 31

sub gen_loop_tests {
  my ($self, @args) = @_;
  my $dir = shift @args;
  _gen_loop_tests($self, $dir, \@args);
}

sub _gen_loop_tests {
  my ($self, $dir, $loops) = @_;
  #return unless $Module::Install::AUTHOR;

  my @tests = $self->tests ? (split / /, $self->tests) : 't/*.t';

  Carp::confess "no dirs given to author_tests"
    unless @$loops;

  POE::Test::Loops::generate($dir, $loops);
  
  $self->tests( join ' ', @tests, map {
				File::Spec->catfile("$dir/", lc($_), "*.t");
				      } sort @$loops
	      );
}

1;

