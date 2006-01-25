######################################################################
#
# EPrints::MetaField::Boolean;
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Boolean> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Staffid;
use EPrints::DisambiguateCreators;
use String::Trigram;
use DBI;
use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Basic );
}

use EPrints::MetaField::Basic;


sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
	$search_mode ) = @_;

	return EPrints::SearchCondition->new(
		'=',
		$dataset,
		$self,
		$search_value );
}

sub get_input_elements
{
	my( $self, $session, $value, $staff, $obj ) = @_;	
	print STDERR ("running special get_input_elements\n\n");
	my $assist;
	if( $self->{input_assist} )
	{
		$assist = $session->make_doc_fragment;
		$assist->appendChild( $session->render_internal_buttons(
			$self->{name}."_assist" => 
				$session->phrase( 
					"lib/metafield:assist" ) ) );
	}
	unless( $self->get_property( "multiple" ) )
	{
		print STDERR ("Staff ID is mulitple only - alter ArchiveMetaFieldsConfig!\n");
	}
	# multiple field...

	my @creators = @{DisambiguateCreators::getCreatorsHash($session, $obj)};



	my $imagesurl = $session->get_archive->get_conf( "base_url" )."/images";
	my $esec = $session->get_request->dir_config( "EPrints_Secure" );
	if( defined $esec && $esec eq "yes" )
	{
		$imagesurl = $session->get_archive->get_conf( "securepath" )."/images";
	}
	
	
	my $creatorCount = 0;
	my %possibles;
	my @order;
	my $db = DisambiguateCreators::connectToMUD();
	my $orderT;
	my $possT;

	print STDERR ("\nnumber : ".scalar(@creators)."\n\n");
	my $id = 0;
	my $rows = [];
	my $linkRow = [];
	my $creatorNoRow = [];
	my $fieldRow = [];
	my $posRow =[];
	

	my $rowMax = 2;
	my $rowCounter = 0;
	my $given;
	my $surname;
	my $pos;
	my $heading;
	my $br;
	my %cache = ();
	my $cacheT;
	my $section;

	#push(@{$creatorNoRow},{el=>$session->make_text("")});
	#push(@{$fieldRow},{el=>$session->make_text("")});
	if(scalar(@creators) > 0)
	{
		if(scalar(@creators) != scalar(@{$value}))
		{
			print STDERR ("\n\n\ntest doing : ");
			resetStaffID($obj);
		}
		else
		{
			print STDERR ("\n\n\ntest test : ".scalar(@creators)."".scalar(@{$value})."\n\n");
		}
		while($id < scalar(@creators))
		{
			$given = $creators[$id]->{"given"};
			$surname = $creators[$id]->{"family"};

			if($rowCounter > $rowMax)
			{

				
				push @{$rows}, $creatorNoRow;
				push @{$rows}, $fieldRow;
				push @{$rows}, $posRow;
				

				
				$creatorNoRow = [];
				$fieldRow = [];
				$posRow =[];
				
				#push(@{$creatorNoRow},{el=>$session->make_text("")});
				#push(@{$fieldRow},{el=>$session->make_text("")});
				#push(@{$posRow},{el=>$session->make_text("")});

				
				$rowCounter = 0;
			}
			else
			{
				$heading = $session->make_doc_fragment();
				$br = $session->make_element("br");
				$heading->appendChild($session->make_text(" Author No. ".($id + 1)));
				$heading->appendChild($br);
				$heading->appendChild($session->make_text("(".$given." ".$surname.")"));
				
				$section = $self->get_input_elements_single( 
						$session, 
						$value->[$id], 
						($id+1),
						$staff,
						$obj );
				
				push(@{$creatorNoRow},{el=>$heading,style=>"padding:2px;text-align:center;font-weight:bold"});
				push(@{$fieldRow},@{$section->[0]});
				
				if(exists($creators[$id]))
				{
					print STDERR ($surname." ".$given);
					($pos,$cacheT) = DisambiguateCreators::renderBestList($session,$surname,$given,$db,7,\%cache);
				}
				
				push(@{$posRow},{ el=>$pos, style=>"padding-left:15px;" });
		
				$id++;
				$rowCounter++;
			}
			
		}
		DisambiguateCreators::disconnectFromMud($db);
		

			push @{$rows}, $creatorNoRow;
			push @{$rows}, $fieldRow;
			push @{$rows}, $posRow;
			push @{$rows}, $linkRow;
		
		$creatorNoRow = [];
		my $spaces = $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "hidden",
			name => $self->{name}."_spaces",
			value => scalar(@creators) );
		
		
		
		$heading = $session->make_doc_fragment();
		$br = $session->render_link($session->get_archive()->get_conf("perl_url")."/users/cdtoolkit/getpossibles?eprintid=".$obj->get_value("eprintid"));
		$br->appendChild($session->make_text("Show all Possible authors")); 
		$heading->appendChild($br);
		$br = $session->make_element("br");
		$heading->appendChild($br);
		$heading->appendChild($session->make_text("(right click the above link and open in a new window)"));
		$heading->appendChild($spaces);
		
		push(@{$creatorNoRow},{el=>$heading,style=>"width:33%;background-color:#EAEAEA;border: thin solid #AEAEAE; text-align:center;"});
		
		push @{$rows}, $creatorNoRow;
	}
	else
	{
		resetStaffID($obj);
		$creatorNoRow = [];
		$heading = $session->make_doc_fragment();
		$br = $session->make_element("br");
		$heading->appendChild($br);
					
		$section = $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "hidden",
			name => $self->{name}."_spaces",
			value => scalar(@creators) );
		$heading->appendChild($section);			
						
		$heading->appendChild($session->make_text("N/A (no creators entered)"));
		push(@{$creatorNoRow},{el=>$heading,style=>"width:100%;background-color:#EAEAEA;border: thin solid #AEAEAE;padding:2px;text-align:center;font-weight:bold"});
		push @{$rows}, $creatorNoRow;
	}

	return $rows;
}

