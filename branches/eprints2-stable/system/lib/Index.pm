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
		$self->{session}->get_db->drop_table( $table ); 
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
		$self->{session}->get_db->install_table( 
			$self->{index_table_tmp}, 
			$self->{dataset}->get_sql_index_table_name );
	}
	else
	{
		$self->{session}->get_archive->log( "Table does not exist to install: ".$self->{index_table_tmp} );
	}


	if( $db->has_table( $self->{names_index_table_tmp} ) )
	{
		$self->{session}->get_db->install_table( 
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

		$self->{session}->get_db->install_table( 
			$order_table_tmp,
			$order_table );
	}

	my $statusfile = $self->get_statusfile;

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

sub get_statusfile
{
	my( $self ) = @_;

	return $self->{session}->get_archive->get_conf( "variables_path" ).
		"/index-".$self->{dataset}->id.".timestamp";
}

######################################################################
=pod

=item $timestamp = $index->get_last_timestamp()

Return the timestamp of the last time this index was installed.

=cut
######################################################################

sub get_last_timestamp
{
	my( $self ) = @_;

	my $statusfile = $self->get_statusfile;

	unless( open( TIMESTAMP, $statusfile ) )
	{
		# can't open file. Either an error or file does not exist
		# either way, return undef.
		return;
	}

	my $timestamp = undef;
	while(<TIMESTAMP>)
	{
		next if m/^\s*#/;	
		next if m/^\s*$/;	
		chomp;
		$timestamp = $_;
		last;
	}
	close TIMESTAMP;

	return $timestamp;
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
# This means that the word F�te is indexed as 'fete' and
# "fete" or "f�te" will match it.
# There's no reason mappings have to be a single character.

$EPrints::Index::FREETEXT_CHAR_MAPPING = {
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
	latin1("�") => "y",	latin1("'") => "" };

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

