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
		grep_table_tmp => $dataset->get_sql_index_table_name."_grep_tmp" 
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

	my @doomtables = ( $self->{index_table_tmp}, $self->{grep_table_tmp} );

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
		print STDERR "$self->{index_table_tmp} already exists. Indexer exited abnormally or still running?\nDropping table: $self->{index_table_tmp}\n";
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
	my $fieldgrepstring = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "grepstring", 
		type => "text");

	if( $db->has_table( $self->{grep_table_tmp} ) )
	{
		print STDERR "$self->{grep_table_tmp} already exists. Indexer exited abnormally or still running?\nDropping table: $self->{grep_table_tmp}\n";
		#cjg!
		my $sql = "DROP TABLE $self->{grep_table_tmp}";
		$self->{session}->get_db->do( $sql );
	}
	

	$rv = $rv & $db->create_table(
		$self->{grep_table_tmp},
		$ds,
		0, # no primary key
		( $keyfield, $fieldfieldname, $fieldgrepstring ) );


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
			print STDERR "$order_table_tmp already exists. Indexer exited abnormally or still running?\nDropping table: $order_table_tmp\n";
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
		allcodes => {},
		indexer => $self,
		rows => 0 };

	$self->{count} = 0;
	$ds->map( $self->{session}, \&_index_item, $info );

	# store all codes which didn't already get stored

	foreach my $code ( keys %{$info->{allcodes}} )
	{
		$self->_store( $info, $code );
	}
}

sub _index_item
{
        my( $session, $dataset, $item, $info ) = @_;

	my $id = $item->get_id;

	my $codes = {};
	my $grepcodes = [];
	EPrints::Index::index_object( $session, $item, $codes, $grepcodes );
	foreach my $code ( keys %{$codes} )
	{
		push @{$info->{allcodes}->{$code}}, $id;
		if( scalar @{$info->{allcodes}->{$code}} > 100 )
		{
			$info->{indexer}->_store( $info, $code );
		} 
	}

	foreach my $grepcode ( @{$grepcodes} )
	{
		my $sql = "INSERT INTO ".$info->{indexer}->{grep_table_tmp}." VALUES ('".$item->get_id."','".$grepcode->[0]."','".$grepcode->[1]."');";
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
	my( $self, $info, $code ) = @_;

	#cjg SQL should not really be in this file.
	my $sql = "INSERT INTO $self->{index_table_tmp} VALUES ( '$code', $info->{rows}, '".join( ':',  @{$info->{allcodes}->{$code}} )."' )";
	$self->{session}->get_db->do( $sql );
	
	$info->{rows}++;
	delete $info->{allcodes}->{$code};
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


	if( $db->has_table( $self->{grep_table_tmp} ) )
	{
		$self->{session}->get_db->install_table( 
			$self->{grep_table_tmp}, 
			$self->{dataset}->get_sql_index_table_name."_grep" );
	}
	else
	{
		$self->{session}->get_archive->log( "Table does not exist to install: ".$self->{grep_table_tmp} );
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

=item index_object( $session, $object, $codes )

undocumented

=cut
######################################################################


sub index_object
{
	my( $session, $object, $codes, $grepcodes ) = @_;

	my $ds = $object->get_dataset;
	my @fields = $ds->get_fields( 1 );

#	if( $object->get_dataset->confid eq "eprint" )
#	{
#		push @fields, $ds->get_field( "_fulltext" );
#	}

	foreach my $field ( @fields )
	{
		my $value = $object->get_value( $field->get_name );
		my( $new_codes, $new_grepcodes, $ignored ) = 
			$field->get_index_codes( $session, $value );

		my $name = $field->get_name;
		foreach my $code ( @{$new_codes} )
		{
			$codes->{$name.":".$code} = 1;
		}
		foreach my $grepcode ( @{$new_grepcodes} )
		{
			push @{$grepcodes}, [ $name, $grepcode ];
		}
	}
}

#	if( $field->get_name eq "_fulltext" )
#	{
#		my @docs = $object->get_all_documents;
#		my $codes = [];
#		my $badwords = [];
#		foreach my $doc ( @docs )
#		{
#			my( $doccodes, $docbadwords );
#			( $doccodes, $docbadwords ) = 
#					$session->get_archive()->call( 
#						"extract_words",
#						$doc->get_text );
#			push @{$codes},@{$doccodes};
#			push @{$badwords},@{$docbadwords};
#		}
#		return( $codes, [], $badwords );
#	}


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

