use strict;
use warnings;
use Test::More;
use YAML::XS;
use Data::Dumper;

my $xs = YAML::XS->new;

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
my $data = $xs->load($yaml);
is_deeply $data, \@exp, 'load scalar context';


my @data = $xs->load($yaml);
is_deeply $data[0], \@exp, 'load list context, first document';
is_deeply $data[1], { foo => 'bar' }, 'load list context, second document';

@data = $xs->load('foo: bar');
is_deeply $data[0], { foo => 'bar' }, 'repeated load';

$data = {
    this => {
        is => [ object => ori => "ented" ],
    },
};
$yaml = $xs->dump($data);

my $exp = <<'EOM';
---
this:
  is:
  - object
  - ori
  - ented
EOM

is $yaml, $exp, 'dump';

@data = ({ doc => 1 }, { doc => 2 });
$yaml = $xs->dump(@data);

$exp = <<'EOM';
---
doc: 1
---
doc: 2
EOM
is $yaml, $exp, 'dump multiple documents';

subtest error => sub {
    my ($data, $err);
    my $reserved = "\n\@foo";
    $data = eval { $xs->load($reserved) };
    $err = $@;
    like $err, qr{found character that cannot start any token};
    like $err, qr{line: 2};

    $reserved = "\n- \@foo";
    $data = eval { $xs->load($reserved) };
    $err = $@;
    like $err, qr{found character that cannot start any token};
    like $err, qr{line: 2};

    my $yaml = "...";
    $data = eval { $xs->load($yaml) };
    $err = $@;
    like $err, qr{did not find expected node content};
    like $err, qr{line: 1};
};

done_testing;
