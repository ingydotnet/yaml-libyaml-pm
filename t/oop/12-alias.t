use strict;
use warnings;
use Test::More;
use YAML::XS;
use Data::Dumper;

my $xs = YAML::XS->new;

my $yaml = <<'EOM';
- &SCALAR foo
- &SEQ [bar]
- &MAP
  key: val

- *SCALAR
- *SEQ
- *MAP
EOM
my $data = $xs->load_string($yaml);

my @exp = (
    (foo => ['bar'], { key => 'val' }) x 2
);
is_deeply $data, \@exp, 'load_string';
is $data->[0], $data->[3], 'scalar alias loaded correctly';
is $data->[1], $data->[4], 'sequence alias loaded correctly';
is $data->[2], $data->[5], 'mapping alias loaded correctly';

$yaml = $xs->dump_string($data);

my $exp = <<'EOM';
---
- foo
- &1
  - bar
- &2
  key: val
- foo
- *1
- *2
EOM
is $yaml, $exp, 'aliases are dumped correctly';

my $circle = [ 'x' ];
$circle->[1] = $circle;

$yaml = $xs->dump_string($circle);
$exp = <<'EOM';
--- &1
- x
- *1
EOM
is $yaml, $exp, 'circular refs are dumped correctly';

$yaml = <<'EOM';
- &NULL null
- &TRUE true
- &FALSE FALSE
- &INT 23
- &FLOAT 3.14
- &INF -.inf
- &NAN .nan

- *NULL
- *TRUE
- *FALSE
- *INT
- *FLOAT
- *INF
- *NAN
EOM

$data = $xs->load_string($yaml);
$yaml = $xs->dump_string($data);
$exp = <<'EOM';
---
- null
- true
- false
- 23
- 3.14
- -.inf
- .nan
- null
- true
- false
- 23
- 3.14
- -.inf
- .nan
EOM
is $yaml, $exp, 'aliases for different types';

$yaml = <<'EOM';
*alias
EOM

eval {
    my $xs = YAML::XS->new;
    $data = $xs->load_string($yaml);
};
my $err = $@;
like $err, qr{No anchor for alias .alias.}, "error for missing anchor";

done_testing;
