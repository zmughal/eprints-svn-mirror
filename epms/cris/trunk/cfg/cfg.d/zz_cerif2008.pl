=begin

=for InternalDoc

CERIF 2008 Specification for EPrints 3.2
----------------------------------------

This file provides additional data sets for use with EPrints to support the core entities specified in CERIF 2008.

This does not cover all aspects of the CERIF semantics.

Based on CERIF 2008 1.0 (accessed 2010-01-25):
http://www.eurocris.org/cerif/cerif-releases/cerif-2008/

=end InternalDoc

=cut

my $accept = $c->{plugins}->{"Export::SummaryPage"}->{params}->{accept} ||= [];

push @$accept, qw( dataobj/project dataobj/org_unit );

push @{$c->{user_roles}->{editor}}, qw(
	+project/create
	+project/edit
	+project/destroy
	+project/details
	+org_unit/create
	+org_unit/edit
	+org_unit/destroy
	+org_unit/details
);

push @{$c->{public_roles}}, qw(
    +project/export
    +project/search
	+project/view
    +org_unit/export
    +org_unit/search
	+org_unit/view
);

push @{$c->{browse_views}}, (
	{
		id => "project",
		dataset => "project",
		allow_null => 0,
		hideempty => 1,
		menus => [
			{
				fields => [ "title" ],
			},
		],
		order => "-start/title",
	},

	{
		id => "funder",
		dataset => "eprint",
		allow_null => 0,
		hideempty => 1,
		menus => [
			{
				fields => [ "org_units_title" ],
			},
		],
		order => "-datestamp/title",
	},
);

$c->{datasets}->{project} = {
	class => 'Cerif::Project',
	sqlname => 'project',
	datestamp => 'start',
	columns => [qw( title )],
	index => 1,
	import => 1,
	search => {
		simple => {
			search_fields => [{
				id => "q",
				meta_fields => [qw(
					title
					contributors_name
					description
				)],
			}],
			order_methods => {
				"bydate"  	 =>  "-start/title",
				"bytitle" 	 =>  "title",
				"byvalue"	 =>  "value/title",
			},
			default_order => "bydate",
			show_zero_results => 1,
			citation => "result",
		},
	},
};

$c->{datasets}->{org_unit} = {
	class => 'Cerif::OrganisationUnit',
	sqlname => 'org_unit',
	datestamp => 'start',
	columns => [qw( title )],
	index => 1,
	import => 1,
};

$c->{fields}->{project} = [] if !defined $c->{fields}->{project};
unshift @{$c->{fields}->{project}}, (
	{
		name => 'projectid',
		type => 'counter',
		sql_counter => 'projectid',
	},

	{
		name => "value",
		type => "int",
	},

	{
		name => 'start',
		type => 'time',
	},

	{
		name => 'end',
		type => 'time',
	},

	{
		name => 'acronym',
		type => 'text',
		maxlength => 16,
	},

	{
		name => 'uri',
		type => 'url',
		maxlength => 128,
	},

	{
		name => 'title',
		type => 'text',
	},

	{
		'name' => 'contributors',
		'type' => 'dataobjref',
		datasetid => 'user',
		'multiple' => 1,
		'fields' => [
		{
			'sub_name' => 'type',
			'type' => 'namedset',
			set_name => "project_contributor_type",
		},
		{
			'sub_name' => 'name',
			'type' => 'name',
			required => 1,
		},
		],
	},

	{
		name => 'description',
		type => 'longtext',
	},

	{
		name => 'keywords',
		type => 'longtext',
	},

	{
		name => 'org_units',
		type => 'dataobjref',
		datasetid => 'org_unit',
		multiple => 1,
		fields => [
			{ sub_name=>"title", type=>"text", },
		],
	},

	{
		name => 'eprints',
		type => 'subobject',
		multiple => 1,
		datasetid => 'archive',
		dataset_fieldname => '',
		dataobj_fieldname => 'projects_id',
		export_as_xml => 0,
	},

#	{
#		name => 'relation',
#		type => 'compound',
#		multiple => 1,
#		fields => [
#			{
#				sub_name => 'type',
#				type => 'id',
#			},
#			{
#				sub_name => 'uri',
#				type => 'id',
#			},
#			{
#				sub_name => 'start',
#				type => 'time',
#			},
#			{
#				sub_name => 'end',
#				type => 'time',
#			},
#		]
#	},
);

$c->{fields}->{org_unit} = [] if !defined $c->{fields}->{org_unit};
unshift @{$c->{fields}->{org_unit}}, (
	{
		name => 'org_unitid',
		type => 'counter',
		sql_counter => 'org_unitid',
	},

	{
		name => 'start',
		type => 'time',
	},

	{
		name => 'end',
		type => 'time',
	},

	{
		name => 'acronym',
		type => 'text',
		maxlength => 16,
	},

	{
		name => 'title',
		type => 'text',
	},

	{
		name => 'uri',
		type => 'url',
		maxlength => 128,
	},

	{
		name => 'res_act', # research activity
		type => 'longtext',
	},

	{
		name => 'keywords',
		type => 'longtext',
	},

	{
		name => 'projects',
		type => 'dataobjref',
		datasetid => 'project',
		multiple => 1,
		fields => [
			{ sub_name=>"title", type=>"text", },
		],
	},

	{
		name => 'relation',
		type => 'compound',
		multiple => 1,
		fields => [
			{
				sub_name => 'type',
				type => 'id',
			},
			{
				sub_name => 'uri',
				type => 'id',
			},
			{
				sub_name => 'start',
				type => 'time',
			},
			{
				sub_name => 'end',
				type => 'time',
			},
		]
	},
);

# strip out the native projects

push @{$c->{fields}->{eprint}},
	{
		name => 'org_units',
		type => 'dataobjref',
		multiple => 1,
		datasetid => 'org_unit',
		fields => [
			{ sub_name=>"title", type=>"text", },
		],
	};

if( !grep { $_->{name} eq "projects" } @{$c->{fields}->{eprint}} )
{
	push @{$c->{fields}->{eprint}},
		{
			name => 'projects',
			type => 'dataobjref',
			multiple => 1,
			datasetid => 'project',
			fields => [
				{ sub_name=>"title", type=>"text", },
			],
		};
}

$c->{search}->{project} = 
{
};

{
no warnings;

package Cerif::Project;

@Cerif::Project::ISA = qw( EPrints::DataObj );

sub get_dataset_id { "project" }

sub get_url { shift->uri }

package Cerif::OrganisationUnit;

@Cerif::OrganisationUnit::ISA = qw( EPrints::DataObj );

sub get_dataset_id { "org_unit" }

sub get_url { shift->uri }

}
