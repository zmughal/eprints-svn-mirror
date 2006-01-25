package DisambiguateCreators;
use Net::LDAP;
use strict;
use EPrints::EPrint;
use EPrints::User;
use String::Trigram;
use DBI;

#sub getEprint
#{
#	my($session,$eprintID) = @_;
#	return EPrints::EPrint->new($session,$eprintID);
#	
#}



sub getCreatorEIDs
{
	my($eprint) = @_;
	my @values = @{$eprint->get_value("creators_empid")};
	my @out = ();
	if($eprint->is_set("creators_empid"))
	{
		foreach my $item (@values)
		{
			push (@out,$item);
			
		}
		
	}

	#print STDERR ("got empids :".join(", ".@out));
	return \@out;
}

#sub getEmployeeFromID
#{
#	my($session,$userID) = @_;
#	return EPrints::User->new($session,$userID);
#}

#sub getEmployees
#{
#	my($session,@empID,$eprint) = @_;
#	#print STDERR ("\n empids : ".join(", ",@empID));
#	my @out = ();
#	
#	foreach my $id (@empID)
#	{
#		
#		if($id eq "unknown")
#		{
#			push (@out,"unknown");
#		}
#		elsif($id eq "internal")
#		{
#			push (@out,"internal");
#		}
#		elsif($id eq "external")
#		{
#			push (@out,"external");
#		}
#		elsif($id=~/^\d+$/)
#		{
#			my $userds = $session->get_archive()->get_dataset( "user" );
#			my $searchexp = new EPrints::SearchExpression(
#				session => $session,
#				dataset => $userds );
#
#			$searchexp->add_field(
#				$userds->get_field( "employeeid" ),
#				$id );
#		
#			$searchexp->perform_search();
#			my @results = $searchexp->get_records(0,1);
#			
#			#need to make sure that the method states if the person doesn not exist in our users dataset - this should spot bum id codes
#			if(defined(@results) && scalar(@results) > 0)
#			{
#				push (@out,$results[0]);
#			}
#			else
#			{
#				push (@out,"ERROR : Invalid ID number (eprint ".$eprint->get_value("eprintid").")");
#			}
#		
#			$searchexp->dispose();
#		}
#		else
#		{
#			push (@out,"ERROR invalid status entry*".$id->get_value("userid")."*");
#		}
#	}
#	#print STDERR ("got EMP :".join(", ".@out));
#	return @out;
#}

#sub getCreatorsNames
#{
#	my($session, $eprint) = @_;
#	my $names = ();
#	my @out = ();
#	if($eprint->is_set("creators"))
#	{
#
#		$names = $eprint->get_value("creators");
#		foreach my $item (@{$names})
#		{
#			push(@out, $item->{main}->{honourific}.$item->{main}->{given}." ".$item->{main}->{family});
#
#		}
#		
#	}
#	#print STDERR ("got Names :".join(", ".@out));
#	return @out;
#}

#sub getCreatorSurnames
#{
#	my($session, $eprint) = @_;
#	my $names = ();
#	my @out = ();
#	if($eprint->is_set("creators"))
#	{
#
#		$names = $eprint->get_value("creators");
#		foreach my $item (@{$names})
#		{
#			push(@out, $item->{main}->{family});
#		}
#		
#	}
#
#	return @out;
#}

sub getCreatorsHash
{
	my($session, $eprint) = @_;
	my $names = ();
	my @out = ();
	my %hash = ();
	if($eprint->is_set("creators"))
	{
		$names = $eprint->get_value("creators");
		foreach my $item (@{$names})
		{
			#->{family};
			#$item->{main}->{given};
			if($item->{main}->{given} ne "" && $item->{main}->{family} ne "")
			{
				push(@out, $item->{main});
			}
			%hash = ();
		}
		#foreach my $item (@out)
		#{
		#	print STDERR ($item->{family}." :: ".$item->{given}."\n");
		#}

	}
	#die();
	return \@out;
}

sub connectToMUD
{
	$ENV{ORACLE_HOME}='/opt/local/oracle';
	my $db = DBI->connect("dbi:Oracle:mud", "mud_read", "fyi246sos") or print STDERR ("\n\n*************Oracle connect failed\n\n");
	return $db;
}

sub disconnectFromMud
{
	$_[0]->disconnect();
}

