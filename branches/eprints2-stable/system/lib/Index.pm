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

B<EPrints::Index> - 
metadata as images.

=head1 DESCRIPTION

???

=over 4

=cut

######################################################################

package EPrints::Index;

use EPrints::Session;

use Unicode::String qw( latin1 utf8 );

use strict;

#my $index = new EPrints::Index( $session->get_archive->get_dataset( "archive" ) );
#$index->create;
#$index->build;
#$index->install;
#$index->dispose;



######################################################################
=pod

=item $index = EPrints::Index->new( $session, $dataset )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $session, $dataset ) = @_;

	my $self = { 
		dataset=>$dataset, 
		session=>$session,
		count=>0,
		index_table_tmp => $dataset->get_sql_index_table_name."_tmp",
		names_index_table_tmp => $dataset->get_sql_index_table_name."_names_tmp" 
	};

	bless $self, $class;

	return $self;
}

######################################################################
=pod

=item $index->dispose();

undocumented

=cut
######################################################################

sub dispose
{
	my( $self ) = @_;

	# destroy any tmp tables that didn't get renamed for some
	# reason.

	my $ds = $self->{dataset};
	my $db = $self->{session}->get_db;

	my @doomtables = ( $self->{index_table_tmp}, $self->{names_index_table_tmp} );

	foreach my $langid ( @{$self->{session}->get_archive()->get_conf( "languages" )} )
	{
		push @doomtables, $ds->get_ordervalues_table_name( $langid )."_tmp";
	}

	foreach my $table ( @doomtables )
	{
		next unless( $db->has_table( $table ) );
		drop_table( $self->{session}->get_db, $table ); 
	}
}

######################################################################
=pod

=item $success = $index->create();

undocumented

=cut
######################################################################

sub create
{
	my( $self ) = @_;

	my $ds = $self->{dataset};

	my $rv = 1;

	my $keyfield = $ds->get_key_field()->clone;
	my $db = $self->{session}->get_db;

	my $fieldpos = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "pos", 
		type => "int" );
	my $fieldword = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "fieldword", 
		type => "text");
	my $fieldids = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "ids", 
		type => "longtext");

	if( $db->has_table( $self->{index_table_tmp} ) )
	{
		print STDERR "$self->{index_table_tmp} already exists. Indexer exited abnormally or still running?\nZAPPING IT!";
		#cjg!
		my $sql = "DROP TABLE $self->{index_table_tmp}";
		$self->{session}->get_db->do( $sql );
	}
	
	$rv = $rv & $db->create_table(
		$self->{index_table_tmp},
		$ds,
		0, # no primary key
		( $fieldword, $fieldpos, $fieldids ) );

	#######################

		
	my $fieldfieldname = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "fieldname", 
		type => "text" );
	my $fieldnamestring = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "namestring", 
		type => "text");

	if( $db->has_table( $self->{names_index_table_tmp} ) )
	{
		print STDERR "$self->{names_index_table_tmp} already exists. Indexer exited abnormally or still running?\nZAPPING IT!";
		#cjg!
		my $sql = "DROP TABLE $self->{names_index_table_tmp}";
		$self->{session}->get_db->do( $sql );
	}
	

	$rv = $rv & $db->create_table(
		$self->{names_index_table_tmp},
		$ds,
		0, # no primary key
		( $keyfield, $fieldfieldname, $fieldnamestring ) );


	###########################
	return 0 unless $rv;

	# Create sort values table. These will be used when ordering search
	# results.
	my @fields = $ds->get_fields( 1 );
	# remove the key field
	splice( @fields, 0, 1 ); 
	my @orderfields = ( $keyfield );
	my $langid;
	foreach( @fields )
	{
		my $fname = $_->get_sql_name();
		push @orderfields, EPrints::MetaField->new( 
					archive=> $self->{session}->get_archive(),
					name => $fname,
					type => "longtext" );
	}
	foreach $langid ( @{$self->{session}->get_archive()->get_conf( "languages" )} )
	{
		my $order_table_tmp = $ds->get_ordervalues_table_name( $langid )."_tmp";
		if( $db->has_table( $order_table_tmp ) )
		{
			print STDERR "$order_table_tmp already exists. Indexer exited abnormally or still running?\nZAPPING IT!\n";
			#cjg!
			my $sql = "DROP TABLE $order_table_tmp";
			$self->{session}->get_db->do( $sql );
		}

		$rv = $rv && $db->create_table( 
			$order_table_tmp,
			$ds, 
			1, 
			@orderfields );
		return 0 unless $rv;
	}
}

