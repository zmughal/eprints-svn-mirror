######################################################################
#
#  EPrints Search Form Class
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

package EPrints::SearchForm;

use EPrints::Session;
use EPrints::HTMLRender;
use EPrints::EPrint;
use EPrints::SearchField;
use EPrints::SearchExpression;

use strict;


######################################################################
#
# $searchform = new( $session,
#                    $what,
#                    $allow_blank,
#                    $table,
#                    $default_fields,
#                    $title,
#                    $preamble,
#                    $order_methods,
#                    $default_order,
#                    $staff )
#
#  Create a new search form handler object.
#
#  $what           - if "eprints", the search form will search for eprints.
#                    if "user",  will search for users.
#  $allow_blank    - if the searcher is allowed to leave everything
#                  - blank and retrieve everything
#  $table          - the database table to search
#  $default_fields - which fields to display (MetaField objects)
#  $title          - title for the form
#  $preamble       - put at the top of the page.
#  $order_methods  - map description of ordering to SQL clause
#  $default_order  - default order (key to order_methods)
#  $staff          - boolean: does user have staff access?
#
######################################################################

sub new
{
	my( $class,
	    $session,
	    $what,
	    $allow_blank,
	    $table,
	    $default_fields,
	    $title,
		 $preamble,
	    $order_methods,
	    $default_order,
	    $staff ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{what} = $what;
	$self->{allow_blank} = $allow_blank;
	$self->{table} = $table;
	$self->{default_fields} = $default_fields;
	$self->{title} = $title;
	$self->{preamble} = $preamble;
	$self->{order_methods} = $order_methods;
	$self->{default_order} = $default_order;
	$self->{staff} = $staff;

	return( undef ) unless( $what eq "users" || $what eq "eprints" );
	
	return( $self );
}


######################################################################
#
# process()
#
#  Process the search form, writing out the form and/or results.
#
######################################################################

sub process
{
	my( $self ) = @_;
	
	my $submit_button = $self->{session}->{render}->param( "submit" );

	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		$self->{table},
		$self->{allow_blank},
		1,
		$self->{default_fields},
		$self->{order_methods},
		$self->{default_order} );

	# Check if we need to do a search. We do if:
	#  a) if the Search button was pressed.
	#  b) if there are search parameters but we have no value for "submit"
	#     (i.e. the search is a direct GET from somewhere else)
	if( ( defined $submit_button && $submit_button eq $self->{session}->{lang}->phrase("F:action_search") ) || 
	    ( !defined $submit_button &&
	      $self->{session}->{render}->have_parameters() ) )
	{
		# We need to do a search
		my $problems = $searchexp->from_form();
		
		if( defined $problems && scalar (@$problems) > 0 )
		{
			# Problem with search expression. Report an error, and redraw the form
			
			print $self->{session}->{render}->start_html( $self->{title} );
			print $self->{preamble};

			print "<P>";
			print $self->{session}->{lang}->phrase( "H:form_problem" );
			print "</P>";
			print "<UL>\n";
			
			foreach (@$problems)
			{
				print "<LI>$_</LI>\n";
			}
			
			print "</UL>\n";

			$self->render_search_form( $searchexp );
			
			print $self->{session}->{render}->end_html();
		}
		else
		{
			# Everything OK.
			
#EPrints::Log::debug( "SearchForm", $searchexp->to_string() );

			print $self->{session}->{render}->start_html(
				$self->{session}->{lang}->phrase( "H:results_for",
				                                  $self->{title} ) );
			
			# Print results

			if( $self->{what} eq "eprints" )
			{

				my $searchid = $searchexp->cache();
				my @eprints = $searchexp->get_records();
				$searchexp->drop_cache();

				print _render_matchcount( $self->{session} , scalar @eprints );


				foreach (@eprints)
				{
					if( $self->{staff} )
					{
						print "<P><A HREF=\"$EPrintSite::SiteInfo::server_perl/".
							"staff/edit_eprint?eprint_id=$_->{eprintid}\">".
							$self->{session}->{render}->render_eprint_citation(
								$_,
								1,
								0 )."</A></P>\n";
					}
					else
					{
						print "<P>".
							$self->{session}->{render}->render_eprint_citation(
								$_,
								1,
								1 )."</P>\n";
					}
				}
			}
			elsif( $self->{what} eq "users" )
			{
				my @users = $searchexp->do_user_search();
				
				print _render_matchcount( $self->{session} , scalar @users );

				foreach (@users)
				{
					print "<P>";
					print $self->{session}->{render}->render_user_name( $_, 1 );
					print "</P>\n";
				}
			}
			
			# Print out state stuff for a further invocation
			print "<CENTER><P>";
			print $self->{session}->{render}->start_get_form();

			$self->write_hidden_state();

			print $self->{session}->{render}->submit_buttons(
				[ $self->{session}->{lang}->phrase("F:action_update"), $self->{session}->{lang}->phrase("F:action_newsearch") ] );
			print "</P></CENTER>\n";

			print $self->{session}->{render}->end_form();


			print $self->{session}->{render}->end_html();
		}
	}
	elsif( defined $submit_button && ( $submit_button eq $self->{session}->{lang}->phrase("F:action_reset") || 
		$submit_button eq $self->{session}->{lang}->phrase("F:action_newsearch") ) )
	{
		# To reset the form, just reset the URL.
		my $url = $self->{session}->{render}->url();
		# Remove everything that's part of the query string.
		$url =~ s/\?.*//;
		$self->{session}->{render}->redirect( $url );
	}
	elsif( defined $submit_button && $submit_button eq $self->{session}->{lang}->phrase("F:action_update") )
	{
		$searchexp->from_form();

		print $self->{session}->{render}->start_html( $self->{title} );
		print $self->{preamble};

		$self->render_search_form( $searchexp );

		print $self->{session}->{render}->end_html();
	}
	else
	{
		# Just print the form...
		print $self->{session}->{render}->start_html( $self->{title} );
		print $self->{preamble};

		$self->render_search_form( $searchexp );

		print $self->{session}->{render}->end_html();
	}		
}
	

