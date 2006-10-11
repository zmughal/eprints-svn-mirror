######################################################################
#
# EPrints::Subject
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

B<EPrints::Subject> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
# Subject class.
#
#  Handles the subject hierarchy.
#
######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::Subject;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;

use EPrints::Database;
use EPrints::Session;
use EPrints::SearchExpression;

use strict;


# Root subject specifier
$EPrints::Subject::root_subject = "ROOT";


######################################################################
=pod

=item $thing = EPrints::Subject->get_system_field_info

undocumented

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"subjectid", type=>"text", required=>1 },

		{ name=>"name", type=>"text", required=>1, multilang=>1 },

		{ name=>"parents", type=>"text", required=>1, multiple=>1 },

		{ name=>"ancestors", type=>"text", required=>0, multiple=>1,
			export_as_xml=>0 },

		{ name=>"depositable", type=>"boolean", required=>1,
			input_style=>"radio" },
	);
}


######################################################################
#
# $subject = new( $id, $row )
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


######################################################################
=pod

=item $thing = EPrints::Subject->new( $subjectid )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $subjectid ) = trim_params(@_);

	if( $subjectid eq $EPrints::Subject::root_subject )
	{
		my $data = {
			subjectid => $EPrints::Subject::root_subject,
			name => {},
			parents => [],
			ancestors => [ $EPrints::Subject::root_subject ],
			depositable => "FALSE" 
		};
		my $langid;
		foreach $langid ( @{&ARCHIVE->get_conf( "languages" )} )
		{
			$data->{name}->{$langid} = EPrints::XML::to_string( 
&ARCHIVE->get_language( $langid )->phrase( "lib/subject:top_level", {} ) );
		}

		return EPrints::Subject->new_from_data( $data );
	}

	return &DATABASE->get_single( 
			&ARCHIVE->get_dataset( "subject" ), 
			$subjectid );

}



######################################################################
=pod

=item $thing = EPrints::Subject->new_from_data( $known )

undocumented

=cut
######################################################################

sub new_from_data
{
	my( $class, $known ) = trim_params(@_);

	my $self = {};
	
	$self->{data} = $known;
	$self->{dataset} = &ARCHIVE->get_dataset( "subject" ); 
	bless $self, $class;

	return( $self );
}



######################################################################
=pod

=item $foo = $thing->commit 

undocumented

=cut
######################################################################

sub commit 
{
	my( $self ) = @_;

	my @ancestors = $self->_get_ancestors();
	$self->{data}->{ancestors} = \@ancestors;

	my $rv = &DATABASE->update( $self->{dataset}, $self->{data} );
	
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
=pod

=item $foo = $thing->remove

undocumented

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	if( scalar $self->children() != 0 )
	{
		return( 0 );
	}

	#cjg Should we unlink all eprints linked to this subject from
	# this subject?

	return &DATABASE->remove(
		$self->{dataset},
		$self->{data}->{subjectid} );
}


######################################################################
=pod

=item EPrints::Subject::remove_all()

undocumented

=cut
######################################################################

sub remove_all
{
	my $ds = &ARCHIVE->get_dataset( "subject" );
	my @subjects = &DATABASE->get_all( $ds );
	foreach( @subjects )
	{
		my $id = $_->get_value( "subjectid" );
		&DATABASE->remove( $ds, $id );
	}
}

	
######################################################################
#
# $subject = create( $id, $name, $parent, $depositable )
#
#  Creates the given subject in the database. $id is the ID of the subject,
#  $name is a suitably meaningful name in English, and $depositable is
#  a boolean specifying whether or not users can deposit articles in this
#  subject. $parent is the parent subject, which should be undef if the
#  subject is a top level subject.
#
######################################################################


######################################################################
=pod

=item EPrints::Subject::create( $id, $name, $parents, $depositable )

undocumented

=cut
######################################################################

sub create
{
	my( $id, $name, $parents, $depositable ) = trim_params(@_);

	if( $id !~ m/^[^\s]+$/ )
	{
		EPrints::Config::abort( <<END );
Error. Can't create new subject. 
The value '$id' is not a valid subject identifier.
Subject id's may not contain whitespace.
END
	}
	
	my $actual_parents = $parents;
	$actual_parents = [ $EPrints::Subject::root_subject ] if( !defined $parents );

	my $newsubdata = 
		{ "subjectid"=>$id,
		  "name"=>$name,
		  "parents"=>$actual_parents,
		  "ancestors"=>[],
		  "depositable"=>($depositable ? "TRUE" : "FALSE" ) };

	return( undef ) unless( &DATABASE->add_record( 
		&ARCHIVE->get_dataset( "subject" ), 
		$newsubdata ) );

	my $newsub = EPrints::Subject->new_from_data( $newsubdata );

	$newsub->commit(); # will update ancestors

	return $newsub;
}

######################################################################
# 
# $foo = $thing->_get_ancestors
#
# undocumented
#
######################################################################

sub _get_ancestors
{
	my( $self ) = @_;
#use Data::Dumper;
#print "$self->{data}->{subjectid}->GETANCESTORS\n";
#print Dumper( $self->{data} );
	my %ancestors;
	$ancestors{$self->{data}->{subjectid}} = 1;

	my $parent;
	foreach $parent ( $self->get_parents() )
	{

#print ".\n";
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


######################################################################
=pod

=item $foo = $thing->create_child( $id, $name, $depositable )

undocumented

=cut
######################################################################

sub create_child
{
	my( $self, $id, $name, $depositable ) = @_;
	
	return( EPrints::Subject::create( $id,
	                                  $name,
	                                  $self->{subjectid},
	                                  $depositable ) );
}




######################################################################
=pod

=item $foo = $thing->children #cjg should be get_children()

undocumented

=cut
######################################################################

sub children #cjg should be get_children()
{
	my( $self ) = @_;

	my $searchexp = new EPrints::SearchExpression(
		dataset=>$self->{dataset},
		custom_order=>"name" );

	$searchexp->add_field(
		$self->{dataset}->get_field( "parents" ),
		$self->get_value( "subjectid" ) );

	my $searchid = $searchexp->perform_search();
	my @children = $searchexp->get_records();
	$searchexp->dispose();

	return( @children );
}




######################################################################
=pod

=item $foo = $thing->get_parents

undocumented

=cut
######################################################################

sub get_parents
{
	my( $self ) = @_;

	my @parents = ();
	foreach( @{$self->{data}->{parents}} )
	{
		push @parents, new EPrints::Subject( $_ );
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


######################################################################
=pod

=item $foo = $thing->can_post( [$user] )

undocumented

=cut
######################################################################

sub can_post
{
	my( $self, $user ) = @_;

	# Depends on the subject	
	return( $self->{data}->{depositable} eq "TRUE" ? 1 : 0 );
}



######################################################################
=pod

=item $foo = $thing->render_with_path( $topsubjid )

undocumented

=cut
######################################################################

sub render_with_path
{
	my( $self, $topsubjid ) = trim_params(@_);

	my @paths = $self->get_paths( $topsubjid );

	my $v = &SESSION->make_doc_fragment();

	my $first = 1;
	foreach( @paths )
	{
		if( $first )
		{
			$first = 0;	
		}	
		else
		{
			$v->appendChild( &SESSION->html_phrase( 
				"lib/metafield:join_subject" ) );
			# nb. using one from metafield!
		}
		my $first = 1;
		foreach( @{$_} )
		{
			if( !$first )
			{
				$v->appendChild( &SESSION->html_phrase( 
					"lib/metafield:join_subject_parts" ) );
			}
			$first = 0;
			$v->appendChild( $_->render_description() );
		}
	}
	return $v;
}

# This function returns all the paths from this subject back up to the
# specified top subject.

######################################################################
=pod

=item $foo = $thing->get_paths( $topsubjid )

undocumented

=cut
######################################################################

sub get_paths
{
	my( $self, $topsubjid ) = trim_params(@_);

	if( $self->get_value( "subjectid" ) eq $topsubjid )
	{
		# empty list, for the top level we care about
		return ([]);
	}
	if( $self->get_value( "subjectid" ) eq $EPrints::Subject::root_subject )
	{
		return ([]);
	}
	my( @paths ) = ();
	foreach( @{$self->{data}->{parents}} )
	{
		my $subj = new EPrints::Subject( $_ );
		push @paths, $subj->get_paths( $topsubjid );
	}
	foreach( @paths )
	{
		push @{$_}, $self;
	}
	return @paths;
}


######################################################################
#
# ( $tags, $labels ) = get_postable( $user )
#
#  Returns a list of the subjects that can be posted to by $user. They
#  are returned in a tuple, the first element being a reference to an
#  array of tags (for the ordering) and the second being a reference
#  to the hash mapping tags to full names. [STATIC]
#
######################################################################


######################################################################
=pod

=item $foo = $thing->get_subjects ( $postableonly, $showtoplevel, $nestids, $nocascadelabel )

undocumented

=cut
######################################################################

sub get_subjects 
{
	my( $self, $postableonly, $showtoplevel, $nestids, $nocascadelabel ) = @_; 

#cjg optimisation to not bother getting labels?
	my( $subjectmap, $rmap ) = EPrints::Subject::get_all();
	return $self->_get_subjects2( $postableonly, !$showtoplevel, $nestids, $subjectmap, $rmap, "", !$nocascadelabel );
	
}

######################################################################
# 
# $foo = $thing->_get_subjects2( $postableonly, $hidenode, $nestids, $subjectmap, $rmap, $prefix )
#
# undocumented
#
######################################################################

sub _get_subjects2
{
	my( $self, $postableonly, $hidenode, $nestids, $subjectmap, $rmap, $prefix, $cascadelabel ) = @_; 
	

	my $postable = ($self->get_value( "depositable" ) eq "TRUE" ? 1 : 0 );
	my $id = $self->get_value( "subjectid" );

	my $desc = $self->render_description;
	my $label = EPrints::Utils::tree_to_utf8( $desc );
	EPrints::XML::dispose( $desc );

	my $subpairs = [];
	if( (!$postableonly || $postable) && (!$hidenode) )
	{
		if( $prefix ne "" ) { $prefix .= ":"; }
		$prefix.=$id;
		push @{$subpairs},[ ($nestids?$prefix:$id), $label ];
	}
	$prefix = "" if( $hidenode );
	foreach my $kid ( @{$rmap->{$id}} )# cjg sort on labels?
	{
		my $kidmap = $kid->_get_subjects2( 
				$postableonly, 0, $nestids, $subjectmap, $rmap, $prefix, $cascadelabel );
		if( !$cascadelabel )
		{
			push @{$subpairs}, @{$kidmap};
			next;
		}
		foreach my $pair ( @{$kidmap} )
		{
			my $label = ($hidenode?"":$label.": ").$pair->[1];
			push @{$subpairs}, [ $pair->[0], $label ];
		}
	}

	return $subpairs;
}

######################################################################
#
# $label = subject_label( $subject_tag )
#
#  Return the full label of a subject, including parents. Returns
#  undef if the subject tag is invalid. [STATIC]
#
######################################################################


######################################################################
=pod

=item EPrints::Subject::subject_label( $subject_tag )

undocumented

=cut
######################################################################

sub subject_label
{
	my( $subject_tag ) = trim_params(@_);
	
	my $label = "";
	my $tag = $subject_tag;

	while( $tag ne $EPrints::Subject::root_subject )
	{
		my $ds = &ARCHIVE->get_dataset();
		my $data = &DATABASE->get_single( $ds, $tag );
		
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
			#cjg lang ": "
			$label = $data->{name} . ": " . $label;
		}
	}
	
	return( $label );
}


######################################################################
=pod

=item @subjects = EPrints::Subject::get_all()

Retrieve all of the subjects

=cut
######################################################################

sub get_all
{
	my @subjects = &DATABASE->get_all( &ARCHIVE->get_dataset( "subject" ) );

	return( undef ) if( scalar @subjects == 0 );

	my( %subjectmap );
	my( %rmap );
	my $subject;
	foreach $subject (@subjects)
	{
		$subjectmap{$subject->get_value("subjectid")} = $subject;
		# iffy non oo bit here.
		# guess it's ok within the same class... (maybe)
		# works fine, just a bit naughty
		foreach( @{$subject->{data}->{parents}} )
		{
			$rmap{$_} = [] if( !defined $rmap{$_} );
			push @{$rmap{$_}}, $subject;
		}
	}
	my $namefield = &ARCHIVE->get_dataset(
		"subject" )->get_field( "name" );
	foreach( keys %rmap )
	{
		#cjg note the OO busting speedup hack.
		@{$rmap{$_}} = sort {   
my $av = $namefield->most_local( $a->{data}->{name} );
my $bv = $namefield->most_local( $b->{data}->{name} );
$av = "" unless defined $av;
$bv = "" unless defined $bv;
$av cmp $bv;
			} @{$rmap{$_}};
	}

	
	return( \%subjectmap, \%rmap );
}






######################################################################
=pod

=item $foo = $thing->posted_eprints( $dataset )

undocumented

=cut
######################################################################

sub posted_eprints
{
	my( $self, $dataset ) = @_;

	my $searchexp = new EPrints::SearchExpression(
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
			$self->get_value( "subjectid" ) );
	}

	if( $n == 0 )
	{
		# no actual subject fields
		return();
	}

	my $searchid = $searchexp->perform_search;
	my @data = $searchexp->get_records;
	$searchexp->dispose();

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

#cjg Should be a recursive method that does all things for which self is
# an ancestor

######################################################################
=pod

=item $foo = $thing->count_eprints( $dataset )

undocumented

=cut
######################################################################

sub count_eprints
{
	my( $self, $dataset ) = @_;

	# Create a search expression
	my $searchexp = new EPrints::SearchExpression(
		satisfy_all => 0, 
		dataset => $dataset );

	my $n = 0;
	my $field;
	foreach $field ( $dataset->get_fields() )
	{
		next unless( $field->is_type( "subject" ) );
		$n += 1;
		$searchexp->add_field(
			$field,
			$self->get_value( "subjectid" ) );
	}

	if( $n == 0 )
	{
		# no actual subject fields
		return( 0 );
	}

	my $searchid = $searchexp->perform_search;
	my $count = $searchexp->count;
	$searchexp->dispose();

	return $count;

}




1;

######################################################################
=pod

=back

=cut

