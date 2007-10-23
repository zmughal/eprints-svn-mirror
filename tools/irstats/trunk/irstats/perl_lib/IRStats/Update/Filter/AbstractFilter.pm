package IRStats::Update::Filter::AbstractFilter;

#filters out abstract downloads

use strict;

our @ISA = qw( Logfile::EPrints::Filter );

sub AUTOLOAD {}

sub fulltext { $_[0]->{handler}->fulltext( $_[1] ) }

1;

