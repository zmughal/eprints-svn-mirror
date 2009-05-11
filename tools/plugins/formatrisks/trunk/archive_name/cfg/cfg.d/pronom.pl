#######################################################
###                                                 ###
###   Preserv2/EPrints FormatsRisks Configuration   ###
###                                                 ###
#######################################################
###                                                 ###
###     Developed by David Tarrant and Tim Brody    ###
###                                                 ###
###          Released under the GPL Licence         ###
###           (c) University of Southampton         ###
###                                                 ###
###        Install in the following location:       ###
###      eprints/archives/archive_name/cfg/cfg.d/   ###
###                                                 ###
#######################################################

# Maximum classification age in seconds
# Any classifications that are older than this will be updated
# To disable classification updates set max_age to 0
$c->{pronom}->{max_age} = 30 * 86400; # 30 days

# The location of Java
$c->{"executables"}->{"java"} = '/home/dct05r/java/jdk1.6.0_06/bin/java';

# The location of the DROID JAR file
$c->{"executables"}->{"droid"} = '/home/dct05r/temp/DroidWrapper/DROID_v3.0/droid.jar';

# The location of the DROID signature file
$c->{"droid_sig_file"} = '/home/dct05r/temp/DroidWrapper/DROID_v3.0/DROID_SignatureFile_V13.xml';

# DROID's invocation syntax
$c->{"invocation"}->{"droid"} = '$(java) -jar $(droid) -S$(SIGFILE) -FXML -A$(SOURCE) -O$(TARGET) >/dev/null';

# High risk score boundary. Anything returning a risk score less than or equal to this will be classified as high risk.
# Risk scores go from 0 - 3000;
$c->{"high_risk_boundary"} = 1000;

# Medium risk score boundary. Anything returning a risk score less than or equal to this and greater than the high risk boundary will be classified as medium risk.
$c->{"medium_risk_boundary"} = 2000;


# Option to use unstable version of PRONOM registry or proxy. This is mainly used in pre-release testing, leave as 0 to use actual pronom release.
$c->{"pronom_unstable"} = 0;

### END OF CONFIGURATION ###

# The remainder of this file defines the Pronom dataset which is used to cache
# the pronom database responses.

# add the necessary fields to the file dataset
$c->{fields}->{file} ||= [];
push @{$c->{fields}->{file}},
	{
		name => "in_pronom_uid",
		type => "text",
	},
	{
		name => "pronomid",
		type => "text",
	},
	{
		name => "classification_date",
		type => "time",
	},
	{
		name => "classification_quality",
		type => "text",
	};

#Add the pronom dataset.

$c->{datasets}->{pronom} = {
 	class => "EPrints::DataObj",
 	sqlname => "pronom",
 	datestamp => "datestamp",
};

$c->{fields}->{pronom} = [
		{ name=>"pronomid", type=>"text", required=>1, can_clone=>0 },
		{ name=>"name", type=>"text", required=>0, },
		{ name=>"version", type=>"text", required=>0, },
		{ name=>"mime_type", type=>"text", required=>0, },
		{ name=>"risk_score", type=>"int", required=>0, },
		{ name=>"file_count", type=>"int", required=>0, },
];

### END ###
