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

######################################################################
=pod

=item $index = EPrints::Index->new( $dataset )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $dataset, $logfn, $elogfn ) = trim_params(@_);

	my $self = { 
		dataset=>$dataset, 
		count=>0,
		change_pname => 0,
		index_table_tmp => $dataset->get_sql_index_table_name."_tmp",
		grep_table_tmp => $dataset->get_sql_index_table_name."_grep_tmp",
		logfn => $logfn,
		elogfn => $elogfn
	};

	bless $self, $class;

	return $self;
}

######################################################################
=pod

=item $success = $index->log( $message );

undocumented

=cut
######################################################################

sub log
{
	my( $self, $message ) = @_;

	if( defined $self->{logfn} )
	{
		&{$self->{logfn}}( $message );
	}
}

######################################################################
=pod

=item $success = $index->logerror( $message );

undocumented

=cut
######################################################################

sub logerror
{
	my( $self, $message ) = @_;

	if( defined $self->{elogfn} )
	{
		&{$self->{elogfn}}( $message );
		return;
	}

	&ARCHIVE->log( $message );
}

######################################################################
=pod

=item $index->cleanup();

undocumented

=cut
######################################################################

sub cleanup
{
	my( $self ) = @_;

	# destroy any tmp tables that didn't get renamed for some
	# reason.

	my $ds = $self->{dataset};

	my @doomtables = ( $self->{index_table_tmp}, $self->{grep_table_tmp} );

	foreach my $langid ( @{&ARCHIVE->get_conf( "languages" )} )
	{
		push @doomtables, $ds->get_ordervalues_table_name( $langid )."_tmp";
	}

	foreach my $table ( @doomtables )
	{
		next unless( &DATABASE->has_table( $table ) );
		$self->logerror( "Table $table still exists. Dropping it now." );
		&DATABASE->drop_table( $table ); 
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

	my $fieldpos = EPrints::MetaField->new( 
		name => "pos", 
		type => "int" );
	my $fieldword = EPrints::MetaField->new( 
		name => "fieldword", 
		type => "text");
	my $fieldids = EPrints::MetaField->new( 
		name => "ids", 
		type => "longtext");

	if( &DATABASE->has_table( $self->{index_table_tmp} ) )
	{
		$self->logerror( "$self->{index_table_tmp} already exists. Indexer exited abnormally or still running?" );
		$self->log( "Dropping table: $self->{index_table_tmp}" );
		#cjg!
		my $sql = "DROP TABLE $self->{index_table_tmp}";
		&DATABASE->do( $sql );
	}
	
	$self->log( "Creating table: $self->{index_table_tmp}" );
	$rv = $rv & &DATABASE->create_table(
		$self->{index_table_tmp},
		$ds,
		0, # no primary key
		( $fieldword, $fieldpos, $fieldids ) );

	#######################

		
	my $fieldfieldname = EPrints::MetaField->new( 
		name => "fieldname", 
		type => "text" );
	my $fieldgrepstring = EPrints::MetaField->new( 
		name => "grepstring", 
		type => "text");

	if( &DATABASE->has_table( $self->{grep_table_tmp} ) )
	{
		$self->logerror( "$self->{grep_table_tmp} already exists. Indexer exited abnormally or still running?" );
		$self->log( "Dropping table: $self->{grep_table_tmp}" );
		#cjg!
		my $sql = "DROP TABLE $self->{grep_table_tmp}";
		&DATABASE->do( $sql );
	}
	

	$self->log( "Creating table: $self->{grep_table_tmp}" );
	$rv = $rv & &DATABASE->create_table(
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
					name => $fname,
					type => "longtext" );
	}
	foreach $langid ( @{&ARCHIVE->get_conf( "languages" )} )
	{
		my $order_table_tmp = $ds->get_ordervalues_table_name( $langid )."_tmp";
		if( &DATABASE->has_table( $order_table_tmp ) )
		{
			$self->logerror( "$order_table_tmp already exists. Indexer exited abnormally or still running?" );
			$self->log( "Dropping table: $order_table_tmp" );
			#cjg!
			my $sql = "DROP TABLE $order_table_tmp";
			&DATABASE->do( $sql );
		}

		$self->log( "Creating table: $order_table_tmp" );
		$rv = $rv && &DATABASE->create_table( 
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
		max => $ds->count,
		rows => 0 };

	
	$self->{count} = 0;
	$ds->map( \&_index_item, $info );

	# store all codes which didn't already get stored

	foreach my $code ( keys %{$info->{allcodes}} )
	{
		$self->_store( $info, $code );
	}
}

sub _index_item
{
        my( $dataset, $item, $info ) = @_;

	my $id = $item->get_id;
	$info->{indexer}->log( "Indexing: ".&ARCHIVE->get_id.'.'.$dataset->id.".".$id );
	if( $info->{indexer}->{change_pname} )
	{
		$0 =~ s/ *\[[^\]]*\]//;
		my $per = int( 100 * $info->{indexer}->{count} / $info->{max} );
		$0.= ' ['.$id.' '.$per.'%]';
	} 

	my $codes = {};
	my $grepcodes = [];
	EPrints::Index::index_object( $item, $codes, $grepcodes );
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
		my $sql = "INSERT INTO ".$info->{indexer}->{grep_table_tmp}." VALUES ('".
EPrints::Database::prep_value($item->get_id)."','".EPrints::Database::prep_value($grepcode->[0])."','".EPrints::Database::prep_value($grepcode->[1])."');";
		&DATABASE->do( $sql ); #cjg
	}

	&insert_ordervalues( $dataset, $item->get_data, 1 );

	# add to count
	$info->{indexer}->{count}++;
	sleep 1 if( $info->{indexer}->{count} % 10 == 0);
}

