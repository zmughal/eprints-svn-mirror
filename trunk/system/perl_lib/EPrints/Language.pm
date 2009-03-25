######################################################################
#
# EPrints::Language
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

B<EPrints::Language> - A Single Language supported by a repository.

=head1 DESCRIPTION

The language class handles loading the "phrase" files for a single
language. See the mail documentation for a full explanation of the
format of phrase files.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{id}
#     The ISO id of this language.
#
#  $self->{fallback}
#     If $self is the primary language in its repository then this is
#     undef, otherwise it is a reference to the primary language
#     object.
#
#  $self->{repository_data}
#  $self->{data}
#     A reference to a hash. Keys are ids for phrases, values are
#     DOM fragments containing the phases.
#     repository_data contains repository specific phrases, data contains
#     generic eprints phrases. 
#
#  $self->{xmldoc}
#     A XML document to hold all the stray DOM elements.
#
######################################################################

package EPrints::Language;

use strict;

######################################################################
=pod

=item $language = EPrints::Language->new( $langid, $repository, [$fallback] )

Create a new language object representing the phases eprints will
use in a given language, loading them from the phrase config XML files.

$langid is the ISO language ID of the language, $repository is the 
repository to which this language object belongs. $fallback is either
undef or a reference to the main language object for the repository.

=cut
######################################################################

my %SYSTEM_PHRASES;

sub new
{
	my( $class , $langid , $repository , $fallback ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{xmldoc} = EPrints::XML::make_document();

	$self->{id} = $langid;
	
	$self->{fallback} = $fallback;

	$self->{repository_data} = { docs => {} };

	$self->{data} = $SYSTEM_PHRASES{$langid} ||= { docs => {} };

	$self->_read_phrases_dir(
		$self->{repository_data},
		$repository,
		$repository->get_conf( "config_path" ).
			"/lang/".$self->{id}."/phrases" );

	$self->_read_phrases_dir(
		$self->{data},
		$repository,
		$repository->get_conf( "lib_path" ).
			"/lang/".$self->{id}."/phrases" );

	return( $self );
}

sub _read_phrases_dir
{
	my( $self, $data, $repository, $dir ) = @_;

	my $dh;
	opendir( $dh, $dir ) || EPrints::abort( "Failed to read: $dir: $!" );
	while( my $fn = readdir( $dh ) )
	{
		next if $fn =~ m/^\./;
		next unless $fn =~ m/\.xml$/;
		my $file = "$dir/$fn";
		if( !exists $data->{docs}->{$file} )
		{
			$self->_read_phrases( $data, $file, $repository );
		}
	}
	close $dh;
}
	


######################################################################
=pod

=item $xhtml = $language->phrase( $phraseid, $inserts, $session )

Return an XHTML DOM structure for the phrase with the given phraseid.

The phraseid is looked for in the following order, if it's not in
one phrase file the system checks the next.

=over 4

=item This languages repository specific phrases.

=item The fallback languages repository specific phrases (if there is a fallback).

=item This languages general phrases.

=item The fallback languages general phrases (if there is a fallback).

=item Failing that it returns an XHTML DOM encoded error.

=back

If the phrase contains "pin" elements then $inserts must be a reference
to a hash. Each "pin" has a "name" attribute. For each pin there must be
a key in $inserts of the "name". The value is a XHTML DOM object which
will replace the "pin" when returing this phrase.

=cut
######################################################################

sub phrase
{
	my( $self, $phraseid, $inserts, $session ) = @_;

	# not using fb 
	my( $phrase , $fb ) = $self->_get_phrase( $phraseid, $session );

	$inserts = {} if( !defined $inserts );
	if( !defined $phrase )
	{
		$session->get_repository->log( 
			'Undefined phrase: "'.$phraseid.'" ('.$self->{id}.')' );
		my $frag = $session->make_doc_fragment;
		$frag->appendChild( $session->make_text( '["'.$phraseid.'" not defined' ) );
		if( scalar(keys %$inserts) )
		{
			my $dl = $session->make_element( "dl", class => "ep_undefined_phrase"  );
			$frag->appendChild( $dl );
			while(my( $key, $insert ) = each %$inserts)
			{
				my $dt = $session->make_element( "dt" );
				$dl->appendChild( $dt );
				$dt->appendChild( $session->make_text( $key ) );
				my $dd = $session->make_element( "dd" );
				$dl->appendChild( $dd );
				$dd->appendChild( $insert );
			}
		}
		$frag->appendChild( $session->make_text( ']' ) );
		return $frag;
	}

#print STDERR "---\nN:$phrase\nNO:".$phrase->getOwnerDocument."\n";
	my $used = {};
	my $result = EPrints::XML::EPC::process_child_nodes( 
		$phrase, 
		in => "Phrase: '$phraseid'",
		session => $session, 
		pindata=>{ 
			inserts => $inserts,
			used => $used,
			phraseid => $phraseid,
		} );
	foreach( keys %{$inserts} )
	{
		if( !$used->{$_} )
		{
			# Should log this, but somtimes it's supposed to happen!
			# $session->get_repository->log( "Unused parameter \"$_\" passed to phrase \"$phraseid\"" );
			EPrints::XML::dispose( $inserts->{$_} );
		}
	}
	return $result;
}


######################################################################
# 
# ( $phrasexml, $is_fallback ) = $language->_get_phrase( $phraseid, $session )
#
# Return the phrase for the given id or undef if no phrase is defined,
# and reload the phrase from disk if needed.
#
######################################################################

sub _get_phrase
{
	my( $self, $phraseid, $session ) = @_;

	# Look for the phrase in this order:
	# $self->{repository_data}, $fallback->{$repository_data},
	# $self->{data}, $fallback->{$data}
	foreach my $src (qw( repository_data data ))
	{
		my $xml = $self->_get_src_phrase( $src, $phraseid, $session );
		return( $xml, 0 ) if defined $xml;

		next unless defined $self->{fallback};
		$xml = $self->{fallback}->_get_src_phrase( $src, $phraseid, $session );
		return( $xml, 1 ) if defined $xml;
	}

	return undef;
}

sub _get_src_phrase
{
	my( $self, $src, $phraseid, $session ) = @_;

	my $data = $self->{$src};

	my $xml = $data->{xml}->{$phraseid};
	return undef unless defined $xml;

	# Check the file modification time, reload it if it's changed
	my $file = ${$data->{file}->{$phraseid}};
	if( !defined( $session->{config_file_mtime_checked}->{$file} ) )
	{
		my $mtime = $data->{docs}->{$file}->{mtime};
		my $c_mtime = (stat( $file ))[9];
		if( $mtime ne $c_mtime )
		{
			$self->_reload_phrases( $data, $file, $session->get_repository );
			$xml = $data->{xml}->{$phraseid};
		}
		$session->{config_file_mtime_checked}->{$file} = 1;
	}

	return $xml;
}

######################################################################
=pod

=item $boolean = $language->has_phrase( $phraseid, $session )

Return 1 if the phraseid is defined for this language. Return 0 if
it is only available as a fallback or unavailable.

=cut
######################################################################

sub has_phrase
{
	my( $self, $phraseid, $session ) = @_;

	my( $phrase , $fb ) = $self->_get_phrase( $phraseid, $session );

	return( defined $phrase && !$fb );
}


######################################################################
# 
# $foo = $language->_get_data
#
# undocumented
#
######################################################################

sub _get_data
{
	my( $self ) = @_;
	return $self->{data};
}

######################################################################
# 
# $foo = $language->_get_repositorydata
#
# undocumented
#
######################################################################

sub _get_repositorydata
{
	my( $self ) = @_;
	return $self->{repository_data};
}


######################################################################
# 
#  $phrases = $language->_read_phrases( $data, $file, $repository )
# 
# Return a reference to a hash of DOM objects describing the phrases
# from the XML phrase file $file.
# 
######################################################################

sub _read_phrases
{
	my( $self, $data, $file, $repository ) = @_;

	my $doc = $repository->parse_xml( $file );	
	if( !defined $doc )
	{
		print STDERR "Error loading $file\n";
		return;
	}
	my $phrases = ($doc->getElementsByTagName( "phrases" ))[0];

	if( !defined $phrases ) 
	{
		print STDERR "Error parsing $file\nCan't find top level element.\n";
		EPrints::XML::dispose( $doc );
		return;
	}

	# Keep the document in scope and record its mtime	
	my $mtime = (stat( $file ))[9];
	$data->{docs}->{$file} = {
		doc => $doc,
		mtime => $mtime,
	};

	my $warned = 1; # set to zero if we want to warn about name="" vs id=""
	my $near;
	foreach my $element ( $phrases->getChildNodes )
	{
		my $name = $element->nodeName;
		if( $name ne "phrase" and $name ne "epp:phrase" )
		{
			next;
		}
		my $key = $element->getAttribute( "id" );
		if( !defined $key || $key eq "")
		{
			$key = $element->getAttribute( "name" );
			if(  !$key || $key eq "" || !$warned )
			{
				my $warning = "Warning: in $file";
				if( defined $near ) 
				{
					$warning.=", near '$near'";
				}
				$warning.= " found phrase without 'id' attribute.";
				if( !$key || $key eq "")
				{
					$repository->log( $warning );
					next;
				}
				$repository->log( 
						"$warning The phrase did have a 'name' attribute so this probably means it's an EPrints v2 phrase file." );
				$warned = 1;
			}
		}
		$near = $key;
		$data->{xml}->{$key} = $element;
		$data->{file}->{$key} = \$file; # save some memory
	}

	return $data;
}

######################################################################
# 
#  $phrases = $language->_reload_phrases( $data, $file, $repository )
# 
# Reload the phrases file $file (otherwise same as _read_phrases).
# 
######################################################################

sub _reload_phrases
{
	my( $self, $data, $file, $repository ) = @_;

	# Find and remove all phrases read from this file
	foreach my $phraseid (keys %{$data->{xml}})
	{
		if( ${$data->{file}->{$phraseid}} eq $file )
		{
			delete $data->{xml}->{$phraseid};
			delete $data->{file}->{$phraseid};
		}
	}

	# Dispose of the old document
	my $doc = delete $data->{docs}->{$file};
	EPrints::XML::dispose( $doc->{doc} );

	return $self->_read_phrases( $data, $file, $repository );
}

######################################################################
=pod

=item $langid = $language->get_id

Return the ISO language ID of this language object.

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;
	return $self->{id};
}



1;

######################################################################
=pod

=back

=cut

