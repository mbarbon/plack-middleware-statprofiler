package Plack::Middleware::StatProfiler;
# ABSTRACT: Plack integration for Devel::StatProfiler

use strict;
use warnings;
use parent 'Plack::Middleware';

use Plack::Util;
use Plack::Util::Accessor qw(
    enable_check
    custom_metadata
    section_name
);

my ($ENABLED_IN_NEXT_REQUEST, $INC_WRITTEN, @EXTRA_INC_PATHS);

sub prepare_app {
    my ($self) = @_;

    $self->enable_check(sub { 1 }) unless $self->enable_check;
    $self->section_name('plack_request') unless $self->section_name;
    $self->custom_metadata(sub { }) unless $self->custom_metadata;
}

sub wrap {
    my $app = shift->SUPER::wrap(@_);
    return sub {
        my ($env) = @_;

        my $res = $app->($env);

        Plack::Util::response_cb($res, sub {
            my $res = shift;
            # see comment in call()
            if (defined(my $length = delete $env->{'devel.statprofiler.content-length'})) {
                Plack::Util::header_set($res->[1], 'Content-Length', $length);
            }
            return;
        });
    };
}

sub call {
    my($self, $env) = @_;
    printf STDERR "%s:%d\n", __FILE__, __LINE__;
    if ($ENABLED_IN_NEXT_REQUEST && $self->enable_check->()) {
        Devel::StatProfiler::save_source('all_evals_always');
        Devel::StatProfiler::enable_profile();
        if (!$INC_WRITTEN) {
            Devel::StatProfiler::write_inc_path([@INC, @EXTRA_INC_PATHS]);
            $INC_WRITTEN = 1;
        }
    } else {
    printf STDERR "%s:%d\n", __FILE__, __LINE__;
        Devel::StatProfiler::disable_profile();
    printf STDERR "%s:%d\n", __FILE__, __LINE__;
        Devel::StatProfiler::save_source('none');
    }

    my $section_name = $self->section_name;
    Devel::StatProfiler::start_section($section_name);

    my $res = $self->app->($env);

    Plack::Util::response_cb($res, sub {
        my $res = shift;

        # response_cb() discards Content-Length when passed a filter sub; since we don't modify the content,
        # save the length here and restore it in the outer middleware added by wrap()
        # see also https://groups.google.com/forum/#!topic/psgi-plack/ioiKjeYHLTM (Plack::Util ate my Content-Length)
        $env->{'devel.statprofiler.content-length'} = Plack::Util::header_get($res->[1], 'Content-Length')
            if ref($res) eq 'ARRAY';

        return sub {
            # use $_[0] to try to avoid a copy
            if (!defined $_[0]) {
                my @metadata = $self->custom_metadata->($env);
                Devel::StatProfiler::write_custom_metadata(@metadata) if @metadata;
                Devel::StatProfiler::end_section($section_name);
            }

            return $_[0];
        };
    });
}

sub set_enabled_in_next_request {
    $ENABLED_IN_NEXT_REQUEST = !!$_[0];
}

sub set_extra_inc_paths {
    @EXTRA_INC_PATHS = @_;
}

1;

=head1 SYNOPSIS

  use Plack::Middleware::StatProfiler::Load (
      load  => 1,
  );

  # Clean shutdown, so profile file is flushed
  # (might or might not be necessary, depending on the server)
  $SIG{INT} = sub {
      exit 0;
  };

  builder {
      if (Plack::Middleware::StatProfiler::Load::LOADED) {
          enable "+Plack::Middleware::StatProfiler";
          Plack::Middleware::StatProfiler::set_enabled_in_next_request(1);
      }
      # ...
  };
