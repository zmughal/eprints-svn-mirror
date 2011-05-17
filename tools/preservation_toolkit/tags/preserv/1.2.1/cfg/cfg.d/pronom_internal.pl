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

# The remainder of this file defines the Pronom dataset which is used to cache
# the pronom database responses.

# add the necessary fields to the file dataset
$c->add_dataset_field( "file", { name => "in_pronom_uid", type => "text",}, reuse => 1 );
$c->add_dataset_field( "file", { name => "pronomid", type => "text",}, reuse => 1 );
$c->add_dataset_field( "file", { name => "classification_date", type => "time",}, reuse => 1 );
$c->add_dataset_field( "file", { name => "classification_quality", type => "text",}, reuse => 1 );

#Add the pronom dataset.

$c->{datasets}->{pronom} = {
   class => "EPrints::DataObj::Pronom",
   sqlname => "pronom",
   datestamp => "datestamp",
};


$c->add_dataset_field( "pronom", { name=>"pronomid", type=>"text", required=>1, can_clone=>0 }, );
$c->add_dataset_field( "pronom", { name=>"name", type=>"text", required=>0, }, );
$c->add_dataset_field( "pronom", { name=>"version", type=>"text", required=>0, }, );
$c->add_dataset_field( "pronom", { name=>"mime_type", type=>"text", required=>0, }, );
$c->add_dataset_field( "pronom", { name=>"risk_score", type=>"int", required=>0, }, );
$c->add_dataset_field( "pronom", { name=>"file_count", type=>"int", required=>0, }, );


{
package EPrints::DataObj::Pronom;

our @ISA = qw( EPrints::DataObj );

sub new
{
        return shift->SUPER::new( @_ );
}

sub get_dataset_id
{
  my ($self) = @_;
        return "pronom";
}

}

#Add the preservation_plan dataset.

$c->{datasets}->{preservation_plan} = {
   class => "EPrints::DataObj::Preservation_Plan",
   sqlname => "preservation_plan",
   datestamp => "datestamp",
};

$c->add_dataset_field( "preservation_plan", { name=>"planid", type=>"counter", required=>1, can_clone=>0, sql_counter=>"planid" }, );
$c->add_dataset_field( "preservation_plan", { name=>"format", type=>"text", required=>0, }, );
$c->add_dataset_field( "preservation_plan", { name=>"plan_type", type=>"text", required=>0, }, );
$c->add_dataset_field( "preservation_plan", { name=>"migration_action", type=>"text", required=>0, }, );
$c->add_dataset_field( "preservation_plan", { name=>"file_path", type => "longtext", required=>0, }, );
$c->add_dataset_field( "preservation_plan", { name=>"import_date", type => "time", }, );
$c->add_dataset_field( "preservation_plan", { name=>"relation", type=>"compound", multiple=>1,
  fields => [
  {
    sub_name => "type",
    type => "text",
  },
  {
    sub_name => "uri",
    type => "text",
  },
  ],
}, );

{
package EPrints::DataObj::Preservation_Plan;

our @ISA = qw( EPrints::DataObj );

sub new
{
        return shift->SUPER::new( @_ );
}

sub get_dataset_id
{
  my ($self) = @_;
        return "preservation_plan";
}

}

### END ###
