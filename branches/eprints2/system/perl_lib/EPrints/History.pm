######################################################################
#
# EPrints::History
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

B<EPrints::History> - An element in the history of the arcvhive.

=head1 DESCRIPTION

This class describes a single item in the history dataset. A history
object describes a single action taken on a single item in another
dataset.

Changes to document are considered part of changes to the eprint it
belongs to.

=head1 METADATA

=over 4

=item historyid (int)

The unique numerical ID of this history event. 

=item userid (itemref)

The id of the user who caused this event. A value of zero or undefined
indicates that there was no user responsible (ie. a script did it). 

=item datasetid (text)

The name of the dataset to which the modified item belongs.

=item objectid (int)

The numerical ID of the object in the dataset. Being numerical means
this will only work for users and eprints. (maybe subscriptions).

=item revision (int)

The revision of the object. This is the revision number after the
action occured. Not all actions increase the revision number.

=item timestamp (time)

The moment at which this thing happened.

=item action (set)

The type of event. Provisionally, this is a subset of the new list
of privilages.

=item details (longtext)

If this is a "rejection" then the details contain the message sent
to the user. 

=back

=head1 METHODS

=over 4

=cut

package EPrints::History;

@ISA = ( 'EPrints::DataObj' );

use EPrints::DataObj;

use Unicode::String qw(utf8 latin1);

use strict;


######################################################################
=pod

=item $field_info = EPrints::History->get_system_field_info

Return the metadata field configuration for this object.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"historyid", type=>"int", required=>1 }, 

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>0 },

		# should maybe be a set?
		{ name=>"datasetid", type=>"text" }, 

		# is this required?
		{ name=>"objectid", type=>"int" }, 

		{ name=>"revision", type=>"int" },

		{ name=>"timestamp", type=>"time" }, 

		# TODO should be a set when I know what the actions will be
		{ name=>"action", type=>"text" }, 

		{ name=>"details", type=>"longtext", 
render_single_value => \&EPrints::Extras::render_preformatted_field }, 
	);
}



######################################################################
=pod

=item $history = EPrints::History->new( $session, $historyid )

Return a history object with id $historyid, from the database.

Return undef if no such object extists.

=cut
######################################################################

sub new
{
	my( $class, $session, $historyid ) = @_;

	return $session->get_db()->get_single( 
			$session->get_archive()->get_dataset( "history" ), 
			$historyid );

}



######################################################################
=pod

=item undef = EPrints::History->new_from_data( $session, $data )

Create a new History object from the given $data. Used to turn items
from the database into objects.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	
	$self->{data} = $data;
	$self->{dataset} = $session->get_archive()->get_dataset( "history" ); 
	$self->{session} = $session;
	bless $self, $class;

	return( $self );
}



######################################################################
=pod

=item $history->commit 

Not meaningful. History can't be altered.

=cut
######################################################################

sub commit 
{
	my( $self, $force ) = @_;

	$self->{session}->get_archive->log(
		"WARNING: Called commit on a EPrints::History object." );
	return 0;
}


######################################################################
=pod

=item $history->remove

Not meaningful. History can't be altered.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	$self->{session}->get_archive->log(
		"WARNING: Called remove on a EPrints::History object." );
	return 0;
}

######################################################################
=pod

=item EPrints::History::create( $session, $data );

Create a new history object from this data. Unlike other create
methods this one does not return the new object as it's never 
needed, and would increase the load of modifying items.

Also, this does not queue the fields for indexing.

=cut
######################################################################

sub create
{
	my( $session, $data ) = @_;

	# don't want to mangle the origional data.
	$data = EPrints::Utils::clone( $data );
	
	$data->{historyid} = $session->get_db()->counter_next( "historyid" );
	$data->{timestamp} = EPrints::Utils::get_datetimestamp( time );
	my $dataset = $session->get_archive()->get_dataset( "history" );
	my $success = $session->get_db()->add_record( $dataset, $data );

	return( undef );

#	if( $success )
#	{
#		my $eprint = EPrints::History->new( $session, $new_id, $dataset );
#		$eprint->queue_all;
#		return $eprint;
#	}
#
##	$newsub->queue_all;
}


######################################################################
=pod

=item $xhtml = history->render

Render this change as XHTML DOM.

