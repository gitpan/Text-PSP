package Text::PSP;

use strict;
use vars qw($VERSION);

$VERSION = '1.010';

use Carp qw(croak carp);
use Symbol ();

sub new {
	my $class = shift;
	my $self = bless { 
		workdir => undef,
		remove_spaces => 0,
		template_root => undef,
		@_ 
	},$class;
	croak "No workdir given" unless defined $self->{workdir};
	croak "No template_root given" unless defined $self->{template_root};
	croak "Workdir $self->{workdir} does not exist" unless (-d $self->{workdir});
	return $self;
}

sub template {
	croak "Text::PSP template method takes 1+ argument" if @_ < 2;
	my ($self,$filename,%options) = @_;
	my ($pmfile,$classname) = $self->translate_filename($filename);
	if ( $options{force_rebuild} or ( !-f $pmfile ) or  -M _ > -M "$self->{template_root}/$filename" ) {
		Symbol::delete_package($classname);
		$self->write_pmfile($filename,$pmfile,$classname);
	}
	require $pmfile;
	return $classname->new( engine => $self, filename => $filename);
}

sub find_template {
	croak "Text::PSP find_template method takes 1+ argument" if @_ < 2;
	my ($self,$directory,%options) = @_;
	$directory =~ s#([^/]+)$## or croak "Cannot find a filename from $directory";
	my $filename = $1;
	$directory = $self->normalize_path($directory);
	my $path = $directory;
	my $found = 0;
	while (1) {
#		warn "testing $path/$filename";
		$found =1,last if -f $self->normalize_path("$self->{template_root}/$path/$filename");
		last if $path eq '';
		$path =~ s#/?[^/]+$##;
	}
	croak "Cannot find $filename from directory $directory" unless $found;
	my ($pmfile,$classname) = $self->translate_filename("$directory/$filename");
	if ( $options{force_rebuild} or ( !-f $pmfile ) or  -M _ > -M "$self->{template_root}/$path/$filename" ) {
		Symbol::delete_package($classname);
		$self->write_pmfile($filename,$pmfile,$classname,$directory);
	}
	require $pmfile;
	return $classname->new( engine => $self, filename => "$path/$filename");
}


sub translate_filename {
	my ($self,$filename) = @_;
	$filename = $self->normalize_path($filename);
	croak "Filename $filename outsite template_root" if $filename =~ /\.\./;
	my $classname = $self->normalize_path("$self->{template_root}/$filename");
	$classname =~ s#[^\w/]#_#g;
	$classname =~ s#^/#_ROOT_/#;
	my $pmfile = $classname;
	$classname =~ s#/#::#g;
	$classname = "Text::PSP::Generated::$classname";
	$pmfile = $self->normalize_path("$self->{workdir}/$pmfile.pm");
	return ($pmfile,$classname);
}

sub clear_workdir {
	my ($self) = shift;
	require File::Path;
	my $workdir = $self->{workdir};
	File::Path::rmtree( [ <$workdir/*> ],0);
}

sub write_pmfile {
	my ($self,$filename,$pmfile,$classname,$directory) = @_;
	open INFILE,"< $self->{template_root}/$filename" or croak "Cannot open template file $filename: $!";
	require Text::PSP::Parser;
	my $parser = Text::PSP::Parser->new($self);
	my @dir_opts;
	if (defined $directory) {
		@dir_opts = ( directory => $directory );
	}
	my ($head,$define,$out) = $parser->parse_template(input => \*INFILE, classname => $classname, filename => $filename, @dir_opts);
	close INFILE;
	my ($outpath) = $pmfile =~ m#(.*)/#;
	require File::Path;
	File::Path::mkpath([$outpath]);
	open OUTFILE,"> $pmfile" or die "Cannot open $pmfile for writing: $!";
	print OUTFILE @$head,@$define,'sub run { my @o;',"\n",@$out,"\n",'return \@o;}',"\n1\n";
	close OUTFILE;
}

sub normalize_path {
	my ($self,$inpath) = @_;
	my @inpath = split '/',$inpath;
	my $relative = (@inpath > 0 and $inpath[0] ne '') ? 1 : 0;
	my @outpath;
	for (@inpath) {
		next if $_ eq '';
		pop @outpath,next if $_ eq '..';
		push @outpath,$_;
	}
	my $outpath = join('/',@outpath);
	$outpath = "/$outpath" unless $relative;
	return $outpath;
}



1;


