######################################################################
#
# Subject class.
#
#  Handles the subject hierarchy.
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

package EPrints::Subject;

use EPrints::Database;
use EPrints::SearchExpression;

use strict;


# Root subject specifier
$EPrints::Subject::root_subject = "ROOT";

# Root subject name
$EPrints::Subject::root_subject_name = "(Top Level)";

## WP1: BAD
sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"subjectid", type=>"text", required=>1 },

		{ name=>"name", type=>"text", required=>1 },

		{ name=>"parents", type=>"text", required=>1, multiple=>1 },

		{ name=>"ancestors", type=>"text", required=>0, multiple=>1 },

		{ name=>"depositable", type=>"boolean", required=>1 },
	);
}

#cjg NEED TO {data} OO it.

######################################################################
#
# $subject = new( $session, $id, $row )
#
#  Create a new subject object. Can either pass in fields from the
#  database (which must be the same fields in the same order as given
#  in @EPrints::Subject::system_meta_fields, including subjectid),
#  or just the $id, in which case the database will be searched.
#
#  If both $id and $row are undefined, then the subject becomes the
#  implicit, invisible root subject, whose children are the top-level
#  subjects.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class, $session, $subjectid, $known ) = @_;

	my $self = {};
	
	if( defined $known )
	{
		$self->{data} = $known;
	}
	else
	{
		if( defined $subjectid && 
			$subjectid ne $EPrints::Subject::root_subject )
		{
			# Got ID, need to read stuff in from database
			return $session->get_db()->get_single( 
				$session->get_archive()->get_dataset( "subject" ), 
				$subjectid );
		}
		# Create a root subject object
		$self->{data} = {};
		$self->{data}->{subjectid} = $EPrints::Subject::root_subject;
		$self->{data}->{name} = $EPrints::Subject::root_subject_name; #cjg!
		$self->{data}->{parents} = [];
		$self->{data}->{ancestors} = [ $EPrints::Subject::root_subject ];
		$self->{data}->{depositable} = "FALSE";
	}

	$self->{dataset} = $session->get_archive()->get_dataset( "subject" ); 
	$self->{session} = $session;
	bless $self, $class;

	return( $self );
}

sub commit 
{
	my( $self ) = @_;

	my @ancestors = $self->_get_ancestors();
	$self->{data}->{ancestors} = \@ancestors;

	my $rv = $self->{session}->get_db()->update(
			$self->{dataset},
			$self->{data} );

	
	# Need to update all children in case ancesors have changed.
	# This is pretty slow esp. For a top level subject, but subject
	# changes will be rare and only done by admin, so mnya.
	my $child;
	foreach $child ( $self->children() )
	{
		$rv = $rv && $child->commit();
	}
	return $rv;
}	


######################################################################
#
# $subject = create_subject( $session, $id, $name, $parent, $depositable )
#
#  Creates the given subject in the database. $id is the ID of the subject,
#  $name is a suitably meaningful name in English, and $depositable is
#  a boolean specifying whether or not users can deposit articles in this
#  subject. $parent is the parent subject, which should be undef if the
#  subject is a top level subject.
#
######################################################################

sub create_subject
{
	my( $class, $session, $id, $name, $parents, $depositable ) = @_;
	
	my $actual_parents = $parents;
	$actual_parents = [ $EPrints::Subject::root_subject ] if( !defined $parents );

	my $newsubdata = 
		{ "subjectid"=>$id,
		  "name"=>$name,
		  "parents"=>$actual_parents,
		  "ancestors"=>[],
		  "depositable"=>($depositable ? "TRUE" : "FALSE" ) };

	return( undef ) unless( $session->get_db()->add_record( 
		$session->get_archive()->get_dataset( "subject" ), 
		$newsubdata ) );

	my $newsub = new EPrints::Subject( $session, undef, $newsubdata );

	$newsub->commit(); # will update ancestors

	return $newsub;
}

sub _get_ancestors
{
	my( $self ) = @_;
use Data::Dumper;
print "$self->{data}->{subjectid}->GETANCESTORS\n";
print Dumper( $self->{data} );
	my %ancestors;
	$ancestors{$self->{data}->{subjectid}} = 1;

	my $parent;
	foreach $parent ( $self->get_parents() )
	{

print ".\n";
		foreach( $parent->_get_ancestors() )
		{
			$ancestors{$_} = 1;
		}
	}
	return keys %ancestors;
}

######################################################################
#
# $subject = create_child( $id, $name, $depositable )
#
#  Create a child subject.
#
######################################################################

## WP1: BAD
sub create_child
{
	my( $self, $id, $name, $depositable ) = @_;
	
	return( EPrints::Subject->create_subject( $self->{session},
	                                          $id,
	                                          $name,
	                                          $self->{subjectid},
	                                          $depositable ) );
}


######################################################################
#
# @children = children()
#
#  Retrieves the subject's children, if any. Children of the root
#  subject are the top-level subjects.
#
#  The children are ordered by name.
#
######################################################################

