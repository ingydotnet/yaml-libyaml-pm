use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests;

plan tests => 3;

my $yaml = <<'...';
key: value
key: another value
...

my $hash = Load $yaml;
is_deeply $hash, { key => 'another value' }, 'Allow duplicate keys (default)';

$YAML::XS::ForbidDuplicateKeys = 0;
$hash = Load $yaml;
is_deeply $hash, { key => 'another value' }, 'Allow duplicate keys explicitly';

$YAML::XS::ForbidDuplicateKeys = 1;
$hash = eval { Load $yaml };
my $err = $@;
like $err, qr{Duplicate key 'key'}, 'Forbid duplicate keys';