sub update_ordervalues
{
        my( $dataset, $data, $tmp ) = trim_params(@_);

	&_do_ordervalues( $dataset, $data, 0, $tmp );	
}

sub insert_ordervalues
{
        my( $dataset, $data, $tmp ) = trim_params(@_);

	&_do_ordervalues( $dataset, $data, 1, $tmp );	
}


sub _do_ordervalues
{
        my( $dataset, $data, $insert, $tmp ) = @_;

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

	foreach my $langid ( @{&ARCHIVE->get_conf( "languages" )} )
	{
		my @fnames = ( $keyfield->get_sql_name() );
		my @fvals = ( $keyvalue );
		foreach my $field ( @fields )
		{
			my $ov = $field->ordervalue( 
					$data->{$field->get_name()},
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
		&DATABASE->do( $sql );
	}
}

sub delete_ordervalues
{
        my( $dataset, $id, $tmp ) = trim_params(@_);

	my @fields = $dataset->get_fields( 1 );

	# remove the key field
	splice( @fields, 0, 1 ); 
	my $keyfield = $dataset->get_key_field();
	my $keyvalue = EPrints::Database::prep_value( $id );

	foreach my $langid ( @{&ARCHIVE->get_conf( "languages" )} )
	{
		# cjg raw SQL!
		my $ovt = $dataset->get_ordervalues_table_name( $langid );
		if( $tmp ) { $ovt .= "_tmp"; }
		my $sql;
		$sql = "DELETE FROM ".$ovt." WHERE ".$keyfield->get_sql_name().' = "'.EPrints::Database::prep_value( $keyvalue ).'"';
		&DATABASE->do( $sql );
	}
}






sub _store
{
	my( $self, $info, $code ) = @_;

	#cjg SQL should not really be in this file.
	my $sql = "INSERT INTO $self->{index_table_tmp} VALUES ( '".EPrints::Database::prep_value($code)."', $info->{rows}, '".join( ':',  @{$info->{allcodes}->{$code}} )."' )";
	&DATABASE->do( $sql );
	
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

	if( &DATABASE->has_table( $self->{index_table_tmp} ) )
	{
		$self->log( "Installing table: ".$self->{index_table_tmp} );
		&DATABASE->install_table( 
			$self->{index_table_tmp}, 
			$self->{dataset}->get_sql_index_table_name );
	}
	else
	{
		$self->logerror( "Table does not exist to install: ".$self->{index_table_tmp} );
	}


	if( &DATABASE->has_table( $self->{grep_table_tmp} ) )
	{
		$self->log( "Installing table: ".$self->{grep_table_tmp} );
		&DATABASE->install_table( 
			$self->{grep_table_tmp}, 
			$self->{dataset}->get_sql_index_table_name."_grep" );
	}
	else
	{
		$self->logerror( "Table does not exist to install: ".$self->{grep_table_tmp} );
	}


	foreach my $langid ( @{&ARCHIVE->get_conf( "languages" )} )
	{
		my $order_table = $self->{dataset}->get_ordervalues_table_name( $langid );
		my $order_table_tmp = $order_table.'_tmp';

		if( !&DATABASE->has_table( $order_table_tmp ) )
		{
			$self->logerror( "Table does not exist to install: ".$order_table_tmp );
			next;
		}

		$self->log( "Installing table: ".$order_table_tmp );
		&DATABASE->install_table( 
			$order_table_tmp,
			$order_table );
	}

	my $statusfile = $self->get_statusfile;

	unless( open( TIMESTAMP, ">$statusfile" ) )
	{
		$self->errorlog( "EPrints::Index::install failed to open $statusfile for writing." );
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

	return &ARCHIVE->get_conf( "variables_path" ).
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

=item $thing->change_pname( $bool )

If passed "true" then this indexer should modify the process name
($0) as it does "build".

=cut
######################################################################

sub change_pname
{
	my( $self, $bool ) = @_;

	$self->{change_pname} = $bool;
}


######################################################################
=pod

=item index_object( $object, $codes )

undocumented

=cut
######################################################################


sub index_object
{
	my( $object, $codes, $grepcodes ) = trim_params(@_);

	my $ds = $object->get_dataset;
	my @fields = $ds->get_fields( 1 );

	if( $object->get_dataset->confid eq "eprint" )
	{
		push @fields, 
			EPrints::Utils::field_from_config_string( 
				$ds,
				$EPrints::Utils::FULLTEXT );
	}

	foreach my $field ( @fields )
	{
		my $value = $object->get_value( $field->get_name );
		my( $new_codes, $new_grepcodes, $ignored ) = 
			$field->get_index_codes( $value );

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

sub split_words
{
	my( $utext, $foo ) = trim_params(@_);

	# Patch an issue with compatibility
	if( !defined $utext ) { $utext = $foo; }
	
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



sub apply_mapping
{
	my( $text ) = trim_params(@_);

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