sub renderCheckStaffIDs
{
	#does validation and check
	#if an error is found it returns a DOM list
	#else it returns undef
	my $session = $_[0];
	my $out;
	my $staffIDs = $_[1];
	my $creators = $_[2];
	my $db = $_[3];

	my @errors = @{checkStaffIDs($session,$staffIDs,$creators,$db)};
	
	if($out eq "error")
	{
		$out = $session->make_doc_fragment();
		my $ul = $session->make_element("ul");
		my $li;
		foreach my $error (@errors)
		{
			$li = $session->make_element("li");
			$li->appendChild($session->make_text($error));
			$ul->appendChild($li);
		}
		$out->appendChild($ul);
	}

	return $out;
}

sub checkStaffIDs
{
	my $session = $_[0];
	my $out;
	my $staffIDs = $_[1];
	my $creators = $_[2];
	my $db = $_[3];
	my @out = ();
	my @verifyResults = @{verifyStaffIDs($staffIDs,$creators)};
	my @validateResults = ();
	if(scalar(@verifyResults) == 0)
	{
		@validateResults = @{validateStaffIDs($staffIDs, $creators, $db)};
		if(scalar(@validateResults) > 0)
		{
			
			#validate error
			print STDERR ("validate errors\n".join(",\n",@validateResults));
			@out = @validateResults;
		}
	}
	else
	{
		#verify error
		print STDERR ("verify errors\n".join(",\n",@verifyResults));
		@out = @verifyResults;
		
	}
	return \@out;
}

sub verifyStaffIDs
{
	#this should use built in validation functions (EPrint.pm) not this method- will get round to it
	my @out = ();
	my @staffID = @{$_[0]};
	my @creators = @{$_[1]};

	
	
	if(scalar(@creators) == scalar(@staffID))
	{
		@out = @{verifyFormatOfStaffID(\@staffID)};
	}
	else
	{
		push (@out, "There are two few staff IDs (creators total = ".scalar(@creators).", Staff IDs total = ".scalar(@staffID).")");
	}
	return \@out;
}

sub verifyFormatOfStaffID
{
	my @out = ();
	my @staffID = @{$_[0]};
	print STDERR ("verifying using :".join(" ,", @staffID)."\n");
	my $count = 1;
	my $error;	
	for(my $staff = 0;$staff < scalar(@staffID);$staff++)
	{
			$error = verifySingleID($staffID[$staff],$count);
			if(defined($error))
			{
				print STDERR ("error occurred ".$error);
				push (@out, $error);
			}
			$count++;
	}
	return \@out;
}

sub verifySingleID
{
	my $status = $_[0];
	my $id = $_[1];
	my $out;
	print STDERR ("checking :".$id.":".$status.":\n");
	if($status!~/^\d+$/ && $status!~/^[a-z]+$/)
	{
		print STDERR ($id." didnt match\n");
		$out = $id.". ID value (".$status.") is invalid";
	}
	else
	{
		print STDERR ($id."  matched \n");
	}
	
	return $out;
}

sub validateStaffIDs
{
	my @out = ();
	my @staffID = @{$_[0]};
	my @creators = defined($_[1]) ? @{$_[1]} : ();
	my $creator;
	print STDERR ("validate staff ids ive got ".scalar(@staffID)." and ".scalar(@creators)."\n\n");
	
	my $db = $_[2];
	my $error;	
	for(my $staffMember = 0;$staffMember < scalar(@staffID);$staffMember++)
	{
		if(exists($creators[$staffMember]))
		{
			$creator = $creators[$staffMember];
		}
		else
		{
			$creator = "none";
		}
		
		print STDERR ("calling\n");
		$error = validateSingleID($staffID[$staffMember],$creator,$db, $staffMember);
		if(defined($error))
		{
			push (@out, $error);
		}
	}
	
	return \@out;
	
}

sub validateSingleID
{

	my $staffID = $_[0];
	my $creator = $_[1];
	my $db = $_[2];
	my $id = $_[3] + 1;
	my %possibles;
	my $out;
	
	if($staffID=~/^(external|internal|unknown|\d+)$/)
	{
		if($staffID=~/^(\d+)$/)
		{
			if($creator eq "none")
			{
				%possibles = %{lookUpStaffMember(substr($staffID,1,length($staffID)-1),substr($staffID,0,1),$db,"none","none")};
			
			}
			else
			{
				%possibles = %{lookUpStaffMember(substr($staffID,1,length($staffID)-1),substr($staffID,0,1),$db,$creator->{"given"},$creator->{"family"})};
			
			}
			if(scalar(keys %possibles == 0))
			{
				$out = $id.". ID value (".$staffID.") does not point to a valid UOS employee";
			}
		}
	}
	else
	{
		$out = $id.". ID value (".$staffID.") is invalid";
	}
	
	
	return $out;
}