=cut
######################################################################

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", style=>"border:solid 0px red; padding: 1em;" );
	$div->appendChild( $self->{session}->make_text( "Time: " ) );
	$div->appendChild( $self->render_value( "timestamp" ) );
	my $user;
	if( $self->get_value( "userid" ) )
	{
		$user = EPrints::User->new( $self->{session}, $self->get_value( "userid" ) );
	}
	$div->appendChild( $self->{session}->make_element("br" ));
	$div->appendChild( $self->{session}->make_text( "User: " ) );
	if( defined $user )
	{
		$div->appendChild( $user->render_description() )
	}
	else
	{
		$div->appendChild( $self->{session}->make_text( "unknown - probably a script." ) );
	}

	my $action = $self->get_value( "action" );

	if( $action eq "MODIFY" ) { $div->appendChild( $self->render_modify ); }
	elsif( $action eq "MOVE_INBOX_TO_BUFFER" ) { $div->appendChild( $self->render_move( $action ) ); }
	elsif( $action eq "MOVE_BUFFER_TO_INBOX" ) { $div->appendChild( $self->render_move( $action ) ); }
	elsif( $action eq "MOVE_BUFFER_TO_ARCHIVE" ) { $div->appendChild( $self->render_move( $action ) ); }
	elsif( $action eq "MOVE_ARCHIVE_TO_BUFFER" ) { $div->appendChild( $self->render_move( $action ) ); }
	elsif( $action eq "MOVE_ARCHIVE_TO_DELETION" ) { $div->appendChild( $self->render_move( $action ) ); }
	elsif( $action eq "MOVE_DELETION_TO_ARCHIVE" ) { $div->appendChild( $self->render_move( $action ) ); }
	elsif( $action eq "MAIL_OWNER" ) { $div->appendChild( $self->render_mail_owner ); }
	else { $div->appendChild( $self->render_error( $action ) ); }
	
	return $div;
}

sub render_mail_owner
{
	my( $self, $action ) = @_;

	my $div = $self->{session}->make_element( "div" );
	$div->appendChild( $self->{session}->make_text( "Mail Owner" ) );
	$div->appendChild( $self->render_value("details") );
	return $div;
}


sub render_move
{
	my( $self, $action ) = @_;

	my $div = $self->{session}->make_element( "div" );
	$div->appendChild( $self->{session}->make_text( "Move EPrint: $action" ) );
	return $div;
}


sub render_error
{
	my( $self, $action ) = @_;

	my $div = $self->{session}->make_element( "div" );
	$div->appendChild( $self->{session}->make_text( "Don't know how to render history event: $action" ) );
	return $div;
}

# render_modify

