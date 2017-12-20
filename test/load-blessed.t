use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests tests => 6;

my $yaml = <<"EOM";
local: !Foo::Bar [a]
perl: !!perl/hash:Foo::Bar { a: 1 }
regex: !!perl/regexp:Foo::Bar OK
EOM

my $objects = Load $yaml;
isa_ok($objects->{local}, "Foo::Bar", "local tag (array)");
isa_ok($objects->{perl}, "Foo::Bar", "perl tag (hash)");
isa_ok($objects->{regex}, "Foo::Bar", "perl tag (regexp)");

local $YAML::XS::LoadBlessed = 0;
my $hash = Load $yaml;
cmp_ok(ref $hash->{local}, 'eq', 'ARRAY', "Array not blessed");
cmp_ok(ref $hash->{perl}, 'eq', 'HASH', "Hash not blessed");
cmp_ok(ref $hash->{regex}, 'eq', 'Regexp', "Regexp not blessed");
