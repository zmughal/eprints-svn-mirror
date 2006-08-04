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
	if( $component->get_internal_button )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>"t" ) );
	}

	# Help rendering


	my $title_bar = $self->{session}->make_element( "div" );

	my $title_div = $self->{session}->make_element( "div", class=>"ep_sr_title" );

	if( $is_req )
	{
		$title = $self->{session}->html_phrase( 
			"sys:ep_form_required",
			label=>$title );
	}

	$title_div->appendChild( $title );

	my $help_prefix = $component->{prefix}."_help";

	my $show_help = $self->{session}->make_element( "div", class=>"ep_sr_show_help ep_only_js", id=>$help_prefix."_show" );
	my $helplink = $self->{session}->make_element( "a", onClick => "EPJS_toggle('$help_prefix',false,'block');EPJS_toggle('${help_prefix}_hide',false,'block');EPJS_toggle('${help_prefix}_show',true,'block');return false", href=>"#" );
	$show_help->appendChild( $self->{session}->html_phrase( "inputform/surround/default:show_help",link=>$helplink ) );
	$title_bar->appendChild( $show_help );

	my $hide_help = $self->{session}->make_element( "div", class=>"ep_sr_hide_help ep_hide", id=>$help_prefix."_hide" );
	my $helplink2 = $self->{session}->make_element( "a", onClick => "EPJS_toggle('$help_prefix',false,'block');EPJS_toggle('${help_prefix}_hide',false,'block');EPJS_toggle('${help_prefix}_show',true,'block');return false", href=>"#" );
	$hide_help->appendChild( $self->{session}->html_phrase( "inputform/surround/default:hide_help",link=>$helplink2 ) );
	$title_bar->appendChild( $hide_help );
	
	$title_bar->appendChild( $title_div );

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

	$input_div->appendChild( $help_div );
	$input_div->appendChild( $component->render_content( $self ) );

	$surround->appendChild( $title_bar );
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