sub render_modify
{
	my( $self ) = @_;

	my $eprint = EPrints::EPrint->new( $self->{session}, $self->get_value( "objectid" ) );

	my $r_new = $self->get_value( "revision" );
	my $r_old = $r_new-1;

	my $r_file_old =  $eprint->local_path."/revisions/$r_old.xml";
	my $r_file_new =  $eprint->local_path."/revisions/$r_new.xml";
	next unless( -e $r_file_old && -e $r_file_new );
	my $file_old = EPrints::XML::parse_xml( $r_file_old );
	my $file_new = EPrints::XML::parse_xml( $r_file_new );
	my $dom_old = $file_old->getFirstChild;
	my $dom_new = $file_new->getFirstChild;

	my %fieldnames = ();
	my %old_nodes = ();
	my %new_nodes = ();
	foreach my $cnode ( $file_old->getFirstChild->getChildNodes )
	{
		next unless EPrints::XML::is_dom( $cnode, "Element" );
		$fieldnames{$cnode->getNodeName}=1;
		$old_nodes{$cnode->getNodeName}=$cnode;
	}
	foreach my $cnode ( $file_new->getFirstChild->getChildNodes )
	{
		next unless EPrints::XML::is_dom( $cnode, "Element" );
		$fieldnames{$cnode->getNodeName}=1;
		$new_nodes{$cnode->getNodeName}=$cnode;
	}

	my $table;
	my $tr;
	my $td;
	$table = $self->{session}->make_element( "table" , width=>"100%", cellspacing=>"0", cellpadding=>"0");
	$tr = $self->{session}->make_element( "tr" );
	$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
	$td->appendChild( $self->{session}->make_text( "Before" ) );
	$tr->appendChild( $td );
	$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
	$td->appendChild( $self->{session}->make_text( "After" ) );
	$tr->appendChild( $td );
	$table->appendChild( $tr );

	my $pre;
	foreach my $fn ( keys %fieldnames )
	{
		if( !empty_tree( $old_nodes{$fn} ) && empty_tree( $new_nodes{$fn} ) )
		{
			my( $old, $pad ) = render_xml( $self->{session}, $old_nodes{$fn}, 0, 1 );
			$tr = $self->{session}->make_element( "tr" );
			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #fcc" );
			$pre = mkpre( $self->{session} );
			$td->appendChild( $pre );
			$pre->appendChild( $old );
			$tr->appendChild( $td );
			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
			$pre = mkpre( $self->{session} );
			$td->appendChild( $pre );
			$pre->appendChild( $self->{session}->render_nbsp );
			$pre->appendChild( $pad );
			$tr->appendChild( $td );
			$table->appendChild( $tr );
		}
		elsif( empty_tree( $old_nodes{$fn} ) && !empty_tree( $new_nodes{$fn} ) )
		{
			my( $new, $pad ) = render_xml( $self->{session}, $new_nodes{$fn}, 0, 1 );
			$tr = $self->{session}->make_element( "tr" );
			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
			$pre = mkpre( $self->{session} );
			$td->appendChild( $pre );
			$pre->appendChild( $self->{session}->render_nbsp );
			$pre->appendChild( $pad );
			$tr->appendChild( $td );
			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #cfc" );
			$pre = mkpre( $self->{session} );
			$td->appendChild( $pre );
			$pre->appendChild( $new );
			$tr->appendChild( $td );
			$table->appendChild( $tr );
		}
		elsif( diff( $old_nodes{$fn}, $new_nodes{$fn} ) )
		{
			$tr = $self->{session}->make_element( "tr" );
			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #ffc" );
			my( $t1, $t2 ) = render_xml_diffs( $self->{session}, $old_nodes{$fn}, $new_nodes{$fn} );
			my $pre1 = mkpre( $self->{session} );
			$pre1->appendChild( $t1 );
			$td->appendChild( $pre1 );
			$tr->appendChild( $td );
			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #ffc" );
			my $pre2 = mkpre( $self->{session} );
			$pre2->appendChild( $t2 );
			$td->appendChild( $pre2 );
			$tr->appendChild( $td );
			$table->appendChild( $tr );
		}
	}

	return $table;
}



# return true if there is no text in the tree other than
# whitespace,

sub empty_tree
{
	my( $domtree ) = @_;

	return 1 unless defined $domtree;

	if( EPrints::XML::is_dom( $domtree, "Text" ) )
	{
		my $v = $domtree->getNodeValue;
		
		if( $v=~m/^[\s\r\n]*$/ )
		{
			return 1;
		}
		return 0;
	}

	if( EPrints::XML::is_dom( $domtree, "Element" ) )
	{
		foreach my $cnode ( $domtree->getChildNodes )
		{
			unless( empty_tree( $cnode ) )
			{
				return 0;
			}
		}
		return 1;
	}

	return 1;
}

# render the diffs between tree1 and tree2

