######################################################################
#
# EPrints::MetaField::Name;
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

B<EPrints::MetaField::Name> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Name;

use strict;
use warnings;

use Unicode::String qw( latin1 utf8 );

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

my $VARCHAR_SIZE = 255;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	my $sqlname = $self->get_sql_name();
	my $param = ($notnull?" NOT NULL":"");
	my $vc = 'VARCHAR('.$VARCHAR_SIZE.')';

	return
		$sqlname.'_honourific '.$vc.' '.$param.', '.
		$sqlname.'_given '.$vc.' '.$param.', '.
		$sqlname.'_family '.$vc.' '.$param.', '.
		$sqlname.'_lineage '.$vc.' '.$param;
}

# index the family part only...
sub get_sql_index
{
	my( $self ) = @_;

	return undef unless( $self->get_property( "sql_index" ) );

	return "INDEX( ".$self->get_sql_name."_family)";
}
	
sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;

	my $order = $self->get_property( "render_opts" )->{order};
	
	# If the render opt "order" is set to "gf" then we order
	# the name with given name first. 

	return $session->render_name( 
			$value, 
			defined $order && $order eq "gf" );
}

sub get_input_bits
{
	my( $self, $session ) = @_;

	my @namebits;
	unless( $self->get_property( "hide_honourific" ) )
	{
		push @namebits, "honourific";
	}
	if( $self->get_property( "family_first" ) )
	{
		push @namebits, "family", "given";
	}
	else
	{
		push @namebits, "given", "family";
	}
	unless( $self->get_property( "hide_lineage" ) )
	{
		push @namebits, "lineage";
	}

	return @namebits;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff ) = @_;

	my $parts = [];
	foreach( $self->get_input_bits( $session ) )
	{
		my $size = $self->{input_name_cols}->{$_};
		push @{$parts}, {el=>$session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $self->{name}.$suffix."_".$_,
			value => $value->{$_},
			size => $size,
			maxlength => $self->{maxlength} ) };
	}

	return [ $parts ];
}

sub get_input_col_titles
{
	my( $self, $session, $staff ) = @_;

	my @r = ();
	foreach my $bit ( $self->get_input_bits( $session ) )
	{
		# deal with some legacy in the phrase id's
		$bit = "given_names" if( $bit eq "given" );
		$bit = "family_names" if( $bit eq "family" );
		push @r, $session->html_phrase(	"lib/metafield:".$bit );
	}
	return \@r;
}

sub form_value_basic
{
	my( $self, $session, $suffix ) = @_;
	
	my $data = {};
	foreach( "honourific", "given", "family", "lineage" )
	{
		$data->{$_} = 
			$session->param( $self->{name}.$suffix."_".$_ );
	}

	unless( EPrints::Utils::is_set( $data ) )
	{
		return( undef );
	}

	return $data;
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	return $session->render_name( $value );
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	my @a;
	foreach( "family", "lineage", "given", "honourific" )
	{
		if( defined $value->{$_} )
		{
			push @a, $value->{$_};
		}
		else
		{
			push @a, "";
		}
	}
	return join( "," , @a );
}



sub split_search_value
{
	my( $self, $session, $value ) = @_;

	# should use archive whitespaces
	# remove spaces around commas to make them single names
	$value =~ s/\s*,\s*/,/g; 

	# things in double quotes are treated as a single name
	# eg. "Harris Smith" or "Smith, J K"
	my @bits = ();
	while( $value =~ s/"([^"]+)"// )
	{
		push @bits, $1;
	}

	# if there is anything left, split it on whitespace
	if( $value !~ m/^\s+$/ )
	{
		push @bits, split /\s+/ , $value;
	}
	return @bits;
}

sub render_search_value
{
        my( $self, $session, $value ) = @_;

	my @bits = $self->split_search_value( $session, $value );
        return $session->make_text( '"'.join( '", "', @bits).'"' );
}

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	if( $match eq "EX" )
	{
		# not correct yet. Only used for browse-by-name
		return EPrints::SearchCondition->new( 
			'name_match', 
			$dataset,
			$self, 
			$search_value );
	}

	my $v2 = EPrints::Index::apply_mapping( 
			$session,
			$search_value );

	# name searches are case sensitive
	$v2 = "\L$v2";

	if( $search_mode eq "simple" )
	{
		return EPrints::SearchCondition->new( 
			'freetext', 
			$dataset,
			$self, 
			$v2 );
	}

	# split up initials
	$v2 =~ s/([A-Z])/ $1/g;

	# remove not a-z characters (except ,)
	$v2 =~ s/[^a-z,]/ /ig;

	my( $family, $given ) = split /\s*,\s*/, $v2;
	my @freetexts = ();
	foreach my $fpart ( split /\s+/, $family )
	{
		next unless EPrints::Utils::is_set( $fpart );
		push @freetexts, EPrints::SearchCondition->new( 
						'freetext', 
						$dataset,
						$self, 
						$fpart );
	}

	
	# 2 family parts or one given part make it worth
	# doing the name crop. A single family part will 
	# obviously match.
	my $noskip = 0; 

	# grep only accepts "%" and "?" as special chars
	my $list = [ '%' ];
	foreach my $fpart ( split /\s+/, $family )
	{
		next unless EPrints::Utils::is_set( $fpart );
		$list->[0] .= '['.$fpart.']%';
		++$noskip; # need at least 2 family parts to be worth cropping
	}

	$list->[0] .= '-%';
	$given = "" unless( defined $given );
	foreach my $gpart ( split /\s+/, $given )
	{
		next unless EPrints::Utils::is_set( $gpart );
		$noskip = 2;
		if( length $gpart == 1 )
		{
			# inital
			foreach my $l ( @{$list} )
			{
				$l .= '['.$gpart.'%';
			}
			next;
		}
		# a full given name
		my $nlist = [];
		foreach my $l ( @{$list} )
		{
			push @{$nlist}, $l.'['.$gpart.']%';
			$gpart =~ m/^(.)/;
			push @{$nlist}, $l.'['.$1.']%';
		}
		$list = $nlist;
	}

	if( $noskip >= 2 )
	{
		# it IS worth cropping 
		push @freetexts, EPrints::SearchCondition->new( 
						'grep', 
						$dataset,
						$self, 
						@{$list} );
	}

	return EPrints::SearchCondition->new( 'AND', @freetexts );
}

