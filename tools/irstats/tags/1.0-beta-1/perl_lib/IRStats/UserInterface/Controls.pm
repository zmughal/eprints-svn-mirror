package IRStats::UserInterface::Controls;

use warnings;
use strict;
use Data::Dumper;

our @ISA = qw/ IRStats::UserInterface /;

sub date_control
{
	my ($self) = @_;
	my $date_values = $self->_date_values();

	my $r = "<fieldset class='date_range'><legend>Date Range</legend>\n";

	$r .= <<EOH;
<div class='help'>
Change the period of access log data included based on when the request was made. Warning! The more data you include the longer it will take to generate the results.
</div>
EOH

	$r .= '<input type="radio" id="IRS_dateperiod" name="IRS_datechoice" value="period" checked="1"/> Period:' . "\n";
	$r .= $self->drop_box({name => "period", onfocus => "document.getElementById('IRS_dateperiod').click()"}, $date_values->{periods});
	$r .= '<br/>';
	$r .= '<input type="radio" id="IRS_daterange" name="IRS_datechoice" value="range" /> From date:' . "\n";
	$r .= $self->drop_box({name => 'start_day', onfocus => "document.getElementById('IRS_daterange').click()"},[{value => '1', display => "Beginning"}, @{$date_values->{days}}]);
	$r .= $self->drop_box({name => 'start_month', onfocus => "document.getElementById('IRS_daterange').click()"},$date_values->{months});
	$r .= $self->drop_box({name => 'start_year', onfocus => "document.getElementById('IRS_daterange').click()"},$date_values->{years});
	$r .= '<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Until date:';
	$r .= $self->drop_box({name => 'end_day', onfocus => "document.getElementById('IRS_daterange').click()"},[{value=>'31', display => 'End'},@{$date_values->{days}}]);
	$r .= $self->drop_box({name => 'end_month', onfocus => "document.getElementById('IRS_daterange').click()"},$date_values->{months});
	$r .= $self->drop_box({name => 'end_year', onfocus => "document.getElementById('IRS_daterange').click()"},$date_values->{years});

	$r .= "</fieldset>";

	return $r;


}


