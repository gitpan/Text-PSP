use Test::More tests => 3;
use File::Path qw(mkpath rmtree);

BEGIN { use_ok 'Text::PSP';  };

if (-d 'tmp/work') {
	rmtree 'tmp/work';
}

eval {
	my $engine = Text::PSP->new('template_root' => 't/templates','workdir' => 'tmp/work');
};
ok ($@ =~ /Workdir tmp\/work does not exist/,"workdir check");

mkpath 'tmp/work';

my $engine = Text::PSP->new('template_root' => 't/templates','workdir' => 'tmp/work');

is(ref $engine,"Text::PSP","engine instantiation");

