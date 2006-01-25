package EPrints::Duplicats;

use strict;
use EPrints::User;
use EPrints::Database;
use EPrints::Session;
use EPrints::EPrint;
use EPrints::DataSet;
use String::Trigram;

##SEB this module manages the discovery of duplicats etc...



#return a ref to a hash: $results{eprintid} = score
sub get_duplicats
{
	my ( $session, %opt ) = @_;
	
	my %options;
	my %results;	
	
	# recopy options and check they are valid, otherwise default
	foreach( keys %opt )
	{
		$options{$_} = $opt{$_};
	}

	return \%results if( !defined($options{id_ref}) );	# we need to know the id_ref, at least
	
	
	# dataset name should also be an option?
	my $ds = $session->get_archive()->get_dataset("archive");
	my $eprint = EPrints::EPrint->new( $session, $options{id_ref}, $ds);
	
	return \%results if( !defined($eprint) );

	$options{type_all} = 1 unless( defined($options{type_all}) );
	$options{dept_all} = 1 unless( defined($options{dept_all}) );
	$options{threshold} = 0.6 unless( defined($options{threshold}) );
	
	if( $options{type_all} == 0 && (!defined($options{type})) )
	{
		# then the type is the one of the ref eprint
		$options{type} = $eprint->get_value( "type" );
	}
	
	if( $options{dept_all} == 0 && (!defined($options{dept})) )
	{
		# then the type is the one of the ref eprint
		my $user = new EPrints::User( $session, $eprint->get_value( "userid" ) );
		
		return \%results if( !defined($user) );

		$options{dept} = $user->get_value( "dept" );
	}
	
	my $se = new EPrints::SearchExpression(
		session => $session,
		dataset => $ds,
		allow_blank => 1,
		keep_cache => 0,	# no point in keeping the cache there
	);

	if($options{type_all} != 1)
	{
		$se->add_field( $ds->get_field("type") , $options{type}, "EQ", "ALL");
	}

	if($options{dept_all} != 1)
	{
		$se->add_field( $ds->get_field("internal_group") , $options{dept}, "EQ", "ALL");
	}
	
	$se->perform_search();
	
	my $rec_ids = $se->get_ids();
	$se->dispose();
	
	my $fingerprints = get_all_fingerprints( $session, "archive" );
	
	my $fp_ref = generate_fingerprint( $eprint );	# the reference...
	
	# the problem of the duplicats thingy is that it uses loads, loads of variables.... need to investigate that
	
	my ( $score, $fingerprint, $e );
	
	foreach $e (@$rec_ids)
	{
		
		next if( $e == $options{id_ref});
	
		$score = String::Trigram::compare( $fp_ref, $$fingerprints{$e} );	# compare the reference fingerprint to the one stored in the hash table
												# returned by get_fingerprints()
		if ($score > $options{threshold} )
		{
			#push @results, $e;
			$results{$e} = $score;
		}
	}
	
	return \%results;
	# return \@results?!
	

}



sub generate_fingerprint
{
	my ($eprint) = @_;

	my $text = $eprint->get_value( "title" );

	# to be extended... (to be, to have etc)
	my @exclusions = ( 'the', 'or', 'in', 'with', 'for', 'a', 'an', 'on', 'up', 'to', 
		'into', 'upto', 'upon', 'does', 'do', 'have', 'has', 'is', 'are', 'there', 'and', 'of', 'at', 'from',
		'it', 'they');
		

	# need something which removes ( ) , . : ;
	

	my $fingerprint = "";

	my @words = split(' ', $text);
	my @selected = ();
	
	my ($w, $ex);
	
	foreach $w (@words)
	{
	
		chomp($w);
		
		next if(!defined $w);
	
		my $bool = 0;
		
		next if (length($w) < 2);	# we ignore words which length are 1 char
		
		foreach $ex (@exclusions)
		{
		
			if(uc($w) eq uc($ex)) {$bool++;}
			
			last if $bool;
			
		}
		
		next if $bool;
		
		
		$bool = 0;
		
		
		# otherwise, mark the word:
		foreach (@selected)
		{
			$bool++ if( $_ eq uc($w));
			last if $bool;	# checks if already selected (don't need word twice...)
		}

		$fingerprint = $fingerprint." ".uc($w);

	}
	
	return $fingerprint;
	
}






# return a ref to an array/hash of fingerprints...
# dataset is either 'archive' or 'buffer'
sub get_all_fingerprints
{
	my ( $session, $dataset ) = @_;

	my %fp;
	
	# check $dataset is 'archive' or 'buffer' or something like that
	
	my $table = $dataset."_fingerprints";
	
	my $sql = "SELECT eprintid, fingerprint from $table;";
	
	my $sth = $session->get_db->prepare( $sql );
	if( $session->get_db->execute( $sth, $sql ) )
	{
		while( my @row = $sth->fetchrow )
		{
			
			$fp{$row[0]} = $row[1];	# $fp{ eprintid } = fingerprint;
			
		}
	
	}
	#else
	#{
	#	big trouble!
	#}
	
	return \%fp;
		
}










1;