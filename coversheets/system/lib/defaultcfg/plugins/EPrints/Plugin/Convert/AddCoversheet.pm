package EPrints::Plugin::Convert::AddCoversheet;

=pod

=head1 NAME

EPrints::Plugin::Convert::AddCoversheet - Prepend front and back coversheet sheets

=cut

use strict;
use warnings;
use encoding 'utf-8';

use Carp;
use Thread qw/async/;
use OpenOffice::OODoc;
use File::Copy;
use Cwd;
use Encode qw(encode);

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
pdf application/pdf
);

# formats pref maps mime type to file suffix. Last suffix
# in the list is used.
for(my $i = 0; $i < @ORDERED; $i+=2)
{
         $FORMATS_PREF{$ORDERED[$i+1]} = $ORDERED[$i];
}

our $EXTENSIONS_RE = join '|', keys %FORMATS;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Coversheet Pages";
	$self->{visible} = "all";


#Future development - these functions should really be receiving the document.  We currently have no way to get document metadata.
	$self->{tags} = 
	{
		'citation'      =>  sub { my ($eprint) = @_; return EPrints::Utils::tree_to_utf8($eprint->render_citation); },
		'creators'      =>  sub { my ($eprint) = @_; return EPrints::Utils::tree_to_utf8($eprint->render_value('creators_name')); },
		'title' 	=>  sub { my ($eprint) = @_; return EPrints::Utils::tree_to_utf8($eprint->render_value('title')); },
		'url' 		=>  sub { my ($eprint) = @_; return $eprint->get_url; },
		'official_url'  =>  sub {
			my ($eprint) = @_;
			my $r = '';
			if ($eprint->is_set('official_url'))
			{
				$r = 'Published version at: ' . $eprint->get_value('official_url');
			}
			return $r;
		},
		'publisher'  =>  sub {
			my ($eprint) = @_;
			my $r = '';
			if ($eprint->is_set('publisher'))
			{
				$r = 'Publisher: ' . EPrints::Utils::tree_to_utf8($eprint->render_value('publisher'));
			}
			return $r;
		},
		'publisher_statement'  =>  sub {
			my ($eprint) = @_;
			my $r = '';
			if ($eprint->is_set('publisher_statement'))
			{
				$r = 'Publisher: ' . EPrints::Utils::tree_to_utf8($eprint->render_value('publisher_statement'));
			}
			return $r;
		},
	};

	return $self;
}

sub can_convert
{
	my ( $plugin, $doc ) = @_;

	# need pdflatex and python
	return unless $plugin->get_repository->can_execute( "pdftk" );
	return unless $plugin->get_repository->can_execute( "python" );
	return unless -e $plugin->get_repository->get_conf( "odt_converter_exe");

        my %types;

        # Get the main file name
        my $fn = $doc->get_main() or return ();
        
        if( $fn =~ /\.($EXTENSIONS_RE)$/oi )
        {
        	$types{"coverpage"} = { plugin => $plugin, };
        }
        
	return %types;
}

sub prepare_pages
{
	my ($self, $doc, $pages) = @_;

	my $eprint = $doc->get_eprint;
	my $temp_dir = EPrints::TempDir->new( "coversheetsXXXX" ); #, UNLINK => 1 );

	my $session = $self->{session};

	foreach my $coversheet_page (keys %{$pages})
	{
		my $filetype = $pages->{$coversheet_page}->{type};
		my $file_path = $pages->{$coversheet_page}->{path};

		next if $filetype eq 'none';

		if ($filetype eq 'odt')
		{
			if ($self->oo_is_running())
			{
				copy($file_path, $temp_dir . "/$coversheet_page.odt");
				EPrints::Utils::chown_for_eprints( $temp_dir . "/$coversheet_page.odt" );

				my $doc = odfDocument(file => $temp_dir . "/$coversheet_page.odt");

				foreach (keys %{$self->{tags}})
				{
					my @list = $doc->selectElementsByContent( '##'.$_.'##',  &{$self->{tags}->{$_}}($eprint) );
				}
				my $cwd = getcwd; #a quirk of $doc->save is that it saves a temp file to the working directory.
				chdir $temp_dir;
				$doc->save();
				chdir $cwd;
				#end of search and replace

				#convert to pdf
				system(
						$session->get_repository->get_conf('executables', 'python'),
						$session->get_repository->get_conf('odt_converter_exe'),
						$temp_dir . "/$coversheet_page.odt",
						$temp_dir . "/$coversheet_page.pdf",
				      );

				#end of convert to pdf
				unlink $temp_dir . "/$coversheet_page.odt";
			}
			if (not -e $temp_dir . "/$coversheet_page.pdf")
			{
				$session->get_repository->log("Can't Convert OpenOffice document for coversheet\n");
			}
		}
		elsif ($filetype eq 'pdf')
		{
			copy($file_path, $temp_dir . "/$coversheet_page.pdf");
		}
		else
		{
			$session->get_repository->log("Cannot handle coversheet pages of type $filetype\n");
		}
	}

	return $temp_dir;
}

