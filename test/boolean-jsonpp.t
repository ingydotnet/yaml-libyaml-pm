use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests;

local $YAML::XS::Booleans = 1;

my $yaml = <<'...';
---
boolfalse: false
booltrue: true
stringfalse: 'false'
...


my $hash = eval { Load $yaml };
if ($@ and $@ =~ m{JSON/PP}) {
    plan skip_all => "JSON::PP not installed";
    exit;
}

plan tests => 5;

isa_ok($hash->{booltrue}, 'JSON::PP::Boolean',
    "boolean true loads as JSON::PP::Boolean");
cmp_ok($hash->{booltrue}, '==', 1, "boolean true is true");

isa_ok($hash->{boolfalse}, 'JSON::PP::Boolean',
    "boolean false loads as JSON::PP::Boolean");
cmp_ok($hash->{boolfalse}, '==', 0, "boolean false is false");

my $yaml2 = Dump($hash);
cmp_ok($yaml2, 'eq', $yaml, "Roundtrip booleans ok");

