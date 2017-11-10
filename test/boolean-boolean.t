use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests;

local $YAML::XS::Boolean = "boolean";

my $yaml = <<'...';
---
boolfalse: false
booltrue: true
stringfalse: 'false'
stringtrue: 'true'
...


my $hash = eval { Load $yaml };

if ($@ and $@ =~ m{boolean}) {
    plan skip_all => "boolean not installed";
    exit;
}

plan tests => 7;

local $YAML::XS::Boolean = "boolean";
isa_ok($hash->{booltrue}, 'boolean');
isa_ok($hash->{boolfalse}, 'boolean');

cmp_ok($hash->{booltrue}, '==', 1, "boolean true is true");
cmp_ok($hash->{boolfalse}, '==', 0, "boolean false is false");

ok(! ref $hash->{stringtrue}, "string 'true' stays string");
ok(! ref $hash->{stringfalse}, "string 'false' stays string");

my $yaml2 = Dump($hash);
cmp_ok($yaml2, 'eq', $yaml, "Roundtrip booleans ok");

