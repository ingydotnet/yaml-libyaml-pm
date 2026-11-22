use strict;
use warnings;
use YAML::XS;
use Test::More;

# resulted in a coredump most of the times up to version v0.910.0:
# double free or corruption (!prev)
# IOT instruction (core dumped)
# https://github.com/ingydotnet/yaml-libyaml-pm/issues/135

my $xs = YAML::XS->new;
my $yaml = <<'EOM';
const: { x: 4, y: 5 }
enum:
  - [ { x: 4, y: 5 }, { x: 4, y: 5 } ]
  - { x: 4, y: 5 }
EOM

subtest issue135 => sub {
    my $data = $xs->load($yaml);
    is $data->{enum}->[0]->[0]->{x}, 4;
};

done_testing;
