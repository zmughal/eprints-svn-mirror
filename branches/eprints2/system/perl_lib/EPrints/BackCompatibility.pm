######################################################################
#
# EPrints::BackCompatibility
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

=head1 NAME

B<EPrints::BackCompatibility> - Provide compatibility for older versions of the API.

=head1 DESCRIPTION

A number of EPrints packages have been moved or renamed. This module
provides stub versions of these packages under there old names so that
existing code will require few or no changes.

It also sets a flag in PERL to think the packages have been loaded from
their original locations. This causes calls such as:

 use EPrints::Document;

to do nothing as they know the module is already loaded.

=over 4

=cut

use EPrints;

use strict;

######################################################################
=pod

=back

=cut

######################################################################

package EPrints::Document;

our @ISA = qw/ EPrints::DataObj::Document /;

$INC{"EPrints/Document.pm"} = 1;

sub create { return EPrints::DataObj::Document::create( @_ ); }

sub docid_to_path { return EPrints::DataObj::Document::docid_to_path( @_ ); }

######################################################################

package EPrints::EPrint;

our @ISA = qw/ EPrints::DataObj::EPrint /;

$INC{"EPrints/EPrint.pm"} = 1;

sub create { return EPrints::DataObj::EPrint::create( @_ ); }
sub eprintid_to_path { return EPrints::DataObj::EPrint::eprintid_to_path( @_ ); }

######################################################################

package EPrints::Subject;

our @ISA = qw/ EPrints::DataObj::Subject /;

$INC{"EPrints/Subject.pm"} = 1;

$EPrints::Subject::root_subject = "ROOT";
sub remove_all { return EPrints::DataObj::Subject::remove_all( @_ ); }
sub create { return EPrints::DataObj::Subject::create( @_ ); }
sub subject_label { return EPrints::DataObj::Subject::subject_label( @_ ); }
sub get_all { return EPrints::DataObj::Subject::get_all( @_ ); }
sub valid_id { return EPrints::DataObj::Subject::valid_id( @_ ); }

######################################################################

package EPrints::Subscription;

our @ISA = qw/ EPrints::DataObj::Subscription /;

$INC{"EPrints/Subscription.pm"} = 1;

sub process_set { return EPrints::DataObj::Subscription::process_set( @_ ); }
sub get_last_timestamp { return EPrints::DataObj::Subscription::get_last_timestamp( @_ ); }

######################################################################

package EPrints::User;

our @ISA = qw/ EPrints::DataObj::User /;

$INC{"EPrints/User.pm"} = 1;

sub create { return EPrints::DataObj::User::create( @_ ); }
sub user_with_email { return EPrints::DataObj::User::user_with_email( @_ ); }
sub user_with_username { return EPrints::DataObj::User::user_with_username( @_ ); }
sub process_editor_alerts { return EPrints::DataObj::User::process_editor_alerts( @_ ); }
sub create_user { return EPrints::DataObj::User::create( @_ ); }

######################################################################

package EPrints::Archive;

our @ISA = qw/ EPrints::Repository /;

$INC{"EPrints/Archive.pm"} = 1;

######################################################################
1;


