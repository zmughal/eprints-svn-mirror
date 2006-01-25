package FlowTracker;
use strict;
use EPrints::User;
use EPrints::Database;
use EPrints::Session;
use EPrints::EPrint;
use EPrints::DataSet;


##ANW this module is used to track the movements of eprints between datasets, determine who the user is that invokes the change and record when the change occurs

sub logEprintMovement
{
	my ($session,$newDataset,$eprintid,$userid,$description) = @_;
	my $db = $session->{database};
	#if(!validateParameter($userid))
	#{
	#	$userid = "unknown";
	#}
	$db->do("INSERT INTO eprint_movement_audit_trail VALUES('','".$eprintid."','".$userid."', '".$newDataset."', NOW(),'".$description."')");
	
}

sub validateParameter
{
	my $result = 1;
	if (!defined($_[0]))
	{	
		$result = 0;
		print STDERR ("ERROR : in EPrints::FlowTracker -> Paramenter : ".$_[1]." was invalid (Value : ".$_[0]." )");
	}
	return $result;
}


sub initialiseMovementTracking
{
	#this method resets all movement logging - you should stop the httpd and run this offline
	
	my $session = $_[0];
	if(!defined($session))
	{
		die("no session");
	}
	#$session->get_archive()->log("EPrints::FlowTracker --> Started Log initialisation procedure\n");
	print STDOUT ("EPrints::FlowTracker --> Started Log initialisation procedure\n");
	my $db = $session->{database};
	
	if(!$db->has_table("eprint_movement_audit_trail"))
	{
		#no log table has been located in the database
			$db->do("CREATE TABLE `eprint_movement_audit_trail` (
					`movementID` BIGINT NOT NULL AUTO_INCREMENT ,
					`eprintID` INT NOT NULL ,
					`userID` INT NOT NULL ,
					`newDataset` VARCHAR( 255 ) NOT NULL ,
					`moveTime` TIMESTAMP NOT NULL ,
					`description` SET( 'creation', 'movement', 'deletion') NOT NULL, 
					PRIMARY KEY ( `movementID` ) 
					) COMMENT = 'This table holds that describes movements of eprints between datasets';"
				);
	}
	else
	{
		#the table already exists so needs clearing
		$db->do("TRUNCATE TABLE eprint_movement_audit_trail");
	}
	
	#get the initial positions of all Eprints in the system
	my @datasets = ("archive","deletion","inbox","buffer");
	foreach my $datasetName (@datasets)
	{
		my $ds = $session->get_archive()->get_dataset($datasetName);
		
		my @records = @{$ds->get_item_ids($session)};
		foreach my $eprintid (@records)
		{
			logEprintMovement($session, $datasetName, $eprintid,$_[1],"creation");
			#$session->get_archive()->log("EPrints::FlowTracker --> Noted initial position of eprint id : ".$eprintid." (location = ".$datasetName.")");
			#print STDOUT ("EPrints::FlowTracker --> Noted initial position of eprint id : ".$eprintid." (location = ".$datasetName.")");
		}
		
	}
	
	print STDOUT ("EPrints::FlowTracker --> Completed Log initialisation procedure\n");

}

1;