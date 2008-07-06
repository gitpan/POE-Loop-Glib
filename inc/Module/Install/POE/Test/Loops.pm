#line 1
package Module::Install::POE::Test::Loops;
# vim: ts=3 sw=3 et

use 5.005;
use strict;
use warnings;
use Module::Install::Base;
use POE::Test::Loops;
use File::Spec;
use Carp ();

#line 16

use vars qw{$VERSION @ISA};
$VERSION = '0.03';
@ISA     = qw{Module::Install::Base};


#line 34

sub gen_loop_tests {
   my ($self, $dir, @args) = @_;

   _gen_loop_tests($self, $dir, \@args);

   if (defined $self->configure_requires) {
      my %c_r = @{$self->configure_requires};
      return if (defined $c_r{'POE::Test::Loops'});
   }
   $self->configure_requires('POE::Test::Loops', '1.002')
}

sub _gen_loop_tests {
   my ($self, $dir, $loops) = @_;

   my @tests = $self->tests ? (split / /, $self->tests) : 't/*.t';

   Carp::confess "no dirs given to gen_loop_tests"
      unless @$loops;

   POE::Test::Loops::generate($dir, $loops);
  
   $self->tests(
      join ' ', @tests,
         map   {
                  File::Spec->catfile("$dir/", lc($_), "*.t");
               } sort @$loops
   );
}

1;

