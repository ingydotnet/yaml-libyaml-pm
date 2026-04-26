use strict;
use warnings;
use Test::More;
use YAML::XS;
use Test::Warnings qw/ warning /;

subtest 'null key' => sub {
    my $xs = YAML::XS->new;
    my $yaml = <<'EOM';
null: value
EOM
    my $data;
    my $warning = warning { $data = $xs->load($yaml) };
    is_deeply $data, { '' => 'value' }, 'null key loaded as empty string';
    is_deeply $warning, [], 'automatic conversion without warning';
};

done_testing;