#sub renderRAECreatorStatusText
#{
#	#deprecated
#	print STDERR "\n\n\nrunning text\n";
#	my @out = ();
#	my $session = $_[0];
#	my $eid = $_[1];
#	my $eprint = getEprint($session,$eid);
#	if(verifyCreatorID($eprint,$session) eq "")
#	{
#
#		my @creatorsStatus = getEmployees($session,getCreatorEIDs($eprint));
#
#		my @creatorNames = getCreatorsNames($session,$eprint);
#
#		print STDERR ("\ncontents creatorNames : \n".join("\n",@creatorNames));
#		print STDERR ("\ncontents creatorStatus : \n".join("\n",@creatorsStatus));
#		my $uid;
#		
#		foreach my $creator (0..scalar(@creatorNames))
#		{
#			if(defined($creatorNames[$creator]))
#			{
#				if(defined($creatorsStatus[$creator]))
#				{
#					if($creatorsStatus[$creator] eq "internal")
#					{
#						push(@out,$creatorNames[$creator]."(internal (no longer employed))");
#					}
#					elsif($creatorsStatus[$creator] eq "unknown")
#					{
#						push(@out,$creatorNames[$creator]."(unknown))");
#					}
#					elsif($creatorsStatus[$creator] eq "external")
#					{
#						push(@out,$creatorNames[$creator]."(external)");
#					}
#					elsif(defined($creatorsStatus[$creator]->get_value("userid")))
#					{
#						
#						push (@out,$creatorNames[$creator]."(internal - ". $creatorsStatus[$creator]->get_value("employeeid").")");
#						
#					}
#					else
#					{
#						push(@out,$creatorNames[$creator]."(ERROR - invalid staff ID)");
#					}
#				}
#				else
#				{
#					push(@out,$creatorNames[$creator]."(ERROR - not defined)");
#				}
#				
#			}
#		}
#	}
#	else
#	{
#		push(@out, verifyCreatorID($eprint,$session));
#	}
#	
#	print STDERR "\n\n\nfinished text\n";
#	return join(", ",@out);
#	
#}


