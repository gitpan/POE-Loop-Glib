# $Id: Glib.pm 12 2004-10-05 13:09:20Z martijn $

# Glib event loop bridge for POE::Kernel.

# Empty package to appease perl.
package POE::Loop::Glib;
use strict;

#use Glib;

# Include common signal handling.
use POE::Loop::PerlSignals;
use POE::Loop::GlibCommon;

use vars qw($VERSION);
$VERSION = do {my@r=(0,q$Rev: 12 $=~/\d+/g);sprintf"%d."."%04d"x$#r,@r};

# Everything plugs into POE::Kernel.
package POE::Kernel;

use strict;

my $glib_mainloop;

#------------------------------------------------------------------------------
# Loop construction and destruction.

sub loop_initialize {
  my $self = shift;

  $glib_mainloop = Glib::MainLoop->new unless (Glib::main_depth > 0);

}

sub loop_run {
  (defined $glib_mainloop) && $glib_mainloop->run;
}

sub loop_halt {
  (defined $glib_mainloop) && $glib_mainloop->quit;
}

1;

__END__

=head1 NAME

POE::Loop::Glib - a bridge that supports Glib's event loop from POE

=head1 SYNOPSIS

See L<POE::Loop>.

=head1 DESCRIPTION

This class is an implementation of the abstract POE::Loop interface.
It follows POE::Loop's public interface exactly.  Therefore, please
see L<POE::Loop> for its documentation.

=head1 SEE ALSO

L<POE>, L<POE::Loop>, L<Glib>, L<Glib::MainLoop>

=head1 AUTHORS & LICENSING

Please see L<POE> for more information about authors, contributors,
and POE's licensing.

=cut
