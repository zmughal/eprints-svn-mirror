package Net::HoneyComb;

use 5.008008;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Net::HoneyComb ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	HC_BINARY_TYPE
	HC_BOGUS_TYPE
	HC_BYTE_TYPE
	HC_CHAR_TYPE
	HC_DATE_TYPE
	HC_DOUBLE_TYPE
	HC_EMPTY_VALUE_INIT
	HC_LONG_TYPE
	HC_OBJECTID_TYPE
	HC_STRING_TYPE
	HC_TIMESTAMP_TYPE
	HC_TIME_TYPE
	HC_UNKNOWN_TYPE
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	HC_BINARY_TYPE
	HC_BOGUS_TYPE
	HC_BYTE_TYPE
	HC_CHAR_TYPE
	HC_DATE_TYPE
	HC_DOUBLE_TYPE
	HC_EMPTY_VALUE_INIT
	HC_LONG_TYPE
	HC_OBJECTID_TYPE
	HC_STRING_TYPE
	HC_TIMESTAMP_TYPE
	HC_TIME_TYPE
	HC_UNKNOWN_TYPE
);

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Net::HoneyComb::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Net::HoneyComb', $VERSION);

# Preloaded methods go here.

Net::HoneyComb::init();

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Net::HoneyComb - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Net::HoneyComb;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Net::HoneyComb, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.

=head2 Exportable constants

  HC_BINARY_TYPE
  HC_BOGUS_TYPE
  HC_BYTE_TYPE
  HC_CHAR_TYPE
  HC_DATE_TYPE
  HC_DOUBLE_TYPE
  HC_EMPTY_VALUE_INIT
  HC_LONG_TYPE
  HC_OBJECTID_TYPE
  HC_STRING_TYPE
  HC_TIMESTAMP_TYPE
  HC_TIME_TYPE
  HC_UNKNOWN_TYPE



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Tim D Brody, E<lt>tdb2@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Tim D Brody

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