######################################################################
=pod

=item $success = $index->build();

undocumented

=cut
######################################################################

sub build
{
	my( $self ) = @_;

	my $ds = $self->{dataset};

	my $info = {
		allkeys => {},
		indexer => $self,
		rows => 0 };

	$self->{count} = 0;
	$ds->map( $self->{session}, \&_index_item, $info );


	# store all keys which didn't already get stored

	foreach my $key ( keys %{$info->{allkeys}} )
	{
		$self->_store( $info, $key );
	}
}

sub _index_item
{
        my( $session, $dataset, $item, $info ) = @_;

	my $id = $item->get_id;

	my $keys = {};
	my $namecodes = [];
	EPrints::Index::index_object( $session, $item, $keys, $namecodes );
	foreach my $key ( keys %{$keys} )
	{
		push @{$info->{allkeys}->{$key}}, $id;
		if( scalar @{$info->{allkeys}->{$key}} > 100 )
		{
			$info->{indexer}->_store( $info, $key );
		} 
	}
	foreach my $code ( @{$namecodes} )
	{
		my $sql = "INSERT INTO ".$info->{indexer}->{names_index_table_tmp}." VALUES ('".$item->get_id."','".$code->[0]."','".$code->[1]."');";
		$session->get_db->do( $sql ); #cjg
	}


	# create order values

	my @fields = $dataset->get_fields( 1 );
	my $data = $item->get_data;

	# remove the key field
	splice( @fields, 0, 1 ); 
	my $keyfield = $dataset->get_key_field();
	my $keyvalue = EPrints::Database::prep_value( $data->{$keyfield->get_sql_name()} );
	my @orderfields = ( $keyfield );

	my $langid;
	foreach $langid ( @{$session->get_archive()->get_conf( "languages" )} )
	{
		my @fnames = ( $keyfield->get_sql_name() );
		my @fvals = ( $keyvalue );
		foreach( @fields )
		{
			my $ov = $_->ordervalue( 
					$data->{$_->get_name()},
					$session,
					$langid );
			
			push @fnames, $_->get_sql_name();
			push @fvals, EPrints::Database::prep_value( $ov );
		}

		# cjg raw SQL!
		my $ovt = $dataset->get_ordervalues_table_name( $langid );
		my $sql = "INSERT INTO ".$ovt."_tmp (".join( ",", @fnames ).") VALUES (\"".join( "\",\"", @fvals )."\")";
		$session->get_db->do( $sql );
	}

	# add to count

	sleep 1 if( $info->{indexer}->{count} % 10 == 0);

	$info->{indexer}->{count}++;
}


sub _store
{
	my( $self, $info, $key ) = @_;

	my $sql = "INSERT INTO $self->{index_table_tmp} VALUES ( '$key', $info->{rows}, '".join( ':',  @{$info->{allkeys}->{$key}} )."' )";
	$self->{session}->get_db->do( $sql );
	
	$info->{rows}++;
	delete $info->{allkeys}->{$key};
}

######################################################################
=pod

=item $success = $index->install();

undocumented

=cut
######################################################################

sub install
{
	my( $self ) = @_;

	my $db = $self->{session}->get_db;

	if( $db->has_table( $self->{index_table_tmp} ) )
	{
		install_table( 
			$self->{session}->get_db,
			$self->{index_table_tmp}, 
			$self->{dataset}->get_sql_index_table_name );
	}
	else
	{
		$self->{session}->get_archive->log( "Table does not exist to install: ".$self->{index_table_tmp} );
	}


	if( $db->has_table( $self->{names_index_table_tmp} ) )
	{
		install_table( 
			$self->{session}->get_db,
			$self->{names_index_table_tmp}, 
			$self->{dataset}->get_sql_index_table_name."_names" );
	}
	else
	{
		$self->{session}->get_archive->log( "Table does not exist to install: ".$self->{names_index_table_tmp} );
	}


	foreach my $langid ( @{$self->{session}->get_archive()->get_conf( "languages" )} )
	{
		my $order_table = $self->{dataset}->get_ordervalues_table_name( $langid );
		my $order_table_tmp = $order_table.'_tmp';

		if( !$db->has_table( $order_table_tmp ) )
		{
			$self->{session}->get_archive->log( "Table does not exist to install: ".$order_table_tmp );
			next;
		}

		install_table( 
			$self->{session}->get_db,
			$order_table_tmp,
			$order_table );
	}

	my $statusfile = $self->{session}->get_archive->get_conf( "variables_path" ).
		"/index-".$self->{dataset}->id.".timestamp";

	unless( open( TIMESTAMP, ">$statusfile" ) )
	{
		$self->{session}->get_archive->log( "EPrints::Index::install failed to open\n$statusfile\nfor writing." );
	}
	else
	{
		my $dsid =  $self->{dataset}->id;
		print TIMESTAMP <<END;
# This file is automatically generated to indicate the last time
# this archive successfully completed indexing the $dsid
# dataset. It should not be edited.
END
		print TIMESTAMP EPrints::Utils::get_timestamp()."\n";
		print TIMESTAMP "RECORDS: ".$self->{count}."\n";
		close TIMESTAMP;
	}
}