## WP1: BAD
sub children #cjg should be get_children()
{
	my( $self ) = @_;

	my $searchexp = new EPrints::SearchExpression(
		session=>$self->{session},
		dataset=>$self->{dataset} );

	$searchexp->add_field(
		$self->{dataset}->get_field( "parents" ),
		"PHR:EQ:".$self->get_value( "subjectid" ) );

#cjg set order (it's in the site config)

	my $searchid = $searchexp->perform_search();
	my @children = $searchexp->get_records();

	return( @children );
}


######################################################################
#
# $subject = parent()
#
#  Returns the subject's parent. If this is called on the root subject,
#  undef is returned. If this is called on a top-level subject, the
#  root subject is returned (i.e. $subject->{subjectid} is
#  $EPrints::Subject::root_subject.)
#
######################################################################

sub get_parents
{
	my( $self ) = @_;

	my @parents = ();
	foreach( @{$self->{data}->{parents}} )
	{
		push @parents, new EPrints::Subject( $self->{session}, $_ );
	}
	return( @parents );
}


######################################################################
#
# $boolean = can_post( $user )
#
#  Determines whether the given user can post in this subject.
#  At the moment, no user-specific stuff - each subject is just
#  a yes or no.
#
######################################################################

sub can_post
{
	my( $self, $user ) = @_;

	# Depends on the subject	
	return( $self->{data}->{depositable} eq "TRUE" ? 1 : 0 );
}

sub render
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "subject" );
	my $namefield = $ds->get_field( "name" );
	my $html = $namefield->render_value( 
			$self->{session}, 
			$self->{data}->{name} );
	return $html;
}

######################################################################
#
# $success = create_subject_table( $session )
#
#  Reads in the subject info from a config file and writes it to the
#  database. [STATIC]
#
######################################################################

