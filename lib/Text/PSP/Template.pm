package Text::PSP::Template;
use strict;
use Carp qw(croak);

sub new {
	my ($class,%args) = @_;
	return bless { _engine => $args{engine}, _filename => $args{filename} },$class;
}

sub run {
	croak "Abstract method Text::PSP::Template::run called!";
}

sub include {
	my ($self,$file,@args) = @_;
	my $dir = $self->{_filename};
	$dir =~ s/[^\/]+$//;
	my $template = $self->{_engine}->template("$dir/$file");
	return @{$template->run(@args)};
}

1;

