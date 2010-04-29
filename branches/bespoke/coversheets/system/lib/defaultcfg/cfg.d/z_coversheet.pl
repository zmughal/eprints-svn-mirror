
# Where the coversheets are stored:
$c->{coversheets_path_suffix} = '/coversheets';
$c->{coversheets_path} = $c->{archiveroot}."/cfg/static".$c->{coversheets_path_suffix};
$c->{coversheets_url} = $c->{base_url}.$c->{coversheets_path_suffix};

$c->{office_path} = "/opt/openoffice.org3/";
$c->{office_program_path} = $c->{office_path}."program/";
$c->{open_office_name} = "soffice.bin";
$c->{open_office_exe} = $c->{office_program_path}.$c->{open_office_name};
$c->{odt_converter_exe} = $c->{base_path}."/bin/DocumentConverter.py";

$c->{executables}->{python} = $c->{office_program_path}.'python';
$c->{executables}->{pdftk} = "/usr/bin/pdftk";

# Fields used for applying coversheets
$c->{license_application_fields} = [ "type" ];


#new permissions for coversheet toolkit
$c->{roles}->{"coversheet-editor"} =
[
        "coversheet/write",
        "coversheet/activate",
        "coversheet/deprecate",
        "coversheet/view",
];
push @{$c->{user_roles}->{editor}}, 'coversheet-editor';
push @{$c->{user_roles}->{admin}}, 'coversheet-editor';

#backwards compatibility
$c->{editpermfields} = $c->{editor_limit_fields};


# called by Apache::Rewrite
# return undef to force Apache::Rewrite to process the request
# return OK if we process the request
$c->{coversheet}->{process_request} = sub
{
	my ( $session, $r, $eprint, $pos, $tail) = @_;


	use Time::Local 'timegm_nocheck';
	use EPrints::Apache::AnApache; # Apache constants
	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos( $session, $eprint->get_id, $pos );
	return unless defined $doc;

	#check for magic 'nocoversheet' flag and only provide if they're an editor or an administrator.
	my $uri = URI::http->new($session->get_request->unparsed_uri);
	my %args = $uri->query_form();

	if ($args{nocoversheet})
	{
		my $user = $session->current_user;
		return if (
			defined $user and (
				$user->get_value('usertype') eq 'admin' or
				$user->get_value('usertype') eq 'editor'
			)
		);
	}

	#if we can't get any pages, then there's no coversheet for this item.
	my $pages;
        if( $session->get_repository->can_call( "coversheet", "get_pages" ) )
	{
		$pages = $session->get_repository->call( [ "coversheet", "get_pages" ], $session, $eprint, $doc);
	}
	return unless defined $pages;

	# check whether covered file exists
	my $dir = $doc->coversheeted_docs_path();
	my $filename = EPrints::Utils::join_path( $dir, $doc->get_main );
	if( -e $filename ) 
	{
		use Time::Local;
		my $covermod = ( stat( $filename ) )[9];

		my $eprintmoddate = $eprint->get_value('lastmod');
			#2009-08-21 13:05:22
		$eprintmoddate =~ m/([0-9]{4})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2})/;
		my $eprintmod = timelocal($6,$5,$4,$3,( $2 - 1 ),$1);

#		my $coversheet = EPrints::DataObj::Coversheet->new($session, $doc->get_value('coversheet'));
		#find the most recently modified coversheet (it may be the one that needs to be applied)
		my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			custom_order => "-lastmod",
			dataset => $session->get_repository->get_dataset('coversheet'),
			session => $session );
		my $list = $searchexp->perform_search;
###test this (most recent moddate will cause regenerations.


		my $coversheet = EPrints::DataObj::Coversheet->new($session, $list->get_ids->[0]);
		my $coversheetmoddate = $coversheet->get_value('lastmod');
		$coversheetmoddate =~ m/([0-9]{4})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2})/;
		my $coversheetmod = timelocal($6,$5,$4,$3,( $2 - 1 ),$1);

		


		#return the previously generated file if it's newer than both the eprint and the coversheet.
		#'<' = bigger = more elapsed time = newer
		if(
			($eprintmod < $covermod) and
			($coversheetmod < $covermod)
		)
		{
			$r->filename( $filename );
			$session->terminate;
			return OK;
		}
	}


	# generate covered file

        my $plugin = $session->plugin( "Convert::AddCoversheet" );
        unless( defined $plugin )
        {
                $session->get_repository->log("[cfg.d/coversheet.pl] Couldn't load Convert::AddCoversheet plugin\n");
                return;
        }
 
	$filename = $plugin->export( $dir, $doc, $pages );
	unless ( defined $filename )
        {
                $session->get_repository->log("[coversheet.pl] Couldn't create target document\n");
                return;
        }
##detect error and pass back!!!!!


	# serve coverpage
	$r->filename( $filename );
	$session->terminate;
	return OK;
};


# return a hashref containing the paths of the frontpage and backpage
$c->{coversheet}->{get_pages} = sub {

	my ( $session, $eprint, $doc ) = @_;

	return unless $doc->get_type eq "application/pdf";
#	return unless $eprint->get_value( "eprint_status" ) eq "archive";

	my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			custom_order => "-apply_priority/-coversheetid",
			dataset => $session->get_repository->get_dataset('coversheet'),
			session => $session );
#only use active coversheets
	$searchexp->add_field(
		$session->get_repository->get_dataset('coversheet')->get_field('status'),
		'active',
	);

	my $list = $searchexp->perform_search;

	my $coversheet;
	foreach my $possible_coversheet ($list->get_records)
	{
		if ($possible_coversheet->applies_to_eprint($eprint))
		{
			$coversheet = $possible_coversheet;
			last;
			
		}
	}
	$list->dispose();

#	my $coversheet = $session->get_repository->get_dataset('coversheet')->get_object($session, $doc->get_value('coversheet'));
	return unless defined $coversheet;

	my $frontfile_path = $coversheet->get_file_path('frontfile');
	my $frontfile_type = $coversheet->get_page_type('frontfile');
	my $backfile_path = $coversheet->get_file_path('backfile');
	my $backfile_type = $coversheet->get_page_type('backfile');


	return unless $frontfile_path or $backfile_path;
	return { 
		frontfile => {
			path => $frontfile_path,
			type => $frontfile_type
		},
		backfile => {
			path => $backfile_path,
			type => $backfile_type,
		}
	};
};