# INHERRITS get_search_conditions_not_ex, but it's not called.

sub get_search_group { return 'name'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_name_cols} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{hide_honourific} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{hide_lineage} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{family_first} = $EPrints::MetaField::FROM_CONFIG;
	return %defaults;
}

my $x=<<END;
			Glaser	Hugh/Glaser	H/Glaser	Hugh B/Glaser	Hugh Bob/Glaser	Smith Glaser
H/Glaser		X	X		X						
H/Glaser-Smith		X	X		X						.
H/Smith-Glaser		X	X		X						X
Hugh/Glaser		X	X		X						
Hugh K/Glaser		X	X		X						
Hugh-Bob/Glaser		X	X		X		X		X		
Hugh Bob/Glaser		X	X		X		X		X		
Hugh B/Glaser		X	X		X		X		X	
Hugh Bill/Glaser	X	X		X		X		 	
H B/Glaser		X	X		X		X		X 	
HB/Glaser		X	X		X		X		X 	
H P/Glaser		X	X		X						
H/Smith											
Herbert/Glaser		X			X						
Herbert/Smith					X						
Q Hugh/Glaser		X	X								
Q H/Glaser		X									

			Glaser	Hugh/Glaser	H/Glaser	Hugh B/Glaser	Hugh Bob/Glaser	Smith Glaser
H/Glaser		X	X		X						
H/Glaser-Smith		X	X		X						X
H/Smith-Glaser		X	X		X						X
Hugh/Glaser		X	X		X						
Hugh K/Glaser		X	X		X						
Hugh-Bob/Glaser		X	X		X		X		X		
Hugh Bob/Glaser		X	X		X		X		X		
Hugh B/Glaser		X	X		X		X		X	
Hugh Bill/Glaser	X	X		X		X		 	
H B/Glaser		X	X		X		X		X 	
HB/Glaser		X	X		X		X		X 	
H P/Glaser		X	X		X						
H/Smith											
Herbert/Glaser		X			X						
Herbert/Smith					X						
Q Hugh/Glaser		X	X								
Q H/Glaser		X									

		
Smith Glaser		Whole word in family IS glaser AND Whole word in family IS smith 	

Glaser			Whole word in family IS glaser	

Hugh/Glaser		Glaser + (Whole word in given is Hugh OR first initial in given is "H")

H/Glaser		Glaser + (first initial in given is "H" OR first word in given starts with "H")

Hugh B/Glaser		Glaser + (first initial in given is "H" OR first word in given is "Hugh" ) +
				(second initial in given is "B" OR second word in given starts with "B")

Hugh Bob/Glaser		Glaser + (first initial in given is "H" OR first word in given is "Hugh" ) +
				(second iniital in given is "B" or second word in given is "Bob")

Names:


BQF
*B-*Q-*F-*

Ben Quantum Fierdash				[B][Q][Fierdash]
*(Ben|B)*(Quantum|Q)*(Fierdash|F)*
%[B]%[Q]%[F]%
%[B]%[Q]%[Fierdash]%
%[B]%[Quantum]%[F]%
%[B]%[Quantum]%[Fierdash]%
%[Ben]%[Q]%[F]%
%[Ben]%[Q]%[Fierdash]%
%[Ben]%[Quantum]%[F]%
%[Ben]%[Quantum]%[Fierdash]%

[Geddes][Harris]|[B][Q][Fierdash]

Ben F
*(Ben|B)*(F-)*

Ben
*(Ben|B)*

Quantum
*(Quantum|Q)*

Q
*(Q-)*



[John][Mike][H]-[Smith][Jones]

*[J*[M*-*[Jones]*

*[J]*-*[Smith]* AND *[John]*-*[Smith]*


END


sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	my $f = &EPrints::Index::apply_mapping( $session, $value->{family} );
	my $g = &EPrints::Index::apply_mapping( $session, $value->{given} );

	# Add a space before all capitals to break
	# up initials. Will screw up names with capital
	# letters in the middle of words. But that's
	# pretty rare.
	my $len_g = $g->length;
        my $new_g = utf8( "" );
        for(my $i = 0; $i<$len_g; ++$i )
        {
                my $s = $g->substr( $i, 1 );
                if( $s eq "\U$s" )
                {
			$new_g .= ' ';
                }
		$new_g .= $s;
	}

	my $code = '';
	my @r = ();
	foreach( EPrints::Index::split_words( $session, $f ) )
	{
		next if( $_ eq "" );
		push @r, "\L$_";
		$code.= "[\L$_]";
	}
	$code.= "-";
	foreach( EPrints::Index::split_words( $session, $new_g ) )
	{
		next if( $_ eq "" );
#		push @r, "given:\L$_";
		$code.= "[\L$_]";
	}
	return( \@r, [$code], [] );
}	

######################################################################
1;
