package EPrints::MetaField::Coversheet;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField::Set );
}

use EPrints::MetaField::Set;

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	my $coversheet = new EPrints::DataObj::Coversheet( $session, $value );
	if( !defined $coversheet )
	{
		return $session->make_text( "?? $value ??" );
	}

	return $session->make_text($coversheet->get_value('name'));
}

sub render_option
{
	my( $self, $session, $option ) = @_;

	if( defined $self->get_property("render_option") )
	{
		return $self->call_property( "render_option", $session, $option );
	}

	if( !defined $option )
	{
		return $self->SUPER::render_option( $session, $option );
	}

	my $coversheet = new EPrints::DataObj::Coversheet( $session, $option );

	return $session->make_text($coversheet->get_value('name'));
}

sub _create_pairs
{
	my ($self, $session) = @_;

        my $pairs = [];

        my $admin = 0;
        $admin = 1 if (
		( defined $session->current_user ) and 
		( $session->current_user()->get_value('usertype') eq 'admin' ) 
	);

        my $searchexp = EPrints::Search->new(
                allow_blank => 1,
                dataset => $session->get_repository->get_dataset('coversheet'),
                session => $session,
                custom_order => 'name' );
        unless ($admin)
        {
                $searchexp->add_field($session->get_repository->get_dataset('coversheet')->get_field("status"), 'active');
        }
        my $list = $searchexp->perform_search;

        foreach my $coversheet ($list->get_records)
        {
                my $status = $coversheet->get_value('status');
                my $label = $coversheet->get_value('name');
                $label = $label . " ($status)" if $admin;
                push @{$pairs}, [ $coversheet->get_id, $label ];
        }
	return $pairs;
}


#sub render_input_field
#{



#}

sub render_set_input
{
	my( $self, $session, $default, $required, $obj, $basename ) = @_;

	my $pairs = $self->_create_pairs($session);

	if( !$self->get_property( "multiple" ) && 
		!$required )
	{
		# If it's not multiple and not required there 
		# must be a way to unselect it.
		my $unspec = $session->phrase( 
			"lib/metafield:unspecified_selection" ) ;
		$pairs = [ [ "", $unspec ], @{$pairs} ];
	}

	return $session->render_option_list(
		pairs => $pairs,
		defaults_at_top => 1,
		name => $basename,
		id => $basename,
		default => $default,
		multiple => $self->{multiple},
		height => $self->{input_rows}  );

} 

#Copied from subject metafield, but unused
#sub get_unsorted_values
#{
#	my( $self, $session, $dataset, %opts ) = @_;
#
#	my $topsubj = $self->get_top_subject( $session );
#	my ( $pairs ) = $topsubj->get_subjects( 
#		0 , 
#		!$opts{hidetoplevel} , 
#		$opts{nestids} );
#	my $pair;
#	my $v = [];
#	foreach $pair ( @{$pairs} )
#	{
#		push @{$v}, $pair->[0];
#	}
#	return $v;
#}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	my $coversheet = EPrints::DataObj::Coversheet->new( $session, $value );
	if( !defined $coversheet )
	{
		return $session->make_text( 
			"?? Bad Coversheet: ".$value." ??" );
	}
	return $coversheet->render_description();
}





sub render_search_set_input
{
	my( $self, $session, $searchfield ) = @_;

	my $prefix = $searchfield->get_form_prefix;
	my $value = $searchfield->get_value;

	my $pairs = $self->_create_pairs($session);
	
	my $max_rows =  $self->get_property( "search_rows" );

	#splice( @{$pairs}, 0, 0, [ "NONE", "(Any)" ] ); #cjg

	my $height = scalar @$pairs;
	$height = $max_rows if( $height > $max_rows );

	my @defaults = ();
	# Do we have any values already?
	if( defined $value && $value ne "" )
	{
		@defaults = split /\s/, $value;
	}

	return $session->render_option_list( 
		name => $prefix,
		defaults_at_top => 1,
		default => \@defaults,
		multiple => 1,
		pairs => $pairs,
		height => $height );
}	

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	return EPrints::Search::Condition->new( 
		'=', 
		$dataset,
		$self, 
		$search_value );
}

sub get_search_group { return 'coversheet'; }


sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_style} = 0;
#	$defaults{showall} = 0;
#	$defaults{showtop} = 0;
#	$defaults{nestids} = 1;
#	$defaults{top} = "subjects";
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}

sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

        my $admin = 0;
        $admin = 1 if ( 
		( defined $session->current_user()) and
		( $session->current_user()->get_value('usertype') eq 'admin' )
	);

        my $searchexp = EPrints::Search->new(
                allow_blank => 1,
                dataset => $session->get_repository->get_dataset('coversheet'),
                session => $session,
                custom_order => 'name' );
        unless ($admin)
        {
                $searchexp->add_field($session->get_repository->get_dataset('coversheet')->get_field("status"), 'active');
        }
        my $list = $searchexp->perform_search;
	return $list->get_ids;
}

sub tags
{
	my( $self, $session ) = @_;

	return @{$self->get_values( $session )};
}

######################################################################
1;
