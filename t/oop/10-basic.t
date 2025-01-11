use strict;
use warnings;
use Test::More;
use YAML::XS;
use Data::Dumper;

my $xs = YAML::XS->new;
#note __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$xs], ['xs']);

is ref $xs, 'YAML::XS', "got YAML::XS object";

my $yaml = <<'EOM';
- foo
- [bar]
- key: val
---
foo: bar
EOM


my @exp = (
    foo => ['bar'], { key => 'val' }
);
my $data = $xs->load_string($yaml);
is_deeply $data, \@exp, 'load_string scalar context';


my @data = $xs->load_string($yaml);
is_deeply $data[0], \@exp, 'load_string list context, first document';
is_deeply $data[1], { foo => 'bar' }, 'load_string list context, second document';
#note __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@data], ['data']);


@data = $xs->load_string('foo: bar');
is_deeply $data[0], { foo => 'bar' }, 'repeated load_string';

$data = {
    this => {
        is => [ object => ori => "ented" ],
    },
};
$yaml = $xs->dump_string($data);

#note $yaml;

my $exp = <<'EOM';
---
this:
  is:
  - object
  - ori
  - ented
EOM

is $yaml, $exp, 'dump_string';

@data = ({ doc => 1 }, { doc => 2 });
$yaml = $xs->dump_string(@data);
#note $yaml;
$exp = <<'EOM';
---
doc: 1
---
doc: 2
EOM
is $yaml, $exp, 'dump multiple documents';

done_testing;