sub render_xml_diffs
{
	my( $session, $tree1, $tree2, $indent ) = @_;

	if( EPrints::XML::is_dom( $tree1, "Text" ) && EPrints::XML::is_dom( $tree2, "Text" ))
	{
		my $v1 = $tree1->getNodeValue;
		my $v2 = $tree2->getNodeValue;
		$v1=~s/^[\s\r\n]*$//;
		$v2=~s/^[\s\r\n]*$//;
		if( $v1 eq "" && $v2 eq "" )
		{
			return( $session->make_doc_fragment, $session->make_doc_fragment );
		}
		#return $session->make_text( ("  "x$indent).$v."\n" );
		return( $session->make_text( ("  "x$indent).$v1."\n" ), $session->make_text( ("  "x$indent).$v2."\n" ) );
	}

	if( EPrints::XML::is_dom( $tree1, "Element" ) && EPrints::XML::is_dom( $tree2, "Element" ))
	{
		my $f1 = $session->make_doc_fragment;
		my $f2 = $session->make_doc_fragment;
		my $name1 = $tree1->getNodeName;
		my $name2 = $tree2->getNodeName;
		my( @list1 ) = $tree1->getChildNodes;
		my( @list2 ) = $tree2->getChildNodes;
		my $justtext = 1;
		my $t1 = "";
		my $t2 = "";
		foreach my $cnode ( @list1 )
		{
			unless( EPrints::XML::is_dom( $cnode,"Text" ) )
			{	
				$justtext = 0;
				last;
			}
			$t1.=$cnode->getNodeValue;
		}
		foreach my $cnode ( @list2 )
		{
			unless( EPrints::XML::is_dom( $cnode,"Text" ) )
			{	
				$justtext = 0;
				last;
			}
			$t2.=$cnode->getNodeValue;
		}

		if( $justtext )
		{
			$f1->appendChild( $session->make_text( "  "x$indent ) );
			$f1->appendChild( $session->make_text( "<$name1>" ) );
			$f2->appendChild( $session->make_text( "  "x$indent ) );
			$f2->appendChild( $session->make_text( "<$name2>" ) );
			my $offset = $indent*2+length($name1)+2;
			my $endw = length($name1)+3;
			my $s1;
			my $s2;
			if( $t1 eq $t2 )
			{
				$s1 = $session->make_element( "span", style=>"" );
				$s1->appendChild( mktext( $session, $t1, $offset, $endw ) );
				$s2 = $session->make_element( "span", style=>"" );
				$s2->appendChild( mktext( $session, $t2, $offset, $endw ) );
			}
			elsif( $t1 eq "" )
			{
				$s1->appendChild( mkpad( $session, $t2, $offset, $endw ) );
				$s2 = $session->make_element( "span", style=>"background: #cfc" );
				$s2->appendChild( mktext( $session, $t2, $offset, $endw ) );
			}
			elsif( $t2 eq "" )
			{
				$s1 = $session->make_element( "span", style=>"background: #fcc" );
				$s1->appendChild( mktext( $session, $t1, $offset, $endw ) );
				$s2->appendChild( mkpad( $session, $t1, $offset, $endw ) );
			}
			else
			{
				my $h1 = scalar _mktext( $session, $t1, $offset, $endw );
				my $h2 = scalar _mktext( $session, $t2, $offset, $endw );
				$s1 = $session->make_element( "span", style=>"background: #cc0" );
				$s1->appendChild( mktext( $session, $t1, $offset, $endw ) );
				$s2 = $session->make_element( "span", style=>"background: #cc0" );
				$s2->appendChild( mktext( $session, $t2, $offset, $endw ) );
				if( $h1>$h2 )
				{
					$s2->appendChild( $session->make_text( "\n"x($h1-$h2) ) );
				}
				if( $h2>$h1 )
				{
					$s1->appendChild( $session->make_text( "\n"x($h2-$h1) ) );
				}
			}
			$f1->appendChild( $s1 );
			$f2->appendChild( $s2 );
			$f1->appendChild( $session->make_text( "</$name1>\n" ) );
			$f2->appendChild( $session->make_text( "</$name2>\n" ) );
			return( $f1, $f2 );
		}
		
	
		$f1->appendChild( $session->make_text( "  "x$indent ) );
		$f1->appendChild( $session->make_text( "<$name1>\n" ) );
		$f2->appendChild( $session->make_text( "  "x$indent ) );
		$f2->appendChild( $session->make_text( "<$name2>\n" ) );
		my $c1 = 0;
		my $c2 = 0;
		while( $c1<scalar @list1 && $c2<scalar @list2 )
		{
			my( $r1, $r2 );
			if( diff( $list1[$c1], $list2[$c2] ) )
			{
				if( $c1+1<scalar @list1 )
				{
					my $removedto = 0;
					for(my $i=$c1+1;$i<scalar @list1;++$i)
					{
						if( !diff( $list1[$i], $list2[$c2] ) )
						{
							$removedto = $i;
							last;
						}
					}
					if( $removedto )
					{
						for(my $i=$c1;$i<$removedto;++$i)
						{
							$r1 = $session->make_element( "span", style=>"background: #f88" );
							my( $rem, $pad ) = render_xml( $session, $list1[$i], $indent+1, 1 );
							$r1->appendChild( $rem );
							$f1->appendChild( $r1 );
							$f2->appendChild( $pad );
						}
						$c1 = $removedto;
						next;
					}
				}

				if( $c2+1<scalar @list2 )
				{
					my $addedto = 0;
					for(my $i=$c2+1;$i<scalar @list2;++$i)
					{
						if( !diff( $list2[$i], $list1[$c1] ) )
						{
							$addedto = $i;
							last;
						}
					}
					if( $addedto )
					{
						for(my $i=$c2;$i<$addedto;++$i)
						{
							my( $add, $pad ) = render_xml( $session, $list2[$i], $indent+1, 1 );
							$f1->appendChild( $pad );
							$r2 = $session->make_element( "span", style=>"background: #8f8" );
							$r2->appendChild( $add );
							$f2->appendChild( $r2 );
						}
						$c2 = $addedto;
						next;
					}
				}

				( $r1, $r2 ) = render_xml_diffs( $session, $list1[$c1], $list2[$c2], $indent+1 );
			}	
			else
			{
				$r1 = $session->make_element( "span" );
				$r1->appendChild( render_xml( $session, $list1[$c1], $indent+1 ) );
				$r2 = $session->make_element( "span" );
				$r2->appendChild( render_xml( $session, $list2[$c2], $indent+1 ) );
			}
			$f1->appendChild( $r1 );
			$f2->appendChild( $r2 );
			++$c1;
			++$c2;
		}
		$f1->appendChild( $session->make_text( "  "x$indent ) );
		$f1->appendChild( $session->make_text( "</$name1>\n" ) );
		$f2->appendChild( $session->make_text( "  "x$indent ) );
		$f2->appendChild( $session->make_text( "</$name2>\n" ) );

		return( $f1, $f2 );
#		my $t = '';
#		my $justtext = 1;
#		foreach my $cnode ( $tree1->getChildNodes )
##		{
	#		if( EPrints::XML::is_dom( $cnode,"Element" ) )
	##		{
	##			$justtext = 0;
	#			last;
	#		}
	#		if( EPrints::XML::is_dom( $cnode,"Text" ) )
	#		{
	#			$t.=$cnode->getNodeValue;
	#		}
	#	}
	#	my $name = $tree1->getNodeName;
	#	my $f = $session->make_doc_fragment;
	#	if( $justtext )
	#	{
	#		$f->appendChild( $session->make_text( "  "x$indent ) );
	#		$t = "" if( $t =~ m/^[\s\r\n]*$/ );
	#		$f->appendChild( $session->make_text( "<$name>$t</$name>\n" ) );
	#	}
	#	else
#		{
#			$f->appendChild( $session->make_text( "  "x$indent ) );
#			$f->appendChild( $session->make_text( "<$name>\n" ) );
#	
#			foreach my $cnode ( $tree1->getChildNodes )
#			{
#				$f->appendChild( render_xml( $session,$cnode, $indent+1 ) );
#			}
#
	#	}
#		return( $f, $f );
	}
	return $session->make_text( "eh?:".ref($tree1) );
}

	