sub view_control
{
	my ($self) = @_;

	my $image_url = $self->{session}->get_conf->static_url;

	my $columns = [[
# Summaries
		"MonthlyDownloadsGraph",
		"DailyDownloadsGraph",
		"MonthlyUniqueVisitorsGraph",
		"AllMonthlyDownloadsGraph",
		"DownloadCountHTML",
	],[
# Simple Analyses
		"TopTenTable",
		"ReferrerGraph",
		"SearchEngineGraph",
		"TopCountriesTable",
		"TopTenAcademies",
		"TopTenSearchTermsTable",
		"RawDataTableHTML",
		"RawDataTableCSV",
	],[
# Complex Analyses
		"TopTenMonthlyDownloadsGraph",
		"TopTenAuthorsTable",
		"TopTenTableDashLinked",
		"HighestClimbersTable",
		"MonthlyDownloadsByGroupGraph",
		"TopTenNonSearchReferrers",
		"RandomFromTopTenHTML",
		"TopItemHTML",
	]];

	my @column_labels = (
		"Summary Data",
		"Simple Analyses",
		"Complex Analyses",
		"Unknown",
	);
	my $unknown = [];
	my( %available, %known );
	foreach my $column (@$columns)
	{
		$known{$_} = 1 for(@$column);
	}
	foreach my $view_name ($self->{session}->get_views)
	{
		$available{$view_name} = 1;
		if( !exists($known{$view_name}) )
		{
			push @$unknown, $view_name;
		}
	}
	push @$columns, $unknown if @$unknown;


	my $r = "<fieldset class='view_choice'><legend>Choice of View</legend>\n";

	$r .= <<EOH;
<div class='help'>
The view determines how data is rendered and may provide additional data refinements (for example showing a summary for authors).
</div>
EOH

	my $first_view = 1;
	$r .= "<ul><table><tr>";
	foreach my $column (0..$#$columns)
	{
		$r .= "<td>";
		$r .= "<li>".$column_labels[$column]."</li>";
		$r .= "<ul>";
		foreach my $view_name (@{$columns->[$column]})
		{
			next unless $available{$view_name};

			my $view_label = $self->{session}->get_phrase( "view:$view_name:title" ) || $view_name;
			$r .= "<li><input type='radio' name='view' value='$view_name' id='$view_name' ";
			if( $first_view )
			{
				$r .= "checked='1'";
				$first_view = 0;
			}
			$r .= "/><label for='$view_name'><img width='100' src='$image_url/view_thumbs/".$view_name."_th.png'>$view_label</label></li>\n";
		}
		$r .= "</ul>";
		$r .= "</td>";
	}
	$r .= "</tr></table></ul>";

	$r .= "<div style='clear: left'></div>";

	$r .= "</fieldset>";
}



sub eprints_control
{
	my ($self) = @_;
	my $r = '';

	my $database = $self->{session}->get_database;

	my @sets = $self->{session}->get_conf->set_ids;
	
	my $set_citations = {};
	my $set_codes = {};

	my( $set_ids, $set_drop_box_values ) = ({},{});
	for(@sets)
	{
		my $set_name = $self->{session}->get_phrase( "set_$_" ) || $_;
		$set_ids->{$_} = [];
		$set_drop_box_values->{$_} = [{
			value => 'dummy',
			display => "Choose a $set_name",
		}];
	}
	
	foreach my $set_class_name (@sets)
	{
		$set_ids->{$set_class_name} = $database->get_all_sets_ids_in_class($set_class_name);
		foreach my $set_member_id (@{$set_ids->{$set_class_name}})
		{
			$set_citations->{$set_class_name}->{$set_member_id} = $database->get_citation($set_member_id, $set_class_name);
			$set_codes->{$set_class_name}->{$set_member_id} = $database->get_code($set_member_id, $set_class_name);
		}
		foreach my $set_member_id (sort { $set_citations->{$set_class_name}->{$a} cmp $set_citations->{$set_class_name}->{$b} } keys %{$set_citations->{$set_class_name}})
		{
			push @{$set_drop_box_values->{$set_class_name}}, {
				value => $set_class_name . '_' . $set_codes->{$set_class_name}->{$set_member_id}, 
				display => $set_citations->{$set_class_name}->{$set_member_id} . ' (' . $set_codes->{$set_class_name}->{$set_member_id} .')'
			}; 
		}


	}

	$r .= "<fieldset class='eprint_set_selection'><legend>Set of Eprints</legend>\n";

	$r .= <<EOH;
<div class='help'>
You can choose to only include data for particular sets (e.g. eprints deposited by a named author) or show data for only a single eprint.
</div>
EOH

	$r .= '<input type="radio" name="IRS_epchoice" id="IRS_epchoice" value="All" checked="1"/> <label for="IRS_epchoice">All</label> <br/>' . "\n";
	
	for(@sets)
	{
		my $set_name = $self->{session}->get_phrase( "set_$_" ) || $_;
		$r .= "<input type='radio' id='IRS_epchoice_$_' name='IRS_epchoice' value='$_' /> $set_name \n";
		$r .= $self->drop_box({name => "${_}s", onchange => "document.getElementById('IRS_epchoice_$_').click()"}, $set_drop_box_values->{$_}); 
		$r .= '</br> ' . "\n";
	}

	$r .= '<input type="radio" id="IRS_epchoice_eprint" name="IRS_epchoice" value="EPrint" /> Eprint ID <input onfocus="document.getElementById(\'IRS_epchoice_eprint\').click()" type="text" name="eprint" value=""/>';

	$r .= "</fieldset>";
	
	return $r;
}

sub _date_values
{
	my ($self) = @_;
	my $days;
	my $months;
	my $years;
	my $periods = [ 
		{ value => "-3m", display => "Last Quarter"},
		{ value => "-6m", display => "Last Six Months"},
		{ value => "-12m", display => "Last Year"}
	];
	my $earliest_year = 2005;

	foreach (1 .. 31)
	{
		push @{$days}, {value => $_, display => $_};
	}

	my @month_names = qw( null January February March April May June July August September October November December );
	foreach (1 .. 12)
	{
		push @{$months}, { value => $_, display => $month_names[$_]};
	}

	my $yesterday = IRStats::Date->new(); #defaults to yesterday

	foreach my $year ($earliest_year .. $yesterday->part('year'))
	{
		push @{$years}, {value => $year, display => $year};
		foreach my $quarter (1 .. 4)
		{
			if ($year != $yesterday->part('year'))
			{
				push @{$periods}, { value => "Q$quarter$year", display => "Q$quarter, $year" };
			}
			else
			{
				if ($quarter == 1)
				{
					push @{$periods}, { value => "Q$quarter$year", display => "Q$quarter, $year" };
				}
				elsif ($quarter == 2)
				{
					if ($yesterday->part('month') > 3)
					{
						push @{$periods}, { value => "Q$quarter$year", display => "Q$quarter, $year" };
					}
				}
				elsif ($quarter == 3)
				{
					if ($yesterday->part('month') > 6)
					{
						push @{$periods}, { value => "Q$quarter$year", display => "Q$quarter, $year" };
					}
				}
				elsif ($quarter == 4)
				{
					if ($yesterday->part('month') > 9)
					{
						push @{$periods}, { value => "Q$quarter$year", display => "Q$quarter, $year" };
					}
				}
			}
		}
	}

	return { days => $days, months => $months, years => $years, periods => $periods };
}

sub drop_box
{
	my ($self, $properties, $contents) = @_;

	my $r = "<select ";
	foreach my $property (keys %{$properties})
	{
		$r .= $property . '="' . $properties->{$property} . '" ';
	}
	$r .= ">\n";
	foreach my $choice (@{$contents})
	{
		$r .= "<option value=\"$choice->{value}\">";
		$r .= $choice->{'display'};
		$r .= "</option>\n";
	}
	$r .= "</select>";
	return $r;
}


1;
