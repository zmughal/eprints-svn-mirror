######################################################################
#
# EPrints::Index
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

B<EPrints::Index> - Methods for indexing objects for later searching.

=head1 DESCRIPTION

This module contains methods used to add and remove information from
the free-text search indexes. 

=head1 FUNCTIONS

=over 4

=cut


package EPrints::Index;

use Unicode::String qw( latin1 utf8 );

use strict;


######################################################################
=pod

=item EPrints::Index::remove( $session, $dataset, $objectid, $fieldid )

Remove all indexes to the field in the specified object.

=cut
######################################################################

sub remove
{
	my( $session, $dataset, $objectid, $fieldid ) = @_;

	my $rv = 1;

	my $sql;

	my $keyfield = $dataset->get_key_field();
	my $where = $keyfield->get_sql_name()." = \"$objectid\" AND field=\"".EPrints::Database::prep_value($fieldid)."\"";

	my $indextable = $dataset->get_sql_index_table_name();
	my $rindextable = $dataset->get_sql_rindex_table_name();

	$sql = "SELECT word FROM $rindextable WHERE $where";
	my $sth=$session->get_db->prepare( $sql );
	$rv = $rv && $session->get_db->execute( $sth, $sql );
	my @codes = ();
	while( my( $c ) = $sth->fetchrow_array )
	{
		push @codes,$c;
	}
	$sth->finish;

	foreach my $code ( @codes )
	{
		my $fieldword = EPrints::Database::prep_value( "$fieldid:$code" );
		$sql = "SELECT ids,pos FROM $indextable WHERE fieldword='$fieldword' AND ids LIKE '%:$objectid:%'";
		$sth=$session->get_db->prepare( $sql );
		$rv = $rv && $session->get_db->execute( $sth, $sql );
		if( my($ids,$pos) = $sth->fetchrow_array )
		{
			$ids =~ s/:$objectid:/:/g;
			$sql = "UPDATE $indextable SET ids = '$ids' WHERE fieldword='$fieldword' AND pos='$pos'";
			$rv = $rv && $session->get_db->do( $sql );
		}
		$sth->finish;
	}
	$sql = "DELETE FROM $rindextable WHERE $where";
	$rv = $rv && $session->get_db->do( $sql );

	return $rv;
}

######################################################################
=pod

=item EPrints::Index::purge_index( $session, $dataset )

Remove all the current index information for the given dataset. Only
really useful if used in conjunction with rebuilding the indexes.

=cut
######################################################################

sub purge_index
{
	my( $session, $dataset ) = @_;

	my $indextable = $dataset->get_sql_index_table_name();
	my $rindextable = $dataset->get_sql_rindex_table_name();
	my $sql;
	$session->get_db->do( "DELETE FROM $indextable" );
	$session->get_db->do( "DELETE FROM $rindextable" );
	return;
}


######################################################################
=pod

=item EPrints::Index::add( $session, $dataset, $objectid, $fieldid, $value )

Add indexes to the field in the specified object. The index keys will
be taken from value.

=cut
######################################################################

