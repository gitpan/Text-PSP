package Text::PSP::Parser;
use Carp qw(croak);
use strict;

sub new {
	my ($class,$engine) = @_;
	ref $engine or die "No engine specified";
	return bless {
		engine => $engine,
	},$class ;
}

sub clone {
	my ($self) = @_;
	return bless {
		engine => $self->{engine},
	},ref $self;
}
	

sub parse_template {
	my $self = shift;
	%$self = 
	(
		%$self,
		@_,
	);
	$self->{head} = ['package ',$self->{classname},';
use strict;
use Text::PSP::Template;
use vars qw(@ISA);
@ISA = qw(Text::PSP::Template);

# this file was generated by ',ref($self),'
'];
	unless (defined $self->{directory}) {
		my $directory = $self->{filename};
		$directory =~ s/[^\/]+$//;
		$self->{directory} = $directory;
	}
	$self->{out} = ["\n#line 1 $self->{engine}->{template_root}/$self->{filename}\n"];
	$self->{define} = [];
	$self->{pushing} = 0;
	$self->{in_quotes} = 0;
	local $_  = readline $self->{input};
	if ($self->text) {
		return $self->{head},$self->{define},$self->{out};
	}
	die "Parse error; unexpected end of file at $self->{filename} line $..\n";
}

sub text {
	my ($self) = @_;
	my @text;
	my ($switch);
	FIND_TAG:
	while (defined $_) {
		if (s/^((.*?)<(%[!=@|]?))//s) {
			$switch = $3;			# before they go out of scope
			push @text,$2 if defined $2 and $2 ne '';
			last FIND_TAG;
		}
		push @text,$_;
		$_ = readline $self->{input};
	}
	if (@text) {
		push @{$self->{out}},'push @o' unless $self->{pushing};
		$self->{pushing} = 1;
		push @{$self->{out}},",'" unless $self->{in_quotes};
		$self->{in_quotes} = 1;
		push @{$self->{out}},map { s#\\#\\\\#g; s#'#\\'#g; $_ } @text;
	}
	unless (defined $_) {
		push @{$self->{out}},"'" if $self->{in_quotes};
		push @{$self->{out}},";" if $self->{pushing};
		return 1;
	}

	die "Parse error at $self->{engine}->{template_root}/$self->{filename} line $..\n" unless defined $switch;

	if ($switch eq '%=') {
		push @{$self->{out}},"'" if $self->{in_quotes};
		$self->{in_quotes} = 0;
		push @{$self->{out}},'push @o' unless $self->{pushing};
		$self->{pushing} = 1;
		push @{$self->{out}},',',$self->get_block;
		goto &text;
	}
	if ( $switch eq '%|' ) {
		push @{$self->{out}},"'" unless $self->{in_quotes};
		push @{$self->{out}},'push @o' unless $self->{pushing};
		$self->{pusing} =1;
		$self->{in_quotes} = 1;
		goto &runnow;
	}
	
	elsif ($switch eq '%!') {
		goto &define;
	}
	elsif ($switch eq '%@') {
		goto &directive;
	}
	push @{$self->{out}},"'" if $self->{in_quotes};
	push @{$self->{out}},';' if $self->{pushing};
	$self->{pushing} = 0;
	$self->{in_quotes} = 0;
	goto &code if $switch eq '%';
die "Parse error: unrecognized switch at $self->{engine}->{template_root}/$self->{filename} line $..\n";
}

sub get_block {
	my ($self) = @_;
	my $block;
	while (1) {
		my $pos = index $_,'%>';
		if ($pos == -1) {
			$block .= $_;
			defined ($_ = readline $self->{input}) or die "End of file in code-block at $self->{engine}->{template_root}/$self->{filename} line $..\n";
 			next;
		}
		$block .= substr($_,0,$pos,'');
		substr($_,0,2,'');
		return $block;
	}

}

sub set_line {
	my $self = shift;
	if ($self->{'pushing'}) {
		push @{$self->{out}},";";
		$self->{'pushing'} = 0;
	}
	push @{$self->{out}},"\n#line $. $self->{engine}->{template_root}/$self->{filename}\n";
}


sub define {
	my ($self) = @_;
	push @{$self->{define}},"\n#line $. $self->{engine}->{template_root}/$self->{filename}\n",$self->get_block;
	goto &text;
}

sub code {
	my ($self) = @_;
	push @{$self->{out}},$self->get_block;
	goto &text;
}

sub directive {
	my ($self) = @_;
	my $directive = $self->get_block;
	if ($directive =~ s/^\s*(\w+)\s+//s) {
		my $name = $1;
		my @args;
		while ($directive =~ s/(\w+)(?:=\"([^\"]+)\")\s*//s) {
			push @args,$1,defined $2 ? $2 : $1;
		}
	my $call = "directive_$name";
		$self->$call(@args);
		goto &text;
	}
	die "Directives are not yet supported at $self->{engine}->{template_root}/$self->{filename} line $..\n";
}

sub runnow {
	my ($self) = @_;
	my $runnow;
	my $beginline = $. -1;
	my @out = eval $self->get_block;
	my $error = $@;
	if ($error) {
		$error =~ s/at.*?line\s+(\d+).*$//s;
		die "$error in compile-time code block at $self->{engine}->{template_root}/$self->{filename} line ".($beginline+$1)."\n";
	}
	push @{$self->{out}}, map { s#\\#\\\\#g; s#'#\\'#g; $_ } @out;
	goto &text;
}

sub static_include {
	my ($self,$filename,$directory) = @_;
	local *INPUT;
	open INPUT,"< $self->{engine}->{template_root}/$filename" or die "Cannot open $self->{engine}->{template_root}/$filename at $self->{filename} line $..\n";
	my $parser = $self->clone;
	my @directory_option = ();
	@directory_option = ( directory => $directory ) if defined $directory;
	my ($dummy,$define,$out) = $parser->parse_template(input => \*INPUT, filename => $filename, classname => 'dummy', @directory_option);
	push @{$self->{out}},"'" if $self->{in_quotes};
	push @{$self->{out}},';' if $self->{pushing};
	$self->{pushing} = 0;
	$self->{in_quotes} = 0;
	push @{$self->{out}},@$out;
	push @{$self->{define}},@$define;
	$self->set_line;
}

sub directive_include {
	my ($self,%args) = @_;
	die "No file argument for include directive at $self->{engine}->{template_root}/$self->{filename} line $..\n" unless defined $args{file};
#	warn "including $self->{directory}/$args{file}\n";
	my $new_filename = $self->{engine}->normalize_path("$self->{directory}/$args{file}");
#	warn "that's $new_filename now\n";
	$self->static_include($new_filename);
}

sub directive_find {
	my ($self,%args) = @_;
	die "No file argument for find directive at $self->{engine}->{template_root}/$self->{filename} line $..\n" unless defined $args{file};
	my $path = $self->{engine}->normalize_path("/$self->{directory}");
	my $filename = $args{file};
	my $found = 0;
	while (1) {
		$found = 1, last if -f "$self->{engine}->{template_root}$path/$filename";
		last if $path eq '';
		$path =~ s#/[^/]*$##;
		next;
	}
	die "File $args{file} not found at $self->{engine}->{template_root}/$self->{filename} line $..\n" unless $found;
	$self->static_include("$path/$filename",$self->{directory});
}

sub directive_path {
	my ($self,%args) = @_;
	die "No file argument for path directive at $self->{engine}->{template_root}/$self->{filename} line $..\n" unless defined $args{file};
	my $path = $self->{engine}->normalize_path("/$self->{directory}");
	my $filename = $args{file};
	my $found = 0;
	while (1) {
		$found = 1, last if -f "$self->{engine}->{template_root}$path/$filename";
		last if $path eq '';
		$path =~ s#/[^/]*$##;
		next;
	}
	die "File $args{file} not found at $self->{engine}->{template_root}/$self->{filename} line $..\n" unless $found;
	push @{$self->{out}},"'" if $self->{in_quotes};
	$self->{in_quotes} = 0;
	push @{$self->{out}},'push @o' unless $self->{pushing};
	$self->{pushing} = 1;
	push @{$self->{out}},',',$path;
}

	


1;

__END__

=head1 NAME

Text::PSP::Parser - JSP-like parser for Text::PSP

=head1 SYNOPSIS

No documentation for this mode yet, better see L<Text::PSP> and L<Text::PSP::Syntax>.

=head1 AUTHOR

Joost Diepenmaat, jdiepen@cpan.org

=head1 SEE ALSO

perl(1). L<Text::PSP>, L<Text::PSP::Syntax>

=cut


