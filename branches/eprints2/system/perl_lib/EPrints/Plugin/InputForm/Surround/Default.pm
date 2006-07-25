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

	my $surround = $self->{session}->make_element( "div", class => "wf_component" );
	foreach my $field_id ( $component->get_fields_handled )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>$field_id ) );
	}

	# Help rendering

	my $id_prefix = $component->{prefix}."_help";

	my $title_table = $self->{session}->make_element( "table", cellspacing=>0, class=>"wf_title_table" );
	my $title_tr = $self->{session}->make_element( "tr" );
	$title_table->appendChild( $title_tr );

	my $title_td1 = $self->{session}->make_element( "td", class=>"wf_title" );
	$title_td1->appendChild( $title );
	$title_tr->appendChild( $title_td1 );

	my $title_td2 = $self->{session}->make_element( "td", class=>"wf_show_help ep_only_js", id=>$id_prefix."_show" );
	my $helplink = $self->{session}->make_element( "a", onClick => "EPJS_toggle('$id_prefix',false,'block');EPJS_toggle('${id_prefix}_hide',false,'table-cell');EPJS_toggle('${id_prefix}_show',true,'table-cell');return false", href=>"#" );
	$helplink->appendChild( $self->{session}->make_text( "Help" ) );
	$title_td2->appendChild( $helplink );
	$title_tr->appendChild( $title_td2 );

	my $title_td3 = $self->{session}->make_element( "td", class=>"wf_hide_help ep_hide", id=>$id_prefix."_hide" );
	my $helplink2 = $self->{session}->make_element( "a", onClick => "EPJS_toggle('$id_prefix',false,'block');EPJS_toggle('${id_prefix}_hide',false,'table-cell');EPJS_toggle('${id_prefix}_show',true,'table-cell');return false", href=>"#" );
	$helplink2->appendChild( $self->{session}->make_text( "Hide help" ) );
	$title_td3->appendChild( $helplink2 );
	$title_tr->appendChild( $title_td3 );
	
	my $help_div = $self->{session}->make_element( "div", class => "wf_help ep_no_js", id => $id_prefix );
	$help_div->appendChild( $help );
	
	if( $is_req )
	{
		$title_td1->appendChild( $self->get_req_icon() );
	}

	$surround->appendChild( $title_table );
	$surround->appendChild( $help_div );
	
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

	# Finally add the content (unless we're collapsed)
	my $input_div = $self->{session}->make_element( "div", class => "wf_input" );
	if( !$collapsed )
	{
		$input_div->appendChild( $component->render_content( $self ) );
	}
	
	$surround->appendChild( $input_div );
	
	return $surround;
}

sub get_req_icon
{
	my( $self ) = @_;
	my $reqimg = $self->{session}->make_element( "img", src => "/images/req.gif", class => "wf_req_icon", border => "0" );
	return $reqimg;
}

1;