sub add
{
	my( $session, $dataset, $objectid, $fieldid, $value ) = @_;

	my $field = $dataset->get_field( $fieldid );

	if( $field->get_property( "hasid" ) )
	{
		#push @fields,$field->get_id_field();
		$field = $field->get_main_field();
	}

	my( $codes, $grepcodes, $ignored ) = $field->get_index_codes( $session, $value );

	my %done = ();

	my $keyfield = $dataset->get_key_field();

	my $indextable = $dataset->get_sql_index_table_name();
	my $rindextable = $dataset->get_sql_rindex_table_name();

	my $rv = 1;
	
	foreach my $code ( @{$codes} )
	{
		next if $done{$code};
		$done{$code} = 1;
		my $sql;
		my $fieldword = EPrints::Database::prep_value($field->get_sql_name().":$code");
		my $sth;
		$sql = "SELECT max(pos) FROM $indextable where fieldword='$fieldword'"; 
		$sth=$session->get_db->prepare( $sql );
		$rv = $rv && $session->get_db->execute( $sth, $sql );
		return 0 unless $rv;
		my ( $n ) = $sth->fetchrow_array;
		$sth->finish;
		my $insert = 0;
		if( !defined $n )
		{
			$n = 0;
			$insert = 1;
		}
		else
		{
			$sql = "SELECT ids FROM $indextable WHERE fieldword='$fieldword' AND pos=$n"; 
			$sth=$session->get_db->prepare( $sql );
			$rv = $rv && $session->get_db->execute( $sth, $sql );
			my( $ids ) = $sth->fetchrow_array;
			$sth->finish;
			my( @list ) = split( ":",$ids );
			# don't forget the first and last are empty!
			if( (scalar @list)-2 < 128 )
			{
				$sql = "UPDATE $indextable SET ids='$ids$objectid:' WHERE fieldword='$fieldword' AND pos=$n";	
				$rv = $rv && $session->get_db->do( $sql );
				return 0 unless $rv;
			}
			else
			{
				++$n;
				$insert = 1;
			}
		}
		if( $insert )
		{
			$sql = "INSERT INTO $indextable (fieldword,pos,ids ) VALUES ('$fieldword',$n,':$objectid:')";
			$rv = $rv && $session->get_db->do( $sql );
			return 0 unless $rv;
		}
		$sql = "INSERT INTO $rindextable (field,word,".$keyfield->get_sql_name()." ) VALUES ('".$field->get_sql_name."','$code','$objectid')";
		$rv = $rv && $session->get_db->do( $sql );
		return 0 unless $rv;

	} 

	my $name = $field->get_name;

	foreach my $grepcode ( @{$grepcodes} )
	{
		my $sql = "INSERT INTO ".$dataset->get_sql_grep_table_name." VALUES ('".
EPrints::Database::prep_value($objectid)."','".EPrints::Database::prep_value($name)."','".EPrints::Database::prep_value($grepcode)."');";
		$session->get_db->do( $sql ); 
	}
}





######################################################################
=pod

=item EPrints::Index::update_ordervalues( $session, $dataset, $data )

Update the order values for an object. $data is a structure
returned by $dataobj->get_data

=cut
######################################################################

# $tmp should not be used any more.

sub update_ordervalues
{
        my( $session, $dataset, $data, $tmp ) = @_;

	&_do_ordervalues( $session, $dataset, $data, 0, $tmp );	
}

######################################################################
=pod

=item EPrints::Index::update_ordervalues( $session, $dataset, $data )

Create the order values for an object. $data is a structure
returned by $dataobj->get_data

=cut
######################################################################

sub insert_ordervalues
{
        my( $session, $dataset, $data, $tmp ) = @_;

	&_do_ordervalues( $session, $dataset, $data, 1, $tmp );	
}

# internal method to avoid code duplication. Update and insert are
# very similar.

sub _do_ordervalues
{
        my( $session, $dataset, $data, $insert, $tmp ) = @_;

	# insert = 0 => update
	# insert = 1 => insert
	# tmp = 1 = use_tmp_table
	# tmp = 0 = use normal table

	my @fields = $dataset->get_fields( 1 );

	# remove the key field
	splice( @fields, 0, 1 ); 
	my $keyfield = $dataset->get_key_field();
	my $keyvalue = EPrints::Database::prep_value( $data->{$keyfield->get_sql_name()} );
	my @orderfields = ( $keyfield );

	foreach my $langid ( @{$session->get_archive()->get_conf( "languages" )} )
	{
		my @fnames = ( $keyfield->get_sql_name() );
		my @fvals = ( $keyvalue );
		foreach my $field ( @fields )
		{
			next if( $field->is_type( "subobject","file" ) );
			my $ov = $field->ordervalue( 
					$data->{$field->get_name()},
					$session,
					$langid );
			
			push @fnames, $field->get_sql_name();
			push @fvals, EPrints::Database::prep_value( $ov );
		}

		# cjg raw SQL!
		my $ovt = $dataset->get_ordervalues_table_name( $langid );
		if( $tmp ) { $ovt .= "_tmp"; }
		my $sql;
		if( $insert )
		{
			$sql = "INSERT INTO ".$ovt." (".join( ",", @fnames ).") VALUES (\"".join( "\",\"", @fvals )."\")";
		}
		else
		{
			my @l = ();
			for( my $i=0; $i<scalar @fnames; ++$i )
			{
				push @l, $fnames[$i].'="'.$fvals[$i].'"';
			}
			$sql = "UPDATE ".$ovt." SET ".join( ",", @l )." WHERE ".$keyfield->get_sql_name().' = "'.EPrints::Database::prep_value( $keyvalue ).'"';
		}
		$session->get_db->do( $sql );
	}
}