sub export
{
	my ( $plugin, $target_dir, $doc, $pages ) = @_;

	# need pdflatex and python
	return unless $plugin->get_repository->can_execute( "pdftk" );
	my $pdftk = $plugin->get_repository->get_conf( "executables", "pdftk" );

#where should this go (OO may not be used)
	return unless $plugin->get_repository->can_execute( "python" );
	return unless -e $plugin->get_repository->get_conf( "odt_converter_exe");

	my $repository = $plugin->get_repository;

	my $temp_dir = $plugin->prepare_pages($doc, $pages);

	my $frontfile_path = $temp_dir . '/frontfile.pdf';
	my $backfile_path = $temp_dir . '/backfile.pdf';

	if (
		($pages->{frontfile}->{path} and not -e $frontfile_path) or
		($pages->{backfile}->{path} and not -e $backfile_path)
	)
        {
                $repository->log( "[CoverPDF] Unexpected absense of coversheet files." );
                return;
        }

        unless( -d $target_dir )
        {
                EPrints::Platform::mkdir( $target_dir);
        }

	my $output_file = EPrints::Utils::join_path( $target_dir, $doc->get_main );
	if( -e $output_file )
	{
		# remove old covered file
		unlink( $output_file );
	}

	my $doc_path = $doc->local_path."/".$doc->get_main;


	my @input_files;
	push @input_files, $frontfile_path if -e $frontfile_path;
	push @input_files, $doc_path;
	push @input_files, $backfile_path if -e $backfile_path;

	my $temp_output_dir = EPrints::TempDir->new( "finishedXXXX", UNLINK => 1 );
	my $temp_output_file = $temp_dir . '/' . 'temp.pdf';

	system( $pdftk, @input_files, "cat", "output", $temp_output_file );
	copy($temp_output_file, $output_file);

	# check it worked
        unless( -e $output_file and -s $output_file ) #check files exists and is not zero length
        {
                $repository->log("[CoverPDF] pdftk could not create $output_file. Check the PDF is not password-protected.");
                return;
        }

	EPrints::Utils::chown_for_eprints( $output_file );
        return ($output_file);
}


#will check to see if openoffice is running.
#if it isn't, it'll try to start it.
sub oo_is_running
{
	my ($self) = @_;
	my $session = $self->{session};

        my $office_name = $session->get_repository()->get_conf("open_office_name");

        my $office_service = `ps -e |grep $office_name `;

        if(!$office_service){
                print STDERR "no open office service found, starting open office\n";

                my $office_bin = $session->get_repository->get_conf('open_office_exe');

#one of the below may work, but make sure only one line is uncommented (the async method may cause a segfault)
#		my $thread = async { `$office_bin "-accept=socket,host=localhost,port=8100;urp;StarOffice.ServiceManager" -norestore -nofirststartwizard -nologo -headless &`;};
		system($office_bin.' "-accept=socket,host=localhost,port=8100;urp;StarOffice.ServiceManager" -norestore -nofirststartwizard -nologo -headless &');

                print STDERR "$! \n Sleeping, back in 6 seconds...\n";
                sleep(6);

                if( `ps -e |grep $office_name ` ){
                        print STDERR "Open Office started successfully\n";
                }else{
                        print STDERR "Open Office failed to start. Exiting...\n";
                        return 0;
                }
        }
        return 1;
}

1;
