use strict;
use warnings;
use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests tests => 22;
use B ();

my $yaml = <<"EOM";
- !!str
- !!str ~
- !!str null
- !!str 23
- !!str true
- !!str false
EOM

my @expected = ('', '~', 'null', "23", 'true', 'false');
my $data = Load $yaml;

ok(defined $data->[0], "Empty node with !!str is defined");
ok(defined $data->[1], "Node '!!str ~' is defined");
ok(defined $data->[2], "Node '!!str null' is defined");

for my $i (0 .. $#expected) {
    cmp_ok($data->[$i], 'eq', $expected[$i], "data[$i] equals '$expected[$i]'");
}

my @flags = map { B::svref_2object(\$_)->FLAGS } @$data;
for my $i (0 .. $#flags) {
    my $flags = $flags[$i];
    ok($flags & B::SVp_POK, "data[$i] has string flag");
    ok(not($flags & B::SVp_IOK), "data[$i] does not have int flag");
}

my $yaml2 = <<"EOM";
- !!map
  a: b
- !!seq
  - a
  - b
EOM

my $data2 = Load $yaml2;
my $exp = [
    { a => 'b' },
    [ 'a', 'b' ],
];
is_deeply($data2, $exp, "Standard tags !!map and !!seq work");