sub resetStaffID
{
	my $obj  = $_[0];
	if(!$obj->is_set("creators"))
	{
			my @empty = ();
			delete $obj->{data}->{"creators_empid"};
			$obj->commit();
			print STDERR 
	}
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff, $obj ) = @_;

	my $maxlength = $self->get_max_input_size;
	my $size = 10;
	my $input = $session->make_element(
		"input",
		"accept-charset" => "utf-8",
		name => $self->{name}.$suffix,
		value => $value,
		maxlength => $maxlength,
		style=>"width:100%;text-align:center");

	return [ [ { el=>$input , style=>"padding:3px;"} ] ];
}



sub render_value
{
	#ANW added OBJ ref to the eprint
	my( $self, $session, $value, $alllangs, $nolink, $obj ) = @_;
	my $out = $session->make_doc_fragment();

	
	my @staffID = @{$value};
	my @creators = @{DisambiguateCreators::getCreatorsHash($session,$obj)};
	
	print STDERR ("ive got ".scalar(@staffID)." and ".scalar(@creators)."\n\n");
	
	my %matchStats;
	if(scalar(@creators) > 0 && scalar(@creators) == scalar(@staffID))
	{
		my $db = DisambiguateCreators::connectToMUD();
		my $errors = DisambiguateCreators::renderCheckStaffIDs($session,\@staffID, \@creators, $db);
		if(defined($errors))
		{
			$out->appendChild($errors);
		}
		else
		{
			if(scalar(@staffID) > 0)
			{
				my $ul = $session->make_element("ul");
				my $li;
				my $sim;
				for(my $staff = 0;$staff < scalar(@staffID);$staff++)
				{
					#print STDERR ("<<<<".$creators[$staff]->{"given"}." ".$creators[$staff]->{"family"}."\n");
					$li = $session->make_element("li");
					if($staffID[$staff]!~/(internal|external|unknown)/ && $staffID[$staff] ne "")
					{
						%matchStats = %{DisambiguateCreators::lookUpStaffMember(substr($staffID[$staff],1,length($staffID[$staff])-1),substr($staffID[$staff],0,1),$db,$creators[$staff]->{"given"},$creators[$staff]->{"family"})};
					
						if(scalar(keys %matchStats) > 0)
						{
							if($matchStats{"similarity"} < 0.4)
							{
								$sim = sprintf("%.1f",$matchStats{"similarity"} * 100)."% : (possible error?)";
							}
							elsif($matchStats{"similarity"} < 0.7)
							{
								$sim = sprintf("%.1f",$matchStats{"similarity"} * 100)."% (OK match)";
							}
							else
							{
								$sim = sprintf("%.1f",$matchStats{"similarity"} * 100)."% (good match)";
							}
							$li->appendChild($session->make_text($staffID[$staff]." (uos-".lc($matchStats{"dept"}).") ".$matchStats{"given"}." ".$matchStats{"surname"}." @ ".$sim));
						}
						else
						{
							$li->appendChild($session->make_text("ERROR :".$staffID[$staff]));
						}
					}
					else
					{
						if($staffID[$staff] eq "internal")
						{
							$li->appendChild($session->html_phrase("staffid_render_field:internal"));
						}
						elsif($staffID[$staff] eq "external")
						{
							$li->appendChild($session->html_phrase("staffid_render_field:external"));
						}
						else
						{
							$li->appendChild($session->html_phrase("staffid_render_field:unknown"));
						}
					}
					$ul->appendChild($li);
					
				}
				$out->appendChild($ul);
			}
		}
		DisambiguateCreators::disconnectFromMud($db);
	}
	else
	{
		resetStaffID($obj);
		$out->appendChild($session->make_text("N/A"));
	}

	
	return $out;
}



######################################################################
1;
