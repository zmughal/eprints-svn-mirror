package EPrints::DataObj::Coversheet;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

sub valid_file_extensions
{
	return [ 'pdf', 'odt' ];
}

=item $thing = EPrints::DataObj::Access->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"coversheetid", type=>"int", required=>1, can_clone=>0 },

		{ name=>"datestamp", type=>"time", required=>1, text_index=>0 },

		{ name=>"lastmod", type=>"time", required=>0, import=>0,
                	render_res=>"minute", render_style=>"short", can_clone=>0 },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>1, text_index=>0 },

		{ name=>"status", type=>"set", required=>1, text_index=>0,
			options => [qw/ draft active deprecated /] },

		{ name=>"name", type=>"text", required=>1 },

		{ name=>"description", type=>"longtext", required => 1 },

		{ name=>"official_url", type=>"url" },

		{ name=>"version_comments", type=>"longtext" },

		{ name=>"notes", type=>"longtext" },

		{
			name=>"frontfile",
			type=>"file",
			render_value=>"EPrints::DataObj::Coversheet::render_coversheet_file",
			render_input => "EPrints::DataObj::Coversheet::render_coversheet_file_input"
		},
		{
			name=>"backfile",
			type=>"file",
			render_value=>"EPrints::DataObj::Coversheet::render_coversheet_file",
			render_input => "EPrints::DataObj::Coversheet::render_coversheet_file_input"
		},
		{
			name=>"proposed_frontfile",
			type=>"file",
			render_value=>"EPrints::DataObj::Coversheet::render_coversheet_file",
		},
		{
			name=>"proposed_backfile",
			type=>"file",
			render_value=>"EPrints::DataObj::Coversheet::render_coversheet_file",
		},
		{
			name=>"frontfile_proposer_id",
			type=>"int",
		},
		{
			name=>"backfile_proposer_id",
			type=>"int",
		},

		{
			name => "apply_priority",
			type => "int",
		},
		{
			name => "apply_to",
			type => "search",
			datasetid => "eprint",
			fieldnames => "license_application_fields",
		},


	);
}

######################################################################

=back

=head2 Constructor Methods

=over 4

=cut

######################################################################

=item $thing = EPrints::DataObj::Coversheet->new( $session, $id )

The data object identified by $id.

=cut

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_database->get_single( 
			$session->get_repository->get_dataset( "coversheet" ),
			$id );
}

=item $thing = EPrints::DataObj::Coversheet->new_from_data( $session, $known )

A new C<EPrints::DataObj::Coversheet> object containing data $known (a hash reference).

=cut

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "coversheet" ) );
}

######################################################################

=item $defaults = EPrints::DataObj::Coversheet->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

        if( !defined $data->{coversheetid} )
        {
                $data->{coversheetid} = _create_coversheetid( $session );
        }
	
	$data->{status} = 'draft';
	$data->{datestamp} = EPrints::Time::get_iso_timestamp();

	return $data;
}


######################################################################
=pod

=item $user->commit( [$force] )

Write this object to the database.

As modifications to files don't make any changes to the metadata, this will
always write back to the database.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;


        if( !$self->is_set( "datestamp" ) )
        {
                $self->set_value(
                        "datestamp" ,
                        EPrints::Time::get_iso_timestamp() );
        }

	$self->set_value("lastmod" , EPrints::Time::get_iso_timestamp() );

	my $coversheet_ds = $self->{session}->get_repository->get_dataset( "coversheet" );
	$self->tidy;
	my $success = $self->{session}->get_database->update(
		$coversheet_ds,
		$self->{data} );
	
	$self->queue_changes;

	return( $success );
}


######################################################################

=head2 Object Methods

=cut

######################################################################

=item $foo = $thing->remove()

Remove this record from the data set (see L<EPrints::Database>).

=cut

sub remove
{
	my( $self ) = @_;
	
	my $rc = 1;

	foreach (qw/ frontfile backfile /) #get rid of the documents
	{
		$self->erase_page($_);
	}
	
	my $database = $self->{session}->get_database;

	$rc &&= $database->remove(
		$self->{dataset},
		$self->get_id );

	return $rc;
}

######################################################################
# =pod
# 
# =item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
# 
# Create a new object of this type in the database. 
# 
# $dataset is the dataset it will belong to. 
# 
# $data is the data structured as with new_from_data.
# 
# =cut
######################################################################

sub create_from_data
{
        my( $class, $session, $data, $dataset ) = @_;

        my $new_coversheet = $class->SUPER::create_from_data( $session, $data, $dataset );

        $session->get_database->counter_minimum( "coversheetid", $new_coversheet->get_id );

        return $new_coversheet;
}

######################################################################
# 
# $coversheetid = EPrints::DataObj::User::_create_coversheetid( $session )
#
# Get the next unused coversheetid value.
#
######################################################################

sub _create_coversheetid
{
        my( $session ) = @_;

        my $new_id = $session->get_database->counter_next( "coversheetid" );

        return( $new_id );
}

sub get_file_path
{
	my ($self, $fieldname) = @_;

        foreach (@{$self->valid_file_extensions()})
        {
		my $file_path = $self->get_path() . '/' . $fieldname . '.' . $_;
                return $file_path if -e $file_path;
        }

	return undef;
}

sub get_file_url
{
	my ($self, $fieldname) = @_;

	foreach (@{$self->valid_file_extensions()})
	{
		my $filename = $fieldname . '.' . $_;
		my $file_path = $self->get_path() . '/' . $filename;
		return
			$self->{session}->get_repository->get_conf('coversheets_url') . '/' . $self->get_id . '/' . $filename
		if
			-e $file_path;
	}

	return undef;
}

