
# Lemur Prints!

package EPrintSite::lemurprints;

sub new
{
	my( $class ) = @_;

	my $self = {};
	bless $self, $class;

$self->{site_root} = "/opt/eprints/sites/lemurprints";

$self->{user_meta_file} 	= "$self->{site_root}/cfg/metadata.user";
$self->{eprint_fields_file}	= "$self->{site_root}/cfg/metadata.eprint-fields";
$self->{eprint_types_file} 	= "$self->{site_root}/cfg/metadata.eprint-types";

#$self->{template_user_intro} 	= "$self->{site_root}/cfg/template.user-intro";
#$self->{template_fail_reply} 	= "$self->{site_root}/cfg/template.fail-reply";
#$self->{template_fail_user} 	= "$self->{site_root}/cfg/template.fail-user";
#$self->{template_change_email} 	= "$self->{site_root}/cfg/template.change-email";
#$self->{subject_config} 	= "$self->{site_root}/cfg/subjects";


# List of supported languages is in EPrintSite.pm
# Default Language for this archive
$self->{default_language} = "english";

	return $self;
}

1;