#sub renderRAECreatorStatusDOMTable
#{
#	print STDERR "\n\n\nrunning DOM 2\n";
#	my @out = ();
#	my $session = $_[0];
#	my $eid = $_[1];
#	my $eprint = getEprint($session,$eid);
#	my $tableRow;
#	my $tableCell;
#	my $link;
#	my $table = $session->make_element("table", style=>"text-align:center;width:100%;padding:5px");
#	if(verifyCreatorID($eprint,$session) eq "")
#	{
#
#		my @creatorsStatus = getEmployees($session,getCreatorEIDs($eprint));
#
#		my @creatorNames = getCreatorsNames($session,$eprint);
#
#
#		print STDERR ("\ncontents creatorNames : \n".join("\n",@creatorNames));
#		print STDERR ("\ncontents creatorStatus : \n".join("\n",@creatorsStatus));
#		my $uid;
#		
#		foreach my $creator (0..scalar(@creatorNames))
#		{
#			$tableRow = $session->make_element("tr");
#			if(defined($creatorNames[$creator]))
#			{
#				print STDERR ("\n".$creatorNames[$creator]." running");
#				if(defined($creatorsStatus[$creator]))
#				{
#					if($creatorsStatus[$creator] eq "internal")
#					{
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#EAEAEA");
#						$tableCell->appendChild($session->make_text($creatorNames[$creator]));
#						$tableRow->appendChild($tableCell);
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#EAEAEA");
#						$tableCell->appendChild($session->make_text("internal (no longer employed)"));
#						$tableRow->appendChild($tableCell);
#					}
#					elsif($creatorsStatus[$creator] eq "unknown")
#					{
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#EAEAEA");
#						$tableCell->appendChild($session->make_text($creatorNames[$creator]));
#						$tableRow->appendChild($tableCell);
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#FF0000");
#						$tableCell->appendChild($session->make_text("unknown - please resolve"));
#						$tableRow->appendChild($tableCell);
#					}
#					elsif($creatorsStatus[$creator] eq "external")
#					{
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#EAEAEA");
#						$tableCell->appendChild($session->make_text($creatorNames[$creator]));
#						$tableRow->appendChild($tableCell);
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#EAEAEA");
#						$tableCell->appendChild($session->make_text("external"));
#						$tableRow->appendChild($tableCell);
#					}
#					elsif(defined($creatorsStatus[$creator]->get_value("userid")))
#					{
#						$uid = $creatorsStatus[$creator]->get_value("userid");
#						print STDERR ("\n".$uid."<-uid\n");
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#EAEAEA");
#						$tableCell->appendChild($session->make_text($creatorNames[$creator]));
#						$tableRow->appendChild($tableCell);
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#EAEAEA");
#						$link = $session->make_element("a",href=>$creatorsStatus[$creator]->get_url("staff"));
#						$link->appendChild($session->make_text("internal"));
#						$tableCell->appendChild($link);
#						$tableRow->appendChild($tableCell);
#						
#					}
#					else
#					{
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#EAEAEA");
#						$tableCell->appendChild($session->make_text($creatorNames[$creator]));
#						$tableRow->appendChild($tableCell);
#						$tableCell = $session->make_element("td",style=>"padding:2px;background-color:#FF0000");
#						$tableCell->appendChild($session->make_text("ERROR - invalid staff ID"));
#						$tableRow->appendChild($tableCell);
#					}
#				}
#				else
#				{
#					$tableRow = $session->make_element("tr");
#					$tableCell = $session->make_element("td");
#					$tableCell->appendChild($session->make_text("ERROR - Eprint does not exist"));
#					$tableRow->appendChild($tableCell);
#					$table->appendChild($tableRow);
#				}
#				$table->appendChild($tableRow);
#			}
#		}
#	}
#	else
#	{
#		$tableRow = $session->make_element("tr");
#		$tableCell = $session->make_element("td");
#		$tableCell->appendChild($session->make_text(verifyCreatorID($eprint,$session)));
#		$tableRow->appendChild($tableCell);
#		$table->appendChild($tableRow);
#	}
#	
#	print STDERR "\n\n\finished DOM 2\n";
#	return $table;
#	
#}##


sub getBestSurnameMatches
{
	
	my $session  = $_[0];
	my $noToDisplay = $_[1];
	my $surname = $_[2];
	my $given = $_[3];
	my $db = $_[4];
	

	my %possibles = DisambiguateCreators::getSurnameMatches($session,$surname,$given,$db);
	my @order =  @{sortPossibles(\%possibles)};
	my %shortList = ();
	if($noToDisplay > 0)
	{
		for(my $count; $count < scalar(@order) && $count < $noToDisplay;$count++)
		{
			$shortList{$order[$count]} = $possibles{$order[$count]};
		}
		@order = @{sortPossibles(\%shortList)};
	}
	else
	{
		%shortList = %possibles;
	}
	print STDERR (" bgvds returning : ".join(", ",@order)." ".scalar(%shortList));
	return (\@order,\%shortList);
}

sub sortPossibles
{
	print STDERR (caller()."\n\n\*****\n");
	my %possibles = %{$_[0]};
	my @out = sort {$possibles{$a}->{"similarity"} <=> $possibles{$b}->{"similarity"}} keys %possibles;
	@out = reverse @out;
	return \@out;
}

sub renderBestPara
{
	my $session = $_[0];
	#get the first letter of the given (cos some contain a full name which aint what we want)

	my ($orderT,$possiblesT) = DisambiguateCreators::getBestSurnameMatches($session,$_[5],$_[1],$_[2],$_[3]);
	
	#print STDERR (scalar(@order)."\n");
	my @order = @{$orderT};
	my %shortList = %{$possiblesT};
	my $p = $session->make_element("p");
	my $br;
	
	if(scalar(@order) > 0)
	{
		foreach my $item (@order)
		{
			$br = $session->make_element("br");
			$p->appendChild($br);
			$p->appendChild($session->make_text(sprintf("%.1f",$shortList{$item}->{"similarity"})."% : ".$shortList{$item}->{"name"}." : ".$shortList{$item}->{"empid"}));
		}
	}
	else
	{
		
		$p->appendChild($session->make_text("no matches (external?)"));
		
	}

	return $p;
}

