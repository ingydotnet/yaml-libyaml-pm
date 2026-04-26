use strict;
use warnings;
use Test::More;
use YAML::XS;

my $xs = YAML::XS->new;
my $yaml = <<'EOM';
defaults: &defaults
  A: defaultA
  B: defaultB
map:
  <<: *defaults
  B: newB
EOM
diag "#############################";
my $data = $xs->load($yaml);
diag "#############################";
use Data::Dumper;
warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$data], ['data']);

pass "ok";

done_testing;
