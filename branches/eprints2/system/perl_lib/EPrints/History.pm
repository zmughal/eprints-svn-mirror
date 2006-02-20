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

The name of the dataset to which the modified item belongs. "eprint"
is used for eprints, rather than the inbox, buffer etc.

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

	return EPrints::History->create_from_data( 
		$session, 
		$data,
		$session->get_archive->get_dataset( "history" ) );
}

######################################################################
=pod

=item $defaults = EPrints::History->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	$data->{historyid} = $session->get_db->counter_next( "historyid" );

	$data->{timestamp} = EPrints::Utils::get_datetimestamp( time );

	return $data;
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

	my %pins = ();
	
	my $user = $self->get_user;
	if( defined $user )
	{
		$pins{cause} = $user->render_description;
	}
	else
	{
		$pins{cause} = $self->{session}->html_phrase( "lib/history:system" );
	}

	$pins{when} = $self->render_value( "timestamp" );

	my $action = $self->get_value( "action" );

	$pins{action} = $self->{session}->html_phrase( "lib/history:title_\L$action" );

	if( $action eq "MODIFY" ) { $pins{details} = $self->render_modify; }
	elsif( $action =~ m/^MOVE_/ ) { $pins{details} = $self->{session}->make_doc_fragment; }
	elsif( $action eq "MAIL_OWNER" ) { $pins{details} = $self->render_mail_owner; }
	else { $pins{details} = $self->{session}->make_text( "Don't know how to render history event: $action" ); }

	my $obj  = $self->get_dataobj;
	$pins{item} = $self->{session}->make_doc_fragment;
	$pins{item}->appendChild( $obj->render_description );
	$pins{item}->appendChild( $self->{session}->make_text( " (" ) );
 	my $a = $self->{session}->render_link( $obj->get_url( 1 ) );
	$pins{item}->appendChild( $a );
	$a->appendChild( $self->{session}->make_text( $self->get_value( "datasetid" )." ".$self->get_value("objectid" ) ) );
	$pins{item}->appendChild( $self->{session}->make_text( ")" ) );
	#$pins{item}->appendChild( $self->render_value( "historyid" ));
	
	return $self->{session}->html_phrase( "lib/history:record", %pins );
}

sub get_dataobj
{
	my( $self ) = @_;

	return unless( $self->is_set( "datasetid" ) );
	my $ds = $self->{session}->get_archive->get_dataset( $self->get_value( "datasetid" ) );
	return $ds->get_object( $self->{session}, $self->get_value( "objectid" ) );
}

sub get_user
{
	my( $self ) = @_;

	if( $self->is_set( "userid" ) )
	{
		return EPrints::User->new( $self->{session}, $self->get_value( "userid" ) );
	}

	return undef;
}

sub render_mail_owner
{
	my( $self, $action ) = @_;

	my $div = $self->{session}->make_element( "div" );
	$div->appendChild( $self->render_value("details") );
	return $div;
}



