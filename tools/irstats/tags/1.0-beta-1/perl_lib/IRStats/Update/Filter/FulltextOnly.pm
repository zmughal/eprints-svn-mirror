package IRStats::Update::Filter::FulltextOnly;

#filters out abstract downloads

use strict;

our @ISA = qw( Logfile::EPrints::Filter );

sub AUTOLOAD {}

sub fulltext { shift->SUPER::fulltext( @_ ) }

1;

