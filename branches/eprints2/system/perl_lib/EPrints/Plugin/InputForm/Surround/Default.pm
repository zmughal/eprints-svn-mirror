package EPrints::Plugin::InputForm::Surround::Default;

use strict;

our @ISA = qw/ EPrints::Plugin /;


sub render
{
	my( $self, $component ) = @_;

	my $is_req = $component->is_required();
	my $help = $component->render_help( $self );
	my $collapsed = $component->is_collapsed();
	my $comp_name = $component->get_name();
	my $title = $component->render_title( $self );
	my @problems = @{$component->get_problems()};

	my $surround = $self->{session}->make_element( "div", class => "ep_sr_component" );
	foreach my $field_id ( $component->get_fields_handled )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>$field_id ) );
	}

	# Help rendering


	my $title_table = $self->{session}->make_element( "table", cellspacing=>0, class=>"ep_sr_title_table" );
	my $title_tr = $self->{session}->make_element( "tr" );
	$title_table->appendChild( $title_tr );

	my $title_td1 = $self->{session}->make_element( "td", class=>"ep_sr_title" );

	if( $is_req )
	{
		$title = $self->{session}->html_phrase( 
			"sys:ep_form_required",
			label=>$title );
	}

	$title_td1->appendChild( $title );
	$title_tr->appendChild( $title_td1 );

	my $help_prefix = $component->{prefix}."_help";

	my $title_td2 = $self->{session}->make_element( "td", class=>"ep_sr_show_help ep_only_js", id=>$help_prefix."_show" );
	my $helplink = $self->{session}->make_element( "a", onClick => "EPJS_toggle('$help_prefix',false,'block');EPJS_toggle('${help_prefix}_hide',false,'table-cell');EPJS_toggle('${help_prefix}_show',true,'table-cell');return false", href=>"#" );
	$helplink->appendChild( $self->{session}->make_text( "Help" ) );
	$title_td2->appendChild( $helplink );
	$title_tr->appendChild( $title_td2 );

	my $title_td3 = $self->{session}->make_element( "td", class=>"ep_sr_hide_help ep_hide", id=>$help_prefix."_hide" );
	my $helplink2 = $self->{session}->make_element( "a", onClick => "EPJS_toggle('$help_prefix',false,'block');EPJS_toggle('${help_prefix}_hide',false,'table-cell');EPJS_toggle('${help_prefix}_show',true,'table-cell');return false", href=>"#" );
	$helplink2->appendChild( $self->{session}->make_text( "Hide help" ) );
	$title_td3->appendChild( $helplink2 );
	$title_tr->appendChild( $title_td3 );
	
	my $help_div = $self->{session}->make_element( "div", class => "ep_sr_help ep_no_js", id => $help_prefix );
	$help_div->appendChild( $help );
	

	# Problem rendering

	if( scalar @problems > 0 )
	{
		my $problem_div = $self->{session}->make_element( "div", class => "wf_problems" );
		foreach my $problem ( @problems )
		{
			$problem_div->appendChild( $problem );
		}
		$surround->appendChild( $problem_div );
	}

	# Finally add the content 
	my $input_div = $self->{session}->make_element( "div", class => "ep_sr_input" );

	$input_div->appendChild( $component->render_content( $self ) );

	$surround->appendChild( $title_table );
	$surround->appendChild( $help_div );
	$surround->appendChild( $input_div );

	if( $collapsed )
	{
		my $outer = $self->{session}->make_doc_fragment;
		my $col_prefix = $component->{prefix}."_help";
		my $col_div = $self->{session}->make_element( "div", class=>"ep_sr_collapse_bar ep_only_js", id => $col_prefix."_bar" );
		my $col_link =  $self->{session}->make_element( "a", onClick => "EPJS_toggle('${col_prefix}_bar',true,'block');EPJS_toggle('${col_prefix}_full',false,'block');return false", href=>"#" );
		$col_link->appendChild( $component->render_title( $self ) );
		my $col_link2 =  $self->{session}->make_element( "a", onClick => "EPJS_toggle('${col_prefix}_bar',true,'block');EPJS_toggle('${col_prefix}_full',false,'block');return false", href=>"#" );
		$col_link2->appendChild( $self->{session}->make_element( "img", alt=>"+", src=>"/images/style/plus.png", border=>0 ) );
		$col_div->appendChild( $col_link2 );
		$col_div->appendChild( $self->{session}->make_text( " " ) );
		$col_div->appendChild( $col_link );
		$outer->appendChild( $col_div );
		my $inner = $self->{session}->make_element( "div", class=>"ep_no_js", id => $col_prefix."_full" );
		$inner->appendChild( $surround );
		$outer->appendChild( $inner );
		return $outer;
	}
		
	
	
	return $surround;
}

1;