sub renderBestList
{
	my $session = $_[0];
	#get the first letter of the given (cos some contain a full name which aint what we want)
	my %cache = %{$_[5]};
	my %shortList;
	my @order;
	
	if(!exists($cache{$_[1]." ".$_[2]}))
	{
		my ($orderT,$possiblesT) = DisambiguateCreators::getBestSurnameMatches($session,$_[4],$_[1],$_[2],$_[3]);
		@order = @{$orderT};
		%shortList = %{$possiblesT};
		$cache{$_[1]." ".$_[2]}->{"shortList"} = \%shortList;
		$cache{$_[1]." ".$_[2]}->{"order"} = \@order;

	}
	else
	{
		print STDERR ("using cache for ".$_[1]." ".$_[2]."\n\n");
		%shortList = %{$cache{$_[1]." ".$_[2]}->{"shortList"}};
		@order = @{$cache{$_[1]." ".$_[2]}->{"order"}};
	}
	
	#print STDERR (scalar(@order)."\n");

	my $dl = $session->make_element("dl", style=>"width:100%;padding:1px;");
	my $dt;
	my $dd;
	my $br;
	
	if(scalar(@order) > 0)
	{
		foreach my $item (@order)
		{
			$br = $session->make_element("br");
			
			$dt = $session->make_element("dt", style=>"padding-top:3px;");
			$dt->appendChild($session->make_text($shortList{$item}->{"empid"}));
			$dl->appendChild($dt);
			$dd = $session->make_element("dd", style=>"padding:1px;");
			$dd->appendChild($session->make_text("".sprintf("%.1f",$shortList{$item}->{"similarity"})."% : ".$shortList{$item}->{"name"}));
			$dd->appendChild($br);
			$dd->appendChild($session->make_text("(dept: ".$shortList{$item}->{"dept"}.")"));
			$dl->appendChild($dd);
		}
	}
	else
	{
		$dt = $session->make_element("dt");
		$dt->appendChild($session->make_text("No matches (external)?"));
		$dl->appendChild($dt);
		$dd = $session->make_element("dd");
		$dd->appendChild($session->make_text(""));
		$dl->appendChild($dd);
	}

	return ($dl,\%cache);
}

sub lookUpStaffMember
{
	#print STDERR ("\n\n\poo".join(",",caller())."\n\n\n\n\n");
	my $staffID = $_[0];
	my $libID = $_[1];
	my $db = $_[2];
	my $given = $_[3];
	my $surname = $_[4];
	my $compareName;
	my $temp;
	my $temp2;
	my %possibles= ();
	my $count = 0;
	print STDERR ("\nlooking up staff using:\n".$libID.":\n".$staffID.":\n".$given.":\n".$surname.":\n");
	my $sh = $db->prepare("select /*+ CACHE(d) +CACHE(p) */  p.initials, p.surname, d.school from mud.person p, mud.division d where p.pinumber = '".$staffID."' and p.library = '".$libID."' and p.pinumber = d.pinumber");
	$sh->execute();
	my @row = $sh->fetchrow_array();

	
	if(scalar(@row) > 0)
	{
		$possibles{"surname"} = $row[1];
		$possibles{"given"} = getDottedInitials($row[0]);
		$possibles{"dept"} = $row[2];
		print STDERR ("comparing :".getDottedInitialsSurname($row[0], $row[1])."::".$compareName.":\n");
		if($given ne "none" || $surname ne "none")
		{
			$compareName = $given." ".$surname;	
			print STDERR ("before all ".$given." ".$surname);
			#compensate for named entries
			if($compareName!~/^([a-zA-Z ])(\.)/)
			{
				if($compareName=~/^([a-zA-Z ]+)([ ])(.*)/)
				{
					print STDERR "before :".$3."\n";
					$temp = $3;
					$temp2 = $1;
					$temp2=~s/ //g;
					$temp=~s/ //g;
					
					print STDERR "after :".$temp."::".$temp2.":\n";
					$compareName = substr($temp2,0,1).".".$temp;
					$compareName =~s/(\.)(\w+)$/$1 $2/;
					print STDERR "compare name moded : ".$compareName."\n";
				}
			}
			
			
			$possibles{"similarity"} = String::Trigram::compare(getDottedInitialsSurname($row[0], $row[1]),$compareName);
		}
		else
		{
			print STDERR ("\n\tno names specified\n\n\n");
		}

		print STDERR ("built match".join(",\n",values %possibles)."\n");
	}		
	
	if($sh->err())
	{
		print STDERR ("disambiguate MUD look up error :".$sh->err."\n");
	}
	return \%possibles;
}