sub get_page_type
{
	my ($self, $fieldname) = @_;

	my $file_path = $self->get_file_path($fieldname);
	if ($file_path)
	{
		$file_path =~ m/[^\.]*$/;
		return $&;
	}

	return 'none';
}

sub render_coversheet_file
{
        my( $session, $field, $value, $alllangs, $nolink, $coversheet ) = @_;

        my $f = $session->make_doc_fragment;

	my $label = $session->html_phrase('Coversheet/Type:' . $coversheet->get_page_type($field->get_name));

	my $url = $coversheet->get_file_url($field->get_name);
	if ($url)
	{
		my $link = $session->render_link($url);
		$link->appendChild($label);
		$f->appendChild($link);
	}
	else
	{
		$f->appendChild($label);
	}

        return $f;
}

#takes a user and a fieldname (frontfile, backfile) and returns true if this user can approve the new file.
sub can_approve
{
	my ($self, $user, $fieldname) = @_;

	return ($user->get_id != $self->get_value( $fieldname . '_proposer_id') );
}


sub update_coversheet
{
	my ($self, $fieldname) = @_;

	my $new_file = $self->get_file_path('proposed_' . $fieldname);
	return unless $new_file; #don't remove the old one unless we have the new one 

	unlink $self->get_file_path($fieldname) if $self->get_file_path($fieldname);
	
	$new_file =~ m([^\.]*$); #grab extension
	my $new_file_path = $self->get_path() . '/' . $fieldname . '.' . $&;

	rename($self->get_file_path('proposed_' . $fieldname), $new_file_path);

	$self->set_value($fieldname . '_proposer_id', undef);
	$self->commit;
}

sub render_coversheet_file_input
{
        my( $field, $session, $value, $dataset, $staff, $hidden_field, $obj, $basename ) = @_;

        my $f = $session->make_doc_fragment;

	$f->appendChild($session->html_phrase('current_file'));
        $f->appendChild($field->render_value($session, $value, undef, undef, $obj));

	$f->appendChild($session->make_element('br'));
#       <input name="c3_first_file" type="file" id="c3_first_file" />

	if ($obj->get_file_path('proposed_' . $field->get_name))  #if a proposed file exists
	{
		$f->appendChild($session->html_phrase('proposed_new_file'));
		$f->appendChild($session->get_repository->get_dataset('coversheet')->get_field('proposed_' . $field->get_name)->render_value($session, undef, undef, undef, $obj));
		$f->appendChild($session->make_element('br'));

	}

	$f->appendChild($session->html_phrase('upload_file'));
        my $input = $session->make_element('input', type => 'file', id => $field->get_name . '_input', name => $field->get_name . '_input' );
        $f->appendChild($input);

        return $f;
}

#return path to coversheet files, and create directories.
sub get_path
{
	my ($self) = @_;

	my $path = $self->{session}->get_repository->get_conf('coversheets_path');
	mkdir $path unless -e $path; #not too fantastic

	$path .= '/' . $self->get_id;
	unless (-e $path)
	{
		mkdir $path unless -e $path;
	}

	return $path;
}

#return paths to live files
sub get_live_paths
{
	my ($self) = @_;

	my $repository = $self->{session}->get_repository;;
	my @paths;

	foreach my $lang (@{$repository->get_conf('languages')})
	{
		push @paths, $repository->get_conf('archiveroot') . '/html/' . $lang . $repository->get_conf('coversheets_path_suffix') . '/' . $self->get_id ;
	}

	return @paths;
}


#name is metafield name (e.g. frontfile, backfile)
sub erase_page
{
	my ($self, $fieldname) = @_;

	my @paths_to_check = ( $self->get_path, $self->get_live_paths );

	foreach my $path (@paths_to_check)
	{
		my $filename = $path . '/' . $fieldname . '.';
		foreach my $extension (@{$self->valid_file_extensions()})
		{
			my $full_filename = $filename . $extension;
			unlink $full_filename if -e $full_filename;
		}
	}
	$self->commit();
}

#for now check extensions...
sub valid_file
{
	my ($self, $file) = @_;

	$file =~ m/[^\.]*$/;
	my $extension = $&;

	foreach (@{$self->valid_file_extensions()})
	{
		return 1 if $_ eq lc($extension);
	}

	return 0;
}

#depricated as items no longer have a coversheet as a metadata field
##returns true if there is at least one document with this coversheet attached.
#sub is_in_use
#{
#	my ($self) = @_;
#
#        my $ds = $self->{session}->get_repository->get_dataset('document');
#        my $search = new EPrints::Search(
#                session=>$self->{session},
#                dataset=>$ds,
#        );
#        $search->add_field($ds->get_field('coversheet'), $self->get_id());
#        my $list = $search->perform_search;
#
#        my $div = $self->{session}->make_element( "div", class=>"ep_block" );
#
#	return 1 if $list->count > 0;
#	return 0;
#}

#based on EPrints->in_edorial_scope_of
sub applies_to_eprint
{
	my( $self, $eprint ) = @_;

	return 0 unless $self->is_set('apply_to');
print STDERR "Checking if this applies\n";
	my $search = $self->{dataset}->get_field('apply_to')->make_searchexp($self->{session}, $self->get_value('apply_to')); #it's not a multiple field
	my $r = $search->get_conditions->item_matches( $eprint );
	$search->dispose;

print STDERR ($r ? '1' : '0'), "\n";


	return 1 if $r;
	return 0;
}



1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut
