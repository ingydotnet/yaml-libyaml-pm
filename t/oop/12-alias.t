use strict;
use warnings;
use Test::More;
use YAML::XS;

my $xs = YAML::XS->new;

subtest cyclic => sub {
    my $xs_with_cyclic = YAML::XS->new(cyclic_refs => 1);
    subtest sequence => sub {
        my $yaml = <<'EOM';
&CIRCLE [ something else, *CIRCLE ]
EOM

        my $circle = eval {
            $xs->load($yaml);
        };
        my $err = $@;
        like $err, qr{No anchor for alias 'CIRCLE'}, 'expected error message';

        $circle = eval {
            $xs_with_cyclic->load($yaml);
        };
        $err = $@;
        is $err, '', 'no error with cyclic_refs on';
        is $circle->[0], 'something else', 'first element like expected';
        is "$circle->[1]", "$circle", 'second element points to root element';

        $yaml = $xs->dump($circle);
        my $exp = <<'EOM';
--- &1
- something else
- *1
EOM
        is $yaml, $exp, 'circular refs are dumped correctly';
    };

    subtest mapping => sub {
        my $yaml = <<'EOM';
&CIRCLE { something_else: *CIRCLE }
EOM

        my $circle = eval {
            $xs->load($yaml);
        };
        my $err = $@;
        like $err, qr{No anchor for alias 'CIRCLE'}, 'expected error message';

        $circle = eval {
            $xs_with_cyclic->load($yaml);
        };
        $err = $@;
        is $err, '', 'no error with cyclic_refs on';
        is "$circle->{something_else}", "$circle", 'hash value points to root element';

        $yaml = $xs->dump($circle);
        my $exp = <<'EOM';
--- &1
something_else: *1
EOM
        is $yaml, $exp, 'circular refs are dumped correctly';
    };
 };

my $yaml = <<'EOM';
- &SCALAR foo
- &SEQ [bar]
- &MAP
  key: val

- *SCALAR
- *SEQ
- *MAP
EOM
my $data = $xs->load($yaml);

my @exp = (
    (foo => ['bar'], { key => 'val' }) x 2
);
is_deeply $data, \@exp, 'load';
is $data->[0], $data->[3], 'scalar alias loaded correctly';
is $data->[1], $data->[4], 'sequence alias loaded correctly';
is $data->[2], $data->[5], 'mapping alias loaded correctly';

$yaml = $xs->dump($data);

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

$data = $xs->load($yaml);
$yaml = $xs->dump($data);
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
    $data = $xs->load($yaml);
};
my $err = $@;
like $err, qr{No anchor for alias .alias.}, "error for missing anchor";

done_testing;
