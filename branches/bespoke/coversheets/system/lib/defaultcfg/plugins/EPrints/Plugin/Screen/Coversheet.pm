
package EPrints::Plugin::Screen::Coversheet;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	my $coversheetid = $self->{session}->param( "coversheetid" );
	if( defined $coversheetid )
	{
		$self->{processor}->{coversheetid} = $coversheetid;
		$self->{processor}->{coversheet} = new EPrints::DataObj::Coversheet( 
						$self->{session}, 
						$coversheetid );
	}

	if( !defined $self->{processor}->{coversheet} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase(
				"no_such_coversheet",
				id => $self->{session}->make_text( 
						$self->{processor}->{coversheetid} ) ) );
		return;
	}

	$self->{processor}->{dataset} = 
		$self->{processor}->{coversheet}->get_dataset;

}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&coversheetid=".$self->{processor}->{coversheetid};
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "coversheet/view" );
}

sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{coversheet};

	return 1 if( $self->{session}->allow_anybody( $priv ) );

	return 0 if( !defined $self->{session}->current_user );

	return $self->{session}->current_user->allow( $priv, $self->{processor}->{coversheet} );
}

sub workflow
{
        my( $self, $staff ) = @_;

        my $cache_id = "workflow";
        $cache_id.= "_staff" if( $staff );

        if( !defined $self->{processor}->{$cache_id} )
        {
                my %opts = (
                        item => $self->{processor}->{coversheet},
                        session => $self->{session} );
                $opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
                $self->{processor}->{$cache_id} = EPrints::Workflow->new(
                        $self->{session},
                        "default",
                        %opts );
        }

        return $self->{processor}->{$cache_id};
}

sub uncache_workflow
{
        my( $self ) = @_;

        delete $self->{processor}->{workflow};
        delete $self->{processor}->{workflow_staff};
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "coversheetid", $self->{processor}->{coversheetid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

1;