sub render_modify
{
	my( $self ) = @_;

	my $eprint = EPrints::EPrint->new( $self->{session}, $self->get_value( "objectid" ) );

	my $r_new = $self->get_value( "revision" );
	my $r_old = $r_new-1;

	my $r_file_old =  $eprint->local_path."/revisions/$r_old.xml";
	my $r_file_new =  $eprint->local_path."/revisions/$r_new.xml";
	unless( -e $r_file_new )
	{
		my $div = $self->{session}->make_element( "div" );
		$div->appendChild( $self->{session}->html_phrase( "lib/history:no_file" ) );
		return $div;
	}

	my $file_new = EPrints::XML::parse_xml( $r_file_new );
	my $dom_new = $file_new->getFirstChild;

	unless( -e $r_file_old )
	{
		my $div = $self->{session}->make_element( "div" );
		$div->appendChild( $self->{session}->html_phrase( "lib/history:no_earlier" ) );
		$div->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>render_xml( $self->{session}, $dom_new, 0, 0, 120 ) ) );
		return $div;
	}

	my $file_old = EPrints::XML::parse_xml( $r_file_old );
	my $dom_old = $file_old->getFirstChild;

	my %fieldnames = ();

	my %old_nodes = ();
	foreach my $cnode ( $file_old->getFirstChild->getChildNodes )
	{
		next unless EPrints::XML::is_dom( $cnode, "Element" );
		$fieldnames{$cnode->getNodeName}=1;
		$old_nodes{$cnode->getNodeName}=$cnode;
	}

	my %new_nodes = ();
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
	$td->appendChild( $self->{session}->html_phrase( "lib/history:before" ) );
	$tr->appendChild( $td );
	$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
	$td->appendChild( $self->{session}->html_phrase( "lib/history:after" ) );
	$tr->appendChild( $td );
	$table->appendChild( $tr );

	foreach my $fn ( keys %fieldnames )
	{
		if( !empty_tree( $old_nodes{$fn} ) && empty_tree( $new_nodes{$fn} ) )
		{
			my( $old, $pad ) = render_xml( $self->{session}, $old_nodes{$fn}, 0, 1, 60 );
			$tr = $self->{session}->make_element( "tr" );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #fcc" );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$old ) );
			$tr->appendChild( $td );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );
			my $f = $self->{session}->make_doc_fragment;			
			$f->appendChild( $self->{session}->render_nbsp );
			$f->appendChild( $pad );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$f ) );
			$tr->appendChild( $td );

			$table->appendChild( $tr );
		}
		elsif( empty_tree( $old_nodes{$fn} ) && !empty_tree( $new_nodes{$fn} ) )
		{
			my( $new, $pad ) = render_xml( $self->{session}, $new_nodes{$fn}, 0, 1, 60 );
			$tr = $self->{session}->make_element( "tr" );
			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%" );

			my $f = $self->{session}->make_doc_fragment;			
			$f->appendChild( $self->{session}->render_nbsp );
			$f->appendChild( $pad );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$f ) );
			$tr->appendChild( $td );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #cfc" );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$new ) );
			$tr->appendChild( $td );

			$table->appendChild( $tr );
		}
		elsif( diff( $old_nodes{$fn}, $new_nodes{$fn} ) )
		{
			$tr = $self->{session}->make_element( "tr" );
			my( $t1, $t2 ) = render_xml_diffs( $self->{session}, $old_nodes{$fn}, $new_nodes{$fn}, 0, 60 );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #ffc" );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$t1 ) );
			$tr->appendChild( $td );

			$td = $self->{session}->make_element( "td", valign=>"top", width=>"50%", style=>"background-color: #ffc" );
			$td->appendChild( $self->{session}->html_phrase( "lib/history:xmlblock", xml=>$t2 ) );
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
	my( $session, $tree1, $tree2, $indent, $width ) = @_;

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
				$s1->appendChild( mktext( $session, $t1, $offset, $endw, $width ) );
				$s2 = $session->make_element( "span", style=>"" );
				$s2->appendChild( mktext( $session, $t2, $offset, $endw, $width ) );
			}
			elsif( $t1 eq "" )
			{
				$s1->appendChild( mkpad( $session, $t2, $offset, $endw, $width ) );
				$s2 = $session->make_element( "span", style=>"background: #cfc" );
				$s2->appendChild( mktext( $session, $t2, $offset, $endw, $width ) );
			}
			elsif( $t2 eq "" )
			{
				$s1 = $session->make_element( "span", style=>"background: #fcc" );
				$s1->appendChild( mktext( $session, $t1, $offset, $endw, $width ) );
				$s2->appendChild( mkpad( $session, $t1, $offset, $endw, $width ) );
			}
			else
			{
				my $h1 = scalar _mktext( $session, $t1, $offset, $endw, $width );
				my $h2 = scalar _mktext( $session, $t2, $offset, $endw, $width );
				$s1 = $session->make_element( "span", style=>"background: #cc0" );
				$s1->appendChild( mktext( $session, $t1, $offset, $endw, $width ) );
				$s2 = $session->make_element( "span", style=>"background: #cc0" );
				$s2->appendChild( mktext( $session, $t2, $offset, $endw, $width ) );
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
							my( $rem, $pad ) = render_xml( $session, $list1[$i], $indent+1, 1, $width );
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
							my( $add, $pad ) = render_xml( $session, $list2[$i], $indent+1, 1, $width );
							$f1->appendChild( $pad );
							$r2 = $session->make_element( "span", style=>"background: #8f8" );
							$r2->appendChild( $add );
							$f2->appendChild( $r2 );
						}
						$c2 = $addedto;
						next;
					}
				}

				( $r1, $r2 ) = render_xml_diffs( $session, $list1[$c1], $list2[$c2], $indent+1, $width );
			}	
			else
			{
				$r1 = $session->make_element( "span" );
				$r1->appendChild( render_xml( $session, $list1[$c1], $indent+1, 0, $width ) );
				$r2 = $session->make_element( "span" );
				$r2->appendChild( render_xml( $session, $list2[$c2], $indent+1, 0, $width ) );
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
	}
	return $session->make_text( "eh?:".ref($tree1) );
}

	

# return domtree rendered as xml. 

sub render_xml
{
	my( $session,$domtree,$indent,$mkpadder,$width ) = @_;

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
			$f->appendChild( mktext( $session, $t, $offset, $endw, $width ) );
			$f->appendChild( $session->make_text( "</$name>\n" ) );
			if( $mkpadder ) { 
				$padder->appendChild( $session->make_text( "\n" ) ); 
				$padder->appendChild( mkpad( $session, $t, $offset, $endw, $width ) );
			}
		}
		else
		{
			$f->appendChild( $session->make_text( "  "x$indent ) );
			$f->appendChild( $session->make_text( "<$name>\n" ) );
			if( $mkpadder ) { $padder->appendChild( $session->make_text( "\n" ) ); }
	
			foreach my $cnode ( $domtree->getChildNodes )
			{
				my( $sub, $padsub ) = render_xml( $session,$cnode, $indent+1, $mkpadder, $width );
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
	my( $session, $text, $offset, $endw, $width ) = @_;

	return () unless length( $text );

	my $lb = utf8("");
	$lb->pack( 8626 );
	my @bits = split(/[\r\n]/, $text );
	my @b2 = ();
	
	foreach( @bits )
	{
		my $t2 = utf8($_);
		while( $offset+length( $t2 ) > $width )
		{
			my $cut = $width-1-$offset;
			push @b2, substr( $t2, 0, $cut ).$lb;
			$t2 = substr( $t2, $cut );
			$offset = 0;
		}
		if( $offset+$endw+length( $t2 ) > $width )
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
	my( $session, $text, $offset, $endw, $width ) = @_;

	my @bits = _mktext( $session, $text, $offset, $endw, $width );

	return $session->make_text( join( "\n", @bits ) );
}

# return DOM of vertical padding equiv. to the lines that would
# be needed to render $text.

sub mkpad
{
	my( $session, $text, $offset, $endw, $width ) = @_;

	my @bits = _mktext( $session, $text, $offset, $endw, $width );

	return $session->make_text( "\n"x((scalar @bits)-1) );
}



######################################################################
1;
######################################################################
=pod

=back

=cut