######################################################################
=pod

=item EPrints::Index::delete_ordervalues( $session, $dataset, $id )

Remove the ordervalues for item $id from the ordervalues table of
$dataset.

=cut
######################################################################

sub delete_ordervalues
{
        my( $session, $dataset, $id, $tmp ) = @_;

	my @fields = $dataset->get_fields( 1 );

	# remove the key field
	splice( @fields, 0, 1 ); 
	my $keyfield = $dataset->get_key_field();
	my $keyvalue = EPrints::Database::prep_value( $id );

	foreach my $langid ( @{$session->get_archive()->get_conf( "languages" )} )
	{
		# cjg raw SQL!
		my $ovt = $dataset->get_ordervalues_table_name( $langid );
		if( $tmp ) { $ovt .= "_tmp"; }
		my $sql;
		$sql = "DELETE FROM ".$ovt." WHERE ".$keyfield->get_sql_name().' = "'.EPrints::Database::prep_value( $keyvalue ).'"';
		$session->get_db->do( $sql );
	}
}

######################################################################
=pod

=item @words = EPrints::Index::split_words( $session, $utext )

Splits a utf8 string into individual words. 

=cut
######################################################################

sub split_words
{
	my( $session, $utext ) = @_;

	my $len = $utext->length;
        my @words = ();
        my $cword = utf8( "" );
        for(my $i = 0; $i<$len; ++$i )
        {
                my $s = $utext->substr( $i, 1 );
                # $s is now char number $i
                if( defined $EPrints::Index::FREETEXT_SEPERATOR_CHARS->{$s} || ord($s)<32 )
                {
                        push @words, $cword unless( $cword eq "" ); 
                        $cword = utf8( "" );
                }
                else
                {
                        $cword .= $s;
                }
        }
	push @words, $cword unless( $cword eq "" ); 

	return @words;
}


######################################################################
=pod

=item $utext2 = EPrints::Index::apply_mapping( $session, $utext )

Replaces certain unicode characters with ASCII equivalents and returns
the new string.

This is used before indexing words so that things like umlauts will
be ignored when searching.

=cut
######################################################################

sub apply_mapping
{
	my( $session, $text ) = @_;

	$text = "" if( !defined $text );
	my $utext = utf8( "$text" ); # just in case it wasn't already.
	my $len = $utext->length;
	my $buffer = utf8( "" );
	for( my $i = 0; $i<$len; ++$i )
	{
		my $s = $utext->substr( $i, 1 );
		# $s is now char number $i
		if( defined $EPrints::Index::FREETEXT_CHAR_MAPPING->{$s} )
		{
			$s = $EPrints::Index::FREETEXT_CHAR_MAPPING->{$s};
		} 
		$buffer.=$s;
	}

	return $buffer;
}


# This map is used to convert Unicode characters
# to ASCII characters below 127, in the word index.
# This means that the word F�te is indexed as 'fete' and
# "fete" or "f�te" will match it.
# There's no reason mappings have to be a single character.