# return domtree rendered as xml. 

sub render_xml
{
	my( $session,$domtree,$indent,$mkpadder ) = @_;

	if( EPrints::XML::is_dom( $domtree, "Text" ) )
	{
		my $v = $domtree->getNodeValue;
		if( $v=~m/^[\s\r\n]*$/ )
		{
			if( $mkpadder ) { return( $session->make_doc_fragment, $session->make_doc_fragment ); }
			return $session->make_doc_fragment;
		}
		my $r = $session->make_text( ("  "x$indent).$v."\n" );
		if( $mkpadder ) { return( $r, $session->make_text( "\n" ) ); }
		return $r;
	}

	if( EPrints::XML::is_dom( $domtree, "Element" ) )
	{
		my $t = '';
		my $justtext = 1;

		foreach my $cnode ( $domtree->getChildNodes )
		{
			if( EPrints::XML::is_dom( $cnode,"Element" ) )
			{
				$justtext = 0;
				last;
			}
			if( EPrints::XML::is_dom( $cnode,"Text" ) )
			{
				$t.=$cnode->getNodeValue;
			}
		}
		my $name = $domtree->getNodeName;
		my $f = $session->make_doc_fragment;
		my $padder;
		if( $mkpadder ) { $padder = $session->make_doc_fragment; }
		if( $justtext )
		{
			my $offset = $indent*2+length($name)+2;
			my $endw = length($name)+3;
			$f->appendChild( $session->make_text( "  "x$indent ) );
			$t = "" if( $t =~ m/^[\s\r\n]*$/ );
			$f->appendChild( $session->make_text( "<$name>" ) );
			$f->appendChild( mktext( $session, $t, $offset, $endw ) );
			$f->appendChild( $session->make_text( "</$name>\n" ) );
			if( $mkpadder ) { 
				$padder->appendChild( $session->make_text( "\n" ) ); 
				$padder->appendChild( mkpad( $session, $t, $offset, $endw ) );
			}
		}
		else
		{
			$f->appendChild( $session->make_text( "  "x$indent ) );
			$f->appendChild( $session->make_text( "<$name>\n" ) );
			if( $mkpadder ) { $padder->appendChild( $session->make_text( "\n" ) ); }
	
			foreach my $cnode ( $domtree->getChildNodes )
			{
				my( $sub, $padsub ) = render_xml( $session,$cnode, $indent+1, $mkpadder );
				if( $mkpadder ) { $padder->appendChild( $padsub ); }
				$f->appendChild( $sub );
			}

			$f->appendChild( $session->make_text( "  "x$indent ) );
			$f->appendChild( $session->make_text( "</$name>\n" ) );
			if( $mkpadder ) { $padder->appendChild( $session->make_text( "\n" ) ); }
		}
		if( $mkpadder ) { return( $f, $padder ); }
		return $f;
	}
	return( $session->make_text( "eh?:".ref($domtree) ), $session->make_doc_fragment );
}

