######################################################################
#
#  Site Text Indexing Configuration
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################
#
# These values control what words do and don't make it into
# the free text search index. Stemming is allowed : eg. removing 
# "ing" and "s" off the end of word so "looks", "looking" and "look"
# all get indexed as "look". Which is probably helpful.
#
######################################################################


# Minimum size word to normally index.
my $FREETEXT_MIN_WORD_SIZE = 3;

# We use a hash rather than an array for good and bad
# words as we only use these to lookup if words are in
# them or not. If we used arrays and we had lots of words
# it might slow things down.

# Words to never index, despite their length.
my $FREETEXT_STOP_WORDS = {
	"this"=>1,	"are"=>1,	"which"=>1,	"with"=>1,
	"that"=>1,	"can"=>1,	"from"=>1,	"these"=>1,
	"those"=>1,	"the"=>1,	"you"=>1,	"for"=>1,
	"been"=>1,	"have"=>1,	"were"=>1,	"what"=>1,
	"where"=>1,	"is"=>1,	"and"=>1, 	"fnord"=>1
};

# Words to always index, despite their length.
my $FREETEXT_ALWAYS_WORDS = {
		"ok" => 1 
};

# This map is used to convert ASCII characters over
# 127 to characters below 127, in the word index.
# This means that the word F�te is indexed as 'fete' and
# "fete" or "f�te" will match it.
# There's no reason mappings have to be a single character.

my $FREETEXT_CHAR_MAPPING = {
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
	latin1("�") => "Y",	latin1("�") => "th",	
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
	latin1("�") => "y",	latin1("�") => "TH",	
	latin1("�") => "y",	latin1("'") => "" };


# Chars which seperate words. Pretty much anything except
# A-Z a-z 0-9 and single quote '

# If you want to add other seperator characters then they
# should be encoded in utf8. The Unicode::String man page
# details some useful methods.

my $FREETEXT_SEPERATOR_CHARS = {
	'@' => 1, 	'[' => 1,
	'\\' => 1, 	']' => 1,
	'^' => 1, 	'_' => 1,
	' ' => 1, 	'`' => 1,
	'!' => 1, 	'"' => 1,
	'#' => 1, 	'$' => 1,
	'%' => 1, 	'&' => 1,
	'(' => 1, 	')' => 1,
	'*' => 1, 	'+' => 1,
	',' => 1, 	'-' => 1,
	'.' => 1, 	'/' => 1,
	':' => 1, 	';' => 1,
	'{' => 1, 	'<' => 1,
	'|' => 1, 	'=' => 1,
	'}' => 1, 	'>' => 1,
	'~' => 1, 	'?' => 1
};

######################################################################
#
# extract_words( $text )
#
#  This method is used when indexing a record, to decide what words
#  should be used as index words.
#  It is also used to decide which words to use when performing a
#  search. 
#
#  It returns references to 2 arrays, one of "good" words which should
#  be used, and one of "bad" words which should not.
#
######################################################################

sub extract_words
{
	my( $text ) = @_;

	# Acronym processing only works on uppercase non accented
	# latin letters. If you don't want this processing comment
	# out the next few lines.

	# Normalise acronyms eg.
	# The F.B.I. is like M.I.5.
	# becomes
	# The FBI  is like MI5
	my $a;
	$text =~ s#[A-Z0-9]\.([A-Z0-9]\.)+#$a=$&;$a=~s/\.//g;$a#ge;
	# Remove hyphens from acronyms
	$text=~ s#[A-Z]-[A-Z](-[A-Z])*#$a=$&;$a=~s/-//g;$a#ge;

	# Process string. 
	# First we apply the char_mappings.
	my( $i, $len ),
	my $utext = utf8( "$text" ); # just in case it wasn't already.
	$len = $utext->length;
	my $buffer = utf8( "" );
	for($i = 0; $i<$len; ++$i )
	{
		my $s = $utext->substr( $i, 1 );
		# $s is now char number $i
		if( defined $FREETEXT_CHAR_MAPPING->{$s} )
		{
			$s = $FREETEXT_CHAR_MAPPING->{$s};
		} 
		$buffer.=$s;
	}

	$len = $buffer->length;
	my @words = ();
	my $cword = utf8( "" );
	for($i = 0; $i<$len; ++$i )
	{
		my $s = $buffer->substr( $i, 1 );
		# $s is now char number $i
		if( defined $FREETEXT_SEPERATOR_CHARS->{$s} )
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
	
	# Iterate over every word (bits divided by seperator chars)
	# We use hashes rather than arrays at this point to make
	# sure we only get each word once, not once for each occurance.
	my %good = ();
	my %bad = ();
	my $word;
	foreach $word ( @words )
	{	
		# skip if this is nothing but whitespace;
		next if ($word =~ /^\s*$/);

		# calculate the length of this word
		my $wordlen = length $word;

		# $ok indicates if we should index this word or not

		# First approximation is if this word is over or equal
		# to the minimum size set in SiteInfo.
		my $ok = $wordlen >= $FREETEXT_MIN_WORD_SIZE;
	
		# If this word is at least 2 chars long and all capitals
		# it is assumed to be an acronym and thus should be indexed.
		if( $word =~ m/^[A-Z][A-Z0-9]+$/ )
		{
			$ok=1;
		}

		# Consult list of "never words". Words which should never
		# be indexed.	
		if( $FREETEXT_STOP_WORDS->{lc $word} )
		{
			$ok = 0;
		}
		# Consult list of "always words". Words which should always
		# be indexed.	
		if( $FREETEXT_ALWAYS_WORDS->{lc $word} )
		{
			$ok = 1;
		}
	
		# Add this word to the good list or the bad list
		# as appropriate.	
		if( $ok )
		{
			# Only "bad" words are used in display to the
			# user. Good words can be normalised even further.

			# non-acronyms (ie not all UPPERCASE words) have
			# a trailing 's' removed. Thus in searches the
			# word "chair" will match "chairs" and vice-versa.
			# This isn't perfect "mose" will match "moses" and
			# "nappy" still won't match "nappies" but it's a
			# reasonable attempt.
			$word =~ s/s$//;

			# If any of the characters are lowercase then lower
			# case the entire word so "Mesh" becomes "mesh" but
			# "HTTP" remains "HTTP".
			if( $word =~ m/[a-z]/ )
			{
				$word = lc $word;
			}
	
			$good{$word}++;
		}
		else 
		{
			$bad{$word}++;
		}
	}
	# convert hash keys to arrays and return references
	# to these arrays.
	my( @g ) = keys %good;
	my( @b ) = keys %bad;
	return( \@g , \@b );
}

# Return true to indicate the module loaded OK.
1;