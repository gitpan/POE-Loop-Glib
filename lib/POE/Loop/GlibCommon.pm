# $Id: GlibCommon.pm 12 2004-10-05 13:09:20Z martijn $

# Glib event loop bridge for POE::Kernel.

# Empty package to appease perl.
package POE::Loop::GlibCommon;
use strict;

use Glib;
use POE::Loop::PerlSignals;

# Include common signal handling.

use vars qw($VERSION);
$VERSION = do {my@r=(0,q$Rev: 12 $=~/\d+/g);sprintf"%d."."%04d"x$#r,@r};

# Everything plugs into POE::Kernel.
package POE::Kernel;

use strict;

my $_watcher_timer;
my @fileno_watcher;

#------------------------------------------------------------------------------
# Loop construction and destruction.

sub loop_finalize {
  foreach my $fd (0..$#fileno_watcher) {
    next unless defined $fileno_watcher[$fd];
    foreach my $mode (MODE_RD, MODE_WR, MODE_EX) {
      POE::Kernel::_warn(
        "Mode $mode watcher for fileno $fd is defined during loop finalize"
      ) if defined $fileno_watcher[$fd]->[$mode];
    }
  }
}

#------------------------------------------------------------------------------
# Signal handler maintenance functions.

#------------------------------------------------------------------------------
# Maintain time watchers.

sub loop_resume_time_watcher {
  my ($self, $next_time) = @_;
  $next_time -= time();
  $next_time *= 1000;
  $next_time = 0 if $next_time < 0;
  $_watcher_timer = Glib::Timeout->add($next_time, \&_loop_event_callback);
}

sub loop_reset_time_watcher {
  my ($self, $next_time) = @_;
  # Should always be defined, right?
  if (defined $_watcher_timer) {
  	Glib::Source->remove($_watcher_timer);
  	undef $_watcher_timer;
  }
  $self->loop_resume_time_watcher($next_time);
}

sub _loop_resume_timer {
  Glib::Source->remove($_watcher_timer);
  $poe_kernel->loop_resume_time_watcher($poe_kernel->get_next_event_time());
}

sub loop_pause_time_watcher {
  # does nothing
}

#------------------------------------------------------------------------------
# Maintain filehandle watchers.

sub loop_watch_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  # Overwriting a pre-existing watcher?
  if (defined $fileno_watcher[$fileno]->[$mode]) {
    Glib::Source->remove($fileno_watcher[$fileno]->[$mode]);
    undef $fileno_watcher[$fileno]->[$mode];
  }

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> watching $handle in mode $mode";
  }

  # Register the new watcher.
  $fileno_watcher[$fileno]->[$mode] =
    Glib::IO->add_watch( $fileno,
                         ( ($mode == MODE_RD)
                           ? ( ['G_IO_IN', 'G_IO_HUP', 'G_IO_ERR'],
                               \&_loop_select_read_callback
                             )
                           : ( ($mode == MODE_WR)
                               ? ( ['G_IO_OUT', 'G_IO_ERR'],
                                   \&_loop_select_write_callback
                                 )
                               : ( 'G_IO_HUP',
                                   \&_loop_select_expedite_callback
                                 )
                             )
                         ),
                       );
}

sub loop_ignore_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> ignoring $handle in mode $mode";
  }

  # Don't bother removing a select if none was registered.
  if (defined $fileno_watcher[$fileno]->[$mode]) {
    Glib::Source->remove($fileno_watcher[$fileno]->[$mode]);
    undef $fileno_watcher[$fileno]->[$mode];
  }
}

sub loop_pause_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> pausing $handle in mode $mode";
  }

  Glib::Source->remove($fileno_watcher[$fileno]->[$mode]);
  undef $fileno_watcher[$fileno]->[$mode];
}

sub loop_resume_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  # Quietly ignore requests to resume unpaused handles.
  return 1 if defined $fileno_watcher[$fileno]->[$mode];

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> resuming $handle in mode $mode";
  }

  $fileno_watcher[$fileno]->[$mode] =
    Glib::IO->add_watch( $fileno,
                         ( ($mode == MODE_RD)
                           ? ( ['G_IO_IN', 'G_IO_HUP', 'G_IO_ERR'],
                               \&_loop_select_read_callback
                             )
                           : ( ($mode == MODE_WR)
                               ? ( ['G_IO_OUT', 'G_IO_ERR'],
                                   \&_loop_select_write_callback
                                 )
                               : ( 'G_IO_HUP',
                                   \&_loop_select_expedite_callback
                                 )
                             )
                         ),
                       );
  return 1;
}

### Callbacks.

# Event callback to dispatch pending events.

my $last_time = time();

sub _loop_event_callback {
  my $self = $poe_kernel;

  if (TRACE_STATISTICS) {
    # TODO - I'm pretty sure the startup time will count as an unfair
    # amout of idleness.
    #
    # TODO - Introducing many new time() syscalls.  Bleah.
    $self->_data_stat_add('idle_seconds', time() - $last_time);
  }

  $self->_data_ev_dispatch_due();
  $self->_test_if_kernel_is_idle();

  Glib::Source->remove($_watcher_timer);
  undef $_watcher_timer;

  # Register the next timeout if there are events left.
  if ($self->get_event_count()) {
    $_watcher_timer = Glib::Idle->add(\&_loop_resume_timer);
  }

  # And back to Gtk, so we're in idle mode.
  $last_time = time() if TRACE_STATISTICS;

  # Return false to stop.
  return 0;
}

# Filehandle callback to dispatch selects.
sub _loop_select_read_callback {
  my $self = $poe_kernel;
  my ($fileno, $tag) = @_;

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> got read callback for $fileno";
  }

  $self->_data_handle_enqueue_ready(MODE_RD, $fileno);
  $self->_test_if_kernel_is_idle();

  # Return false to stop... probably not with this one.
  return 0;
}

sub _loop_select_write_callback {
  my $self = $poe_kernel;
  my ($fileno, $tag) = @_;

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> got write callback for $fileno";
  }

  $self->_data_handle_enqueue_ready(MODE_WR, $fileno);
  $self->_test_if_kernel_is_idle();

  # Return false to stop... probably not with this one.
  return 0;
}

sub _loop_select_expedite_callback {
  my $self = $poe_kernel;
  my ($handle, $fileno, $hash) = @_;

  if (TRACE_FILES) {
    POE::Kernel::_warn "<fh> got expedite callback for $handle";
  }

  $self->_data_handle_enqueue_ready(MODE_EX, $fileno);
  $self->_test_if_kernel_is_idle();

  # Return false to stop... probably not with this one.
  return 0;
}

#------------------------------------------------------------------------------
# The event loop itself.

sub loop_do_timeslice {
  die "doing timeslices currently not supported in the Glib based loops";
}

1;
