package Plack::Middleware::StatProfiler::Load;

use strict;
use warnings;
use constant;

sub import {
    my ($class, %args) = @_;

    unless ($args{load}) {
        constant->import(LOADED => 0);
        return;
    }

    require Devel::StatProfiler;

    Devel::StatProfiler->import(@{$args{statprofiler_args} || []});
    constant->import(LOADED => 1);
}

1;
