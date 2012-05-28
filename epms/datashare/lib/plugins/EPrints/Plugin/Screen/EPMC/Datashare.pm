package EPrints::Plugin::Screen::EPMC::Datashare;

@ISA = qw( EPrints::Plugin::Screen::EPMC );

use strict;

my $WORKFLOW = <<'EOX';
<?xml version="1.0"?>
<workflow xmlns="http://eprints.org/ep3/workflow" xmlns:epc="http://eprints.org/ep3/control">
	<stage name="files">
		<component type="Documents">
			<epc:if test="type.one_of('dataset','experiment')">
				<field ref="readme" />
				<field ref="experiment_stage" />
			</epc:if>
		</component>
	</stage>

	<stage name="core">
		<epc:if test="type.one_of('dataset','experiment')">
			<component>
				<field ref="contributors" input_lookup_url="{$config{rel_cgipath}}/users/lookup/name">
					<sub_field ref="type" set_name="contributor_type_dataset" />
				</field>
			</component>
		</epc:if>
	</stage>
</workflow>
EOX

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{actions} = [qw( enable disable )];
	$self->{disable} = 0; # always enabled, even in lib/plugins

	$self->{package_name} = "datashare";

	return $self;
}

sub action_enable
{
	my( $self, $skip_reload ) = @_;

	$self->SUPER::action_enable( 1 );
	my $repo = $self->{repository};

	my $namedset;

	$namedset = EPrints::NamedSet->new( "eprint",
			repository => $repo,
		);
	$namedset->add_option( "dataset", "datashare" );
	$namedset->add_option( "experiment", "datashare" );

	$namedset = EPrints::NamedSet->new( "content",
			repository => $repo,
		);
	$namedset->add_option( "data", "datashare" );
	$namedset->add_option( "readme", "datashare" );
	$namedset->add_option( "discussion", "datashare" );
	$namedset->add_option( "software", "datashare" );

	my $default_xml = $repo->config( "config_path" )."/workflows/eprint/default.xml";
	EPrints::XML::add_to_xml( $default_xml, $WORKFLOW, $self->{package_name} );

	$self->reload_config if !$skip_reload;
}

sub action_disable
{
	my( $self, $skip_reload ) = @_;

	$self->SUPER::action_disable( 1 );
	my $repo = $self->{repository};

	my $namedset;

	$namedset = EPrints::NamedSet->new( "eprint",
			repository => $repo,
		);
	$namedset->remove_option( "dataset", "datashare" );
	$namedset->remove_option( "experiment", "datashare" );

	$namedset = EPrints::NamedSet->new( "content",
			repository => $repo,
		);
	$namedset->remove_option( "data", "datashare" );
	$namedset->remove_option( "readme", "datashare" );
	$namedset->remove_option( "discussion", "datashare" );
	$namedset->remove_option( "software", "datashare" );

	$namedset = EPrints::NamedSet->new( "contributor_type",
			repository => $repo,
		);
	$namedset->remove_option( "principle_investigator", "datashare" );
	$namedset->remove_option( "coinvestigator", "datashare" );
	$namedset->remove_option( "investigator", "datashare" );
	$namedset->remove_option( "project_manager", "datashare" );
	$namedset->remove_option( "project_worker", "datashare" );

	my $default_xml = $repo->config( "config_path" )."/workflows/eprint/default.xml";
	EPrints::XML::remove_package_from_xml( $default_xml, $self->{package_name} );

	$self->reload_config if !$skip_reload;
}

1;