$EPrints::Index::FREETEXT_CHAR_MAPPING = {

	# Basic latin1 mappings
	latin1("�") => "!",	latin1("�") => "c",	
	latin1("�") => "L",	latin1("�") => "o",	
	latin1("�") => "Y",	latin1("�") => "|",	
	latin1("�") => "S",	latin1("�") => "\"",	
	latin1("�") => "(c)",	latin1("�") => "a",	
	latin1("�") => "<<",	latin1("�") => "-",	
	latin1("�") => "-",	latin1("�") => "(R)",	
	latin1("�") => "-",	latin1("�") => "o",	
	latin1("�") => "+-",	latin1("�") => "2",	
	latin1("�") => "3",	latin1("�") => "'",	
	latin1("�") => "u",	latin1("�") => "q",	
	latin1("�") => ".",	latin1("�") => ",",	
	latin1("�") => "1",	latin1("�") => "o",	
	latin1("�") => ">>",	latin1("�") => "1/4",	
	latin1("�") => "1/2",	latin1("�") => "3/4",	
	latin1("�") => "?",	latin1("�") => "A",	
	latin1("�") => "A",	latin1("�") => "A",	
	latin1("�") => "A",	latin1("�") => "A",	
	latin1("�") => "A",	latin1("�") => "AE",	
	latin1("�") => "C",	latin1("�") => "E",	
	latin1("�") => "E",	latin1("�") => "E",	
	latin1("�") => "E",	latin1("�") => "I",	
	latin1("�") => "I",	latin1("�") => "I",	
	latin1("�") => "I",	latin1("�") => "D",	
	latin1("�") => "N",	latin1("�") => "O",	
	latin1("�") => "O",	latin1("�") => "O",	
	latin1("�") => "O",	latin1("�") => "O",	
	latin1("�") => "x",	latin1("�") => "O",	
	latin1("�") => "U",	latin1("�") => "U",	
	latin1("�") => "U",	latin1("�") => "U",	
	latin1("�") => "Y",	latin1("�") => "TH",	
	latin1("�") => "B",	latin1("�") => "a",	
	latin1("�") => "a",	latin1("�") => "a",	
	latin1("�") => "a",	latin1("�") => "a",	
	latin1("�") => "a",	latin1("�") => "ae",	
	latin1("�") => "c",	latin1("�") => "e",	
	latin1("�") => "e",	latin1("�") => "e",	
	latin1("�") => "e",	latin1("�") => "i",	
	latin1("�") => "i",	latin1("�") => "i",	
	latin1("�") => "i",	latin1("�") => "d",	
	latin1("�") => "n",	latin1("�") => "o",	
	latin1("�") => "o",	latin1("�") => "o",	
	latin1("�") => "o",	latin1("�") => "o",	
	latin1("�") => "/",	latin1("�") => "o",	
	latin1("�") => "u",	latin1("�") => "u",	
	latin1("�") => "u",	latin1("�") => "u",	
	latin1("�") => "y",	latin1("�") => "th",	
	latin1("�") => "y",	latin1("'") => "",

	# Hungarian characters. 
	'�' => "o",	
	'Ő' => "o",  
	'ű' => "u",  
	'Ű' => "u",
 };

# Minimum size word to normally index.
$EPrints::Index::FREETEXT_MIN_WORD_SIZE = 3;

# We use a hash rather than an array for good and bad
# words as we only use these to lookup if words are in
# them or not. If we used arrays and we had lots of words
# it might slow things down.

# Words to never index, despite their length.
$EPrints::Index::FREETEXT_STOP_WORDS = {
	"this"=>1,	"are"=>1,	"which"=>1,	"with"=>1,
	"that"=>1,	"can"=>1,	"from"=>1,	"these"=>1,
	"those"=>1,	"the"=>1,	"you"=>1,	"for"=>1,
	"been"=>1,	"have"=>1,	"were"=>1,	"what"=>1,
	"where"=>1,	"is"=>1,	"and"=>1, 	"fnord"=>1
};

# Words to always index, despite their length.
$EPrints::Index::FREETEXT_ALWAYS_WORDS = {
		"ok" => 1 
};

# Chars which seperate words. Pretty much anything except
# A-Z a-z 0-9 and single quote '

# If you want to add other seperator characters then they
# should be encoded in utf8. The Unicode::String man page
# details some useful methods.

$EPrints::Index::FREETEXT_SEPERATOR_CHARS = {
	'@' => 1, 	'[' => 1, 	'\\' => 1, 	']' => 1,
	'^' => 1, 	'_' => 1,	' ' => 1, 	'`' => 1,
	'!' => 1, 	'"' => 1, 	'#' => 1, 	'$' => 1,
	'%' => 1, 	'&' => 1, 	'(' => 1, 	')' => 1,
	'*' => 1, 	'+' => 1, 	',' => 1, 	'-' => 1,
	'.' => 1, 	'/' => 1, 	':' => 1, 	';' => 1,
	'{' => 1, 	'<' => 1, 	'|' => 1, 	'=' => 1,
	'}' => 1, 	'>' => 1, 	'~' => 1, 	'?' => 1
};

	
1;

######################################################################
=pod

=back

=cut