# diff 2 XML DOM nodes.

sub diff
{
	my( $a, $b ) = @_;

	if( defined $a && !defined $b )
	{
		return 1;
	}
	if( !defined $a && defined $b )
	{
		return 1;
	}
	if( ref( $a ) ne ref( $b ) )
	{
		return 1;
	}
		
	if( $a->getNodeName ne $b->getNodeName )
	{
		return 1;
	}
		

	
	if( EPrints::XML::is_dom( $a, "Text" ) )
	{
		my $va = $a->getNodeValue;
		my $vb = $b->getNodeValue;

		# both empty
		if( $va=~m/^[\s\r\n]*$/ && $vb=~m/^[\s\r\n]*$/ )
		{
			return 0;
		}

		if( $va eq $vb )	
		{
			return 0;
		}

		return 1;
	}

	if( EPrints::XML::is_dom( $a, "Element" ) )
	{
		my @alist = $a->getChildNodes;
		my @blist = $b->getChildNodes;
		return( 1 ) if( scalar @alist != scalar @blist );
		for( my $i=0;$i<scalar @alist;++$i )
		{
			return 1 if diff( $alist[$i], $blist[$i] );
		}
		return 0;
	}

	return 0;
}

sub _mktext
{
	my( $session, $text, $offset, $endw ) = @_;

	return () unless length( $text );

	my $W = 60;
	my $lb = utf8("");
	$lb->pack( 8626 );
	my @bits = split(/[\r\n]/, $text );
	my @b2 = ();
	
	foreach( @bits )
	{
		my $t2 = utf8($_);
		while( $offset+length( $t2 ) > $W )
		{
			my $cut = $W-1-$offset;
			push @b2, substr( $t2, 0, $cut ).$lb;
			$t2 = substr( $t2, $cut );
			$offset = 0;
		}
		if( $offset+$endw+length( $t2 ) > $W )
		{
			push @b2, $t2.$lb, "";
		}
		else
		{
			push @b2, $t2;
		}
	}

	return @b2;
}

# render $text into wrapped XML DOM.

sub mktext
{
	my( $session, $text, $offset, $endw ) = @_;

	my @bits = _mktext( $session, $text, $offset, $endw );

	return $session->make_text( join( "\n", @bits ) );
}

# return DOM of vertical padding equiv. to the lines that would
# be needed to render $text.

sub mkpad
{
	my( $session, $text, $offset, $endw ) = @_;

	my @bits = _mktext( $session, $text, $offset, $endw );

	return $session->make_text( "\n"x((scalar @bits)-1) );
}

# internal function. Returns a <pre> XML DOM Element with the correct
# style.

sub mkpre
{
	my( $session ) = @_;

	return $session->make_element( "pre", style=>"margin: 0px 0em 0px 0; padding: 3px 3px 3px 3px; border-left: 1px dashed black; border-bottom: 1px dashed black;" );
}



######################################################################
1;
######################################################################
=pod

=back

=cut