sub install_table
{
	my( $db, $current_pos, $target_pos ) = @_;

	if( $db->has_table( $target_pos ) )
	{
		swap_tables( 
			$db,
			$current_pos,
			$target_pos );
		drop_table( 
			$db,
			$current_pos );
		return;
	}

	rename_table( 
		$db,
		$current_pos,
		$target_pos );
}
		
	
sub drop_table
{
	my( $db, $tablename ) = @_;

	my $sql = "DROP TABLE ".$tablename;
	$db->do( $sql );
}

sub rename_table
{
	my( $db, $table_from, $table_to ) = @_;

	my $sql = "RENAME TABLE $table_from TO $table_to";
	$db->do( $sql );
}

sub swap_tables
{
	my( $db, $table_a, $table_b ) = @_;

	my $tmp = $table_a.'_swap';
	my $sql = "RENAME TABLE $table_a TO $tmp, $table_b TO $table_a, $tmp TO $table_b";
	$db->do( $sql );
}

######################################################################
=pod

=item index_object( $session, $object, $keys )

undocumented

=cut
######################################################################


sub index_object
{
	my( $session, $object, $keys, $namecodes ) = @_;

	my $ds = $object->get_dataset;
	my @fields = $ds->get_fields( 1 );
	if( $object->get_dataset->confid eq "eprint" )
	{
		push @fields, $ds->get_field( "_fulltext" );
	}

	foreach my $field ( @fields )
	{
		my( $codes, $new_namecodes, $badwords ) = 
			get_codes( $session, $ds, $field, $object );

		my $name = $field->get_name;
		foreach my $key ( @{$codes} )
		{

			$keys->{$name.":".$key} = 1;
		}
		foreach my $namecode ( @{$new_namecodes} )
		{
			push @{$namecodes}, [ $name, $namecode ];
		}
	}
}

sub get_codes
{
	my( $session, $dataset, $field, $object ) = @_;

	if( !$field->is_text_indexable && !$field->is_type( "name" ) )
	{
		return( [], [], [] );
	}

	if( $field->get_name eq "_fulltext" )
	{
		my @docs = $object->get_all_documents;
		my $codes = [];
		my $badwords = [];
		foreach my $doc ( @docs )
		{
			my( $doccodes, $docbadwords );
			( $doccodes, $docbadwords ) = 
					$session->get_archive()->call( 
						"extract_words",
						$doc->get_text );
			push @{$codes},@{$doccodes};
			push @{$badwords},@{$docbadwords};
		}
		return( $codes, [], $badwords );
	}

	my $value = $object->get_value( $field->get_name, 1 );

	return( [], [], [] )unless( EPrints::Utils::is_set( $value ));

	if( $field->is_type( "name" ) )
	{
		my( $codes, $namecodes ) = 
			_extract_from_name( $value, $session );
		return( $codes, $namecodes, [] );
	}

	my( $codes, $badwords ) = 
		$session->get_archive()->call( 
			"extract_words" , 
			$value );
	return( $codes, [], $badwords );
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






sub _extract_from_name
{
	my( $value, $session ) = @_;

	if( ref($value) eq "ARRAY" )
	{
		my @r = ();
		my @codes = ();
		foreach( @{$value} ) 
		{ 
			my( $nameparts, $namecodes ) = _extract_from_name2( $_, $session );
			push @r, @{$nameparts};
			push @codes, @{$namecodes};
		}
		return( \@r, \@codes );
	}

	return _extract_from_name2( $value, $session ); 
}

sub _extract_from_name2
{
	my( $name, $session ) = @_;

	my $f = &apply_mapping( $session, $name->{family} );
	my $g = &apply_mapping( $session, $name->{given} );

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
	foreach( split_words( $session, $f ) )
	{
		next if( $_ eq "" );
		push @r, "\L$_";
		$code.= "[\L$_]";
	}
	$code.= "-";
	foreach( split_words( $session, $new_g ) )
	{
		next if( $_ eq "" );
#		push @r, "given:\L$_";
		$code.= "[\L$_]";
	}

	return( \@r, [$code] );
}	

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
                        push @words, $cword; # even if it's empty       
                        $cword = utf8( "" );
                }
                else
                {
                        $cword .= $s;
                }
        }
        push @words,$cword;

	return @words;
}

