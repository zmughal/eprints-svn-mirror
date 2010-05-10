######################################################################
#
# EPrints::Const
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Const> - constants and enumerations

=head1 DESCRIPTION

This module contains EPrints constants and enumerations.

=head1 CONSTANTS

=head2 Namespaces

=over 4

=item EP_NS_DATA

http://eprints.org/ep2/data/2.0

=item EP_NS_XSLT

http://eprints.org/ep2/xslt/1.0

=back

=head2 Trigger Result Codes

=over 4

=item EP_TRIGGER_DONE

Stop processing triggers immediately and return.

=item EP_TRIGGER_OK

Continue normal processing.

=back

=head2 Trigger Types

=over 4

=item EP_TRIGGER_GUESS_DOC_TYPE

=item EP_TRIGGER_LOG

=item EP_TRIGGER_BOILERPLATE_RDF

=item EP_TRIGGER_REPOSITORY_RDF

=item EP_TRIGGER_BEGIN

=item EP_TRIGGER_BEGIN_REQUEST

=item EP_TRIGGER_END_REQUEST

=item EP_TRIGGER_END

=item EP_TRIGGER_DOC_URL_REWRITE

=item EP_TRIGGER_CREATED

=item EP_TRIGGER_RDF

=item EP_TRIGGER_DEFAULTS

=item EP_TRIGGER_STATUS_CHANGE

=item EP_TRIGGER_BEFORE_COMMIT

=item EP_TRIGGER_AFTER_COMMIT

=item EP_TRIGGER_VALIDATE

=item EP_TRIGGER_WARNINGS

=item EP_TRIGGER_FILES_MODIFED

=back

=cut

package EPrints::Const;

use Exporter;
@ISA = qw( Exporter );

# Namespaces
use constant {
	EP_NS_XSLT => "http://eprints.org/ep2/xslt/1.0",
	EP_NS_DATA => "http://eprints.org/ep2/data/2.0",
};

use constant {
	EP_TRIGGER_DONE => -2,
	EP_TRIGGER_OK => 0,
};

# Repository triggers
use constant {
	EP_TRIGGER_GUESS_DOC_TYPE => 1,
	EP_TRIGGER_LOG => 2,
	EP_TRIGGER_BOILERPLATE_RDF => 3,
	EP_TRIGGER_REPOSITORY_RDF => 4,
	EP_TRIGGER_BEGIN => 5,
	EP_TRIGGER_BEGIN_REQUEST => 6,
	EP_TRIGGER_END_REQUEST => 7,
	EP_TRIGGER_END => 8,
	EP_TRIGGER_DOC_URL_REWRITE => 9,
};

# DataObj triggers
use constant {
	EP_TRIGGER_CREATED => 100,
	EP_TRIGGER_RDF => 101,
	EP_TRIGGER_DEFAULTS => 102,
	EP_TRIGGER_STATUS_CHANGE => 103,
	EP_TRIGGER_BEFORE_COMMIT => 104,
	EP_TRIGGER_AFTER_COMMIT => 105,
	EP_TRIGGER_VALIDATE => 106,
	EP_TRIGGER_WARNINGS => 107,
	EP_TRIGGER_FILES_MODIFED => 108,
};

@EXPORT_OK = ();
@EXPORT = qw(
	EP_NS_XSLT
	EP_NS_DATA

	EP_TRIGGER_DONE
	EP_TRIGGER_OK

	EP_TRIGGER_GUESS_DOC_TYPE
	EP_TRIGGER_LOG
	EP_TRIGGER_BOILERPLATE_RDF
	EP_TRIGGER_REPOSITORY_RDF
	EP_TRIGGER_BEGIN
	EP_TRIGGER_BEGIN_REQUEST
	EP_TRIGGER_END_REQUEST
	EP_TRIGGER_END
	EP_TRIGGER_DOC_URL_REWRITE

	EP_TRIGGER_CREATED
	EP_TRIGGER_RDF
	EP_TRIGGER_DEFAULTS
	EP_TRIGGER_STATUS_CHANGE
	EP_TRIGGER_BEFORE_COMMIT
	EP_TRIGGER_AFTER_COMMIT
	EP_TRIGGER_VALIDATE
	EP_TRIGGER_WARNINGS
	EP_TRIGGER_FILES_MODIFED
);
%EXPORT_TAGS = ();

use strict;

1;