sub getMUDGiven
{
	my $out = $_[0];
	$out =~s/.//;
	$out =~s/ //;
	return $out;
}

sub getSurnameMatches
{
	
	my @out = ();
	my %possibles = ();
	my $surname = $_[1];
	my $session = $_[0];
	my $given = $_[2];
	my $firstInitial = substr($given,0,1);
	my $db = $_[3];
	my $searchName;
	my $compareName;
	$surname=~s/\'/\_/;
	my $temp;
	my $temp2;
	my $count;
	
	print STDERR ("\nmatch looking using:\n".$given.":\n".$surname.":\n");
	
	$firstInitial = $given ne "" ? "p.initials LIKE '".substr($given,0,1)."%' AND " : "";
	my $sh = $db->prepare("select /*+ CACHE(d) +CACHE(p) */ CONCAT(p.library,p.pinumber), p.initials, p.surname, d.school from mud.person p, mud.division d where ".$firstInitial."p.surname LIKE '".$surname."' and p.pinumber = d.pinumber");# OR p.surname LIKE '".uc($surname)."')");
	$sh->execute();
	print STDERR ("Querying using ".$surname.",".$given.":::-->".$firstInitial."\n"."select /*+ CACHE(d) +CACHE(p) */ CONCAT(p.library,p.pinumber), p.initials, p.surname, d.school from mud.person p, mud.division d where ".$firstInitial."p.surname LIKE '".$surname."' and p.pinumber = d.pinumber"."\n");
	while(my @row = $sh->fetchrow_array())
	{
	
		#print STDERR (scalar(@row)."<- number of fields \n");
		print STDERR ($row[0]." :: ".$row[1]." :: ".$row[2]."\n");
		$searchName = getDottedInitialsSurname($row[1],ucfirst(lc($row[2])));

		$compareName = $given." ".$row[2];
	#
		#compensate for named entries
		if($compareName!~/^([a-zA-Z ])(\.)/)
		{
			if($compareName=~/^([a-zA-Z ]+)([ ])(.*)/)
			{
				print STDERR "before :".$3."\n";
				$temp = $3;
				$temp2 = $1;
				$temp2=~s/ //g;
				$temp=~s/ //g;
				
				print STDERR "after :".$temp."::".$temp2.":\n";
				$compareName = substr($temp2,0,1).".".$temp;
				$compareName =~s/(\.)(\w+)$/$1 $2/;
				print STDERR "compare name moded : ".$compareName."\n";
			}
		}
		
		print STDERR "comparing :".$searchName.":: ".$compareName."\n";
		$possibles{$count}->{"similarity"} = String::Trigram::compare($compareName, $searchName) * 100;
		$possibles{$count}->{"empid"} = $row[0];
		$possibles{$count}->{"name"} = $searchName;
		$possibles{$count}->{"dept"} = "uos-".lc($row[3]);
	
		$count++;
	}
	if($sh->err())
	{
		print STDERR ("disambiguate MUD look up error :".$sh->err."\n");
	}
	
	return %possibles;
}




#sub getName
#{
#	#this method returns a name using the first letter of given, then appending the initals (sep by .) followed by the surname
#	#probably should be removed as this was useful for LDAP (which was crap)
#	my $given = $_[0];
#	my $initials = $_[1];
#	my $surname = $_[2];
#	my $out = substr($given,0,1).".";
#	
#	for(my $count ; $count < length($initials);$count++)
#	{
#		$out.= substr($initials,$count,1).".";
#	}
#	
#	$out.= " ".$surname;
#	#print STDERR ("get Name : ".$out."\n");
#
#	return $out;
#}

sub getDottedInitials
{
	my $initials = $_[0];
	my $out = "";
	
	for(my $count ; $count < length($initials);$count++)
	{
		$out.= substr($initials,$count,1).".";
	}
	
	return $out;
}

sub getDottedInitialsSurname
{
	#this method simply puts dots after each character in initials followed by a surname
	
	my $surname = $_[1];
	my $out = getDottedInitials($_[0]);

	
	$out.= " ".$surname;
	#print STDERR ("get Name : ".$out."\n");

	return $out;
}




1;