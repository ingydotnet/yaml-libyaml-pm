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

done_testing;
