use strict;
use warnings;
use Test::More;
use YAML::XS;
use Data::Dumper;


my ($yaml, $data, @data);

subtest indent => sub {
    my $xs = YAML::XS->new( indent => 8 );
    $data = {
        this => {
            is => [ object => ori => "ented" ],
        },
    };

    $yaml = $xs->dump_string($data);

    my $exp = <<'EOM';
---
this:
        is:
        - object
        - ori
        - ented
EOM

    is $yaml, $exp, 'dump_string';
};

subtest header => sub {
    $data = { key => 'value' };

    my $xs = YAML::XS->new( header => 0 );
    $yaml = $xs->dump_string($data);
    my $exp = <<'EOM';
key: value
EOM
    is $yaml, $exp, 'header 0';

    $xs = YAML::XS->new( header => 1 );
    $yaml = $xs->dump_string($data);
    $exp = <<'EOM';
---
key: value
EOM
    is $yaml, $exp, 'header 1';

    $xs = YAML::XS->new;
    $yaml = $xs->dump_string($data);
    $exp = <<'EOM';
---
key: value
EOM
    is $yaml, $exp, 'header default';
};

subtest footer => sub {
    $data = { key => 'value' };

    my $xs = YAML::XS->new( footer => 0 );
    $yaml = $xs->dump_string($data);
    my $exp = <<'EOM';
---
key: value
EOM
    is $yaml, $exp, 'footer 0';

    $xs = YAML::XS->new( footer => 1 );
    $yaml = $xs->dump_string($data);
    $exp = <<'EOM';
---
key: value
...
EOM
    is $yaml, $exp, 'footer 1';

    $xs = YAML::XS->new;
    $yaml = $xs->dump_string($data);
    $exp = <<'EOM';
---
key: value
EOM
    is $yaml, $exp, 'footer default';
};

subtest require_footer => sub {
    my $yaml = <<'EOM';
---
key: value
---
x: y
...
EOM
    my $yaml2 = <<'EOM';
---
key: value
...
---
x: y
...
EOM

    my $xs = YAML::XS->new( require_footer => 1 );
    local $@;
    $data = eval { $xs->load_string($yaml) };
    like $@, qr{load: Document .1. did not end with '...'}, 'require_footer 1 failure';

    local $@;
    $data = eval { $xs->load_string($yaml2) };
    ok !$@, 'require_footer 1 success';

    local $@;
    $data = eval { $xs->load_string('') };
    like $@, qr{load: Document .0. did not end with '...'}, 'require_footer 1 empty doc failure';

    $xs = YAML::XS->new( require_footer => 0 );
    local $@;
    $data = eval { $xs->load_string($yaml) };
    ok !$@, 'require_footer 0';
};

subtest anchor_prefix => sub {
    my $xs = YAML::XS->new( anchor_prefix => 'a_' );
    my $ref = ['yaml rocks'];
    my $ref2 = ['another ref'];
    my $yaml = $xs->dump_string([$ref, $ref, $ref2, $ref2]);
    my $exp = <<'EOM';
---
- &a_1
  - yaml rocks
- *a_1
- &a_2
  - another ref
- *a_2
EOM
    is $yaml, $exp, 'anchor_prefix';
};

done_testing;