sub stem_word
{
	my( $session, $word ) = @_;

	my $newword = "\L$word";
	$newword =~ s/s$//;
	return $newword;
}


sub apply_mapping
{
	my( $session, $text ) = @_;

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


# This map is used to convert ASCII characters over
# 127 to characters below 127, in the word index.
# This means that the word Fête is indexed as 'fete' and
# "fete" or "fête" will match it.
# There's no reason mappings have to be a single character.

$EPrints::Index::FREETEXT_CHAR_MAPPING = {
	latin1("¡") => "!",	latin1("¢") => "c",	
	latin1("£") => "L",	latin1("¤") => "o",	
	latin1("¥") => "Y",	latin1("¦") => "|",	
	latin1("§") => "S",	latin1("¨") => "\"",	
	latin1("©") => "(c)",	latin1("ª") => "a",	
	latin1("«") => "<<",	latin1("¬") => "-",	
	latin1("­") => "-",	latin1("®") => "(R)",	
	latin1("¯") => "-",	latin1("°") => "o",	
	latin1("±") => "+-",	latin1("²") => "2",	
	latin1("³") => "3",	latin1("´") => "'",	
	latin1("µ") => "u",	latin1("¶") => "q",	
	latin1("·") => ".",	latin1("¸") => ",",	
	latin1("¹") => "1",	latin1("º") => "o",	
	latin1("»") => ">>",	latin1("¼") => "1/4",	
	latin1("½") => "1/2",	latin1("¾") => "3/4",	
	latin1("¿") => "?",	latin1("À") => "A",	
	latin1("Á") => "A",	latin1("Â") => "A",	
	latin1("Ã") => "A",	latin1("Ä") => "A",	
	latin1("Å") => "A",	latin1("Æ") => "AE",	
	latin1("Ç") => "C",	latin1("È") => "E",	
	latin1("É") => "E",	latin1("Ê") => "E",	
	latin1("Ë") => "E",	latin1("Ì") => "I",	
	latin1("Í") => "I",	latin1("Î") => "I",	
	latin1("Ï") => "I",	latin1("Ð") => "D",	
	latin1("Ñ") => "N",	latin1("Ò") => "O",	
	latin1("Ó") => "O",	latin1("Ô") => "O",	
	latin1("Õ") => "O",	latin1("Ö") => "O",	
	latin1("×") => "x",	latin1("Ø") => "O",	
	latin1("Ù") => "U",	latin1("Ú") => "U",	
	latin1("Û") => "U",	latin1("Ü") => "U",	
	latin1("Ý") => "Y",	latin1("Þ") => "TH",	
	latin1("ß") => "B",	latin1("à") => "a",	
	latin1("á") => "a",	latin1("â") => "a",	
	latin1("ã") => "a",	latin1("ä") => "a",	
	latin1("å") => "a",	latin1("æ") => "ae",	
	latin1("ç") => "c",	latin1("è") => "e",	
	latin1("é") => "e",	latin1("ê") => "e",	
	latin1("ë") => "e",	latin1("ì") => "i",	
	latin1("í") => "i",	latin1("î") => "i",	
	latin1("ï") => "i",	latin1("ð") => "d",	
	latin1("ñ") => "n",	latin1("ò") => "o",	
	latin1("ó") => "o",	latin1("ô") => "o",	
	latin1("õ") => "o",	latin1("ö") => "o",	
	latin1("÷") => "/",	latin1("ø") => "o",	
	latin1("ù") => "u",	latin1("ú") => "u",	
	latin1("û") => "u",	latin1("ü") => "u",	
	latin1("ý") => "y",	latin1("þ") => "th",	
	latin1("ÿ") => "y",	latin1("'") => "" };

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