## WP1: BAD
#cjg Ultimatly should use ImportXML.
sub create_subject_table
{
	my( $session, $filename ) = @_;
	
	# Read stuff in from the subject config file
print STDERR "subjectfile=($filename)\n";
	open( SUBJECTS, $filename ) or return( 0 );

	my $success = 1;
	
	while( <SUBJECTS> )
	{
#		print "Line: $_\n";
		chomp();
		next if /^\s*(#|$)/;
		my @vals = split /:/;

		my @parents = split( ",", $vals[2] );
		
		$success = $success &&
			( defined EPrints::Subject->create_subject( 
				$session,
			        $vals[0],
			        $vals[1],
				\@parents,					
			        $vals[3] ) );
	}
	
	return( $success );
}



######################################################################
#
# ( $tags, $labels ) = get_postable( $session, $user )
#
#  Returns a list of the subjects that can be posted to by $user. They
#  are returned in a tuple, the first element being a reference to an
#  array of tags (for the ordering) and the second being a reference
#  to the hash mapping tags to full names. [STATIC]
#
######################################################################

sub get_subjects 
{
	my( $self, $postableonly, $showtoplevel ) = @_; 
#cjg some kind of whacky debugging code:
if( $self eq "0" )
{
	use Carp;
confess;
}
	my( $subjectmap, $rmap ) = EPrints::Subject::get_all( $self->{session} );
	return $self->_get_subjects2( $postableonly, !$showtoplevel, $subjectmap, $rmap );
	
}

sub _get_subjects2
{
	my( $self, $postableonly, $hidenode, $subjectmap, $rmap ) = @_; 
	
	my $namefield = $self->{dataset}->get_field( "name" );

	my $postable = ($self->get_value( "depositable" ) eq "TRUE" ? 1 : 0 );
	my $id = $self->get_value( "subjectid" );
	my $label = $namefield->most_local( $self->{session}, $self->get_value( "name" ) );
	my $subpairs = [];
	if( (!$postableonly || $postable) && (!$hidenode) )
	{
		push @{$subpairs},[ $id, $label ];
	}
	my $kid;
	foreach $kid ( @{$rmap->{$id}} )# cjg sort on labels?
	{
		my $kidmap = $kid->_get_subjects2( 
				$postableonly, 0, $subjectmap, $rmap );
		my $pair;
		foreach $pair ( @{$kidmap} )
		{
			my $pair2 = [ 
				$pair->[0], 
				($hidenode?"":$label.": ").$pair->[1] ];
			push @{$subpairs}, $pair2;
		}
	}

	return $subpairs;
}

######################################################################
#
# $label = subject_label( $session, $subject_tag )
#
#  Return the full label of a subject, including parents. Returns
#  undef if the subject tag is invalid. [STATIC]
#
######################################################################

## WP1: BAD
sub subject_label
{
	my( $session, $subject_tag ) = @_;
	
	my $label = "";
	my $tag = $subject_tag;

	while( $tag ne $EPrints::Subject::root_subject )
	{
		my $ds = $session->get_archive()->get_dataset();
		my $data = $session->{database}->get_single( $ds, $tag );
		
		# If we can't find it, the tag must be invalid.
		if( !defined $data )
		{
			return( undef );
		}

		$tag = $data->{parent};

		if( $label eq "" )
		{
			$label = $data->{name};
		}
		else
		{
			$label = $data->{name} . ": " . $label;
		}
	}
	
	return( $label );
}


# cjg CACHE this per, er, session?
# commiting a subject should erase the cache
sub get_all
{
	my( $session ) = @_;
	
	# Retrieve all of the subjects
	my @subjects = $session->get_db()->get_all( 
		$session->get_archive()->get_dataset( "subject" ) );

	return( undef ) if( scalar @subjects == 0 );

	my( %subjectmap );
	my( %rmap );
	my $subject;
	foreach $subject (@subjects)
	{
		$subjectmap{$subject->get_value("subjectid")} = $subject;
		foreach( @{$subject->{data}->{parents}} )
		{
			$rmap{$_} = [] if( !defined $rmap{$_} );
			push @{$rmap{$_}}, $subject;
		}
	}
	
	return( \%subjectmap, \%rmap );
}


sub posted_eprints
{
	my( $self, $dataset ) = @_;

	my $searchexp = new EPrints::SearchExpression(
		session => $self->{session},
		dataset => $dataset,
		satisfy_all => 0 );

	my $n = 0;
	my $field;
	foreach $field ( $dataset->get_fields() )
	{
		next unless( $field->is_type( "subject" ) );
		$n += 1;
		$searchexp->add_field(
			$field,
			"PHR:EQ:".$self->get_value( "subjectid" ) );
	}

	if( $n == 0 )
	{
		# no actual subject fields
		return();
	}

	my $searchid = $searchexp->perform_search;
	my @data = $searchexp->get_records;

	return @data;
}


######################################################################
#
# $num = count_eprints( $table )
#
#  Simpler version of above function. Counts the EPrints in this
#  subject fields from $table. If $table is unspecified, the main
#  archive table is assumed.
#
######################################################################

## WP1: BAD
sub count_eprints
{
	my( $self, $dataset ) = @_;

	# Create a search expression
	my $searchexp = new EPrints::SearchExpression(
		session => $self->{session},
		dataset => $dataset );

	$searchexp->add_field(
		$dataset->get_field( "subjects" ),
		"PHR:EQ:".$self->get_value( "subjectid" ) );

	my $searchid = $searchexp->perform_search;
	my $count = $searchexp->count;

	return $count;

}

## WP1: BAD
sub get_value 
{
	my( $self, $fieldname ) = @_;
	if( $self->{data}->{$fieldname} eq "")
	{
		return undef;
	}

	return $self->{data}->{$fieldname};
}

#
#
#
#
#
#
#
###############################################
# JUNK
###############################################

## WP1: BAD
sub get_postable
{
	my( $session, $user ) = @_;

	# Get all of the subjects
	my( $subjectmap, $rmap ) = EPrints::Subject::get_all( $session );


	# For the results
	#my @tags;
	#my %labels;

	# easy sorting
	#my %labelmap;
	#my $subject;
	## Go through all of the subjects
	#foreach $subject (keys
	#{
		## If the user can post to it...
		#if( !defined $user || $subject->can_post( $user ) )
		#{
			## Lob it in the list!
			#my $lab = EPrints::Subject::subject_label_cache(
				#$session,
				#$subject->{subjectid},
				#$subjectmap );
			#$labels{$subject->get_value("subjectid")} = $lab;
			#$labelmap{$lab} = $subject;
		#}
	#}
	#
	## Put subjects in alphabetical order to labelmap
	#foreach (sort keys %labelmap)
	#{
		#push @tags, $labelmap{$_}->get_value("subjectid");
	#}
#
	#return( \@tags, \%labels );
}

######################################################################
#
# ($tags, $labels ) = all_subject_labels( $session )
#
#  Returns tags and labels for _all_ subjects, in a manner similar to
#  get_postable().
#
######################################################################

## WP1: BAD
sub all_subject_labels
{
	my( $session ) = @_;
	
	return( EPrints::Subject::get_postable( $session, undef ) );
}


######################################################################
#
# $name = subject_name( $session, $subject_tag )
#
#  Return just the subjects name. Returns
#  undef if the subject tag is invalid. [STATIC]
#
######################################################################

## WP1: BAD
sub subject_name
{
	my( $session, $subject_tag ) = @_;

	my $data = $session->{database}->get_single( "subject" , $subject_tag );

	# If we can't find it, the tag must be invalid.
	if( !defined $data )
	{
		return( undef );
	}

	# return the name
	return $data->{name};
}

######################################################################
#
# $label = subject_label_cache( $session, $subject_tag, $subject_cache )
#
#  Return the full label of a subject, including parents. Returns
#  undef if the subject tag is invalid. This one works when you have
#  the subjects cached in a hash that maps subject ID - Subject. 
#  [STATIC]
#
######################################################################

## WP1: BAD
sub subject_label_cache
{
	my( $session, $subject_tag, $subject_cache ) = @_;
	
	my $label = "";
	my $tag = $subject_tag;

	while( $tag ne $EPrints::Subject::root_subject )
	{
		my $s = $subject_cache->{$tag};

		# If we can't find it, the tag must be invalid.
		if( !defined $s )
		{
			return( undef );
		}

		$tag = $s->{parent};

		if( $label eq "" )
		{
			$label = $s->{name};
		}
		else
		{
			$label = $s->{name} . ": " . $label;
		}
	}
	
	return( $label );
}



1;