######################################################################
#
# _render_matchcount( $count )
#
#  Renders the number of hits the search resulted in, handling singular/
#  plural properly into HTML.
#
######################################################################

sub _render_matchcount
{
	my( $session, $count ) = @_;

	my $code;
	if( $count==0 )
	{
		$code = "H:no_hits";
	}
	elsif( $count==1 )
	{
		$code = "H:one_hit";
	}
	else
	{
		$code = "H:n_hits";
	}
	return "<CENTER><P>".
	       $session->{lang}->phrase( $code, "<STRONG>".$count."</STRONG>" ).
	       "</P></CENTER>";
}


######################################################################
#
# render_search_form( $searchexp )
#
#  Render a for for the given search expression, using the GET method
#
######################################################################

sub render_search_form
{
	my( $self, $searchexp ) = @_;

	print $self->{session}->{render}->start_get_form();

	print $searchexp->render_search_form( 1, 1 );
	print "<CENTER><P>";
	print $self->{session}->{render}->submit_buttons( [ $self->{session}->{lang}->phrase("F:action_search"),
		                                                 $self->{session}->{lang}->phrase("F:action_reset") ] );
	print "</P></CENTER>\n";

	print $self->{session}->{render}->end_form();
}


######################################################################
#
# write_hidden_state()
#
#  Write out the state of the form in hidden HTML fields.
#
######################################################################

sub write_hidden_state
{
	my( $self ) = @_;
	
	# Call CGI directly, we want an array
	my @params = $self->{session}->{render}->param();

	foreach (@params)
	{
		print $self->{session}->{render}->hidden_field( $_ ) if( $_ ne "submit" );
	}
}

1;
