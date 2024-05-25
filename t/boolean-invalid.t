use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests;

my @disable = (['int 0', 0], ['string 0', '0'], ['empty string', ''], ['undef', undef]);
my @invalid = (['int 1', 1], ['string 1', '1'], ['string foo', 'foo']);
my $tests = (@disable + 2 * @invalid);
plan tests => $tests;

for (@invalid) {
    my ($label, $test) = @$_;
    local $YAML::XS::Boolean = $test;

    my $data = eval { Load "dummy" };
#    $@ and diag "ERROR: $@";
    cmp_ok($@, '=~', qr{accepts}, "YAML::XS::Load: $label is an invalid setting");

    my $yaml = eval { Dump { foo => 42 } };
#    $@ and diag "ERROR: $@";
    cmp_ok($@, '=~', qr{accepts}, "YAML::XS::Dump: $label is an invalid setting");
}

for (@disable) {
    my ($label, $test) = @$_;
    local $YAML::XS::Boolean = $test;

    my $data = eval { Load "true" };
    if ($@) {
        diag "ERROR: $@";
        ok(0, "$label disables YAML::XS::Boolean");
    }
    else {
        my $ref = ref $data;
        cmp_ok($ref, 'eq', '', "$label disables YAML::XS::Boolean");
    }
}
