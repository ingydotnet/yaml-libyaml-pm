use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests tests => 5;

#-------------------------------------------------------------------------------
my $sub = sub { return "Hi.\n" };

my $yaml = <<'...';
--- !!perl/code '{ "DUMMY" }'
...

is Dump($sub), $yaml,
    "Dumping a code ref works produces DUMMY";

#-------------------------------------------------------------------------------
$sub = sub { return "Bye.\n" };
bless $sub, "Barry::White";

$yaml = <<'...';
--- !!perl/code:Barry::White |-
  {
      use warnings;
      use strict;
      return "Bye.\n";
  }
...

use B::Deparse;
if (new B::Deparse -> coderef2text ( sub { no strict; 1; use strict; 1; })
      =~ 'refs') {
    $yaml =~ s/use strict/use strict 'refs'/g;
}

$YAML::XS::DumpCode = 1;
is Dump($sub), $yaml,
    "Dumping a blessed code ref works (with B::Deparse)";

#-------------------------------------------------------------------------------
$sub = sub { return "Bye.\n" };
bless $sub, "Barry::White";

$yaml = <<'...';
--- !!perl/code:Barry::White '{ "DUMMY" }'
...

$YAML::XS::DumpCode = 0;
is Dump($sub), $yaml,
    "Dumping a blessed code ref works (with DUMMY again)";

$yaml = <<'...';
--- !!perl/code:Barry::White |-
  {
      use warnings;
      use strict;
      return "Bye.\n";
  }
...

$YAML::XS::LoadCode = 0;

$sub = Load($yaml);
my $return = $sub->();
is($return, undef, "Loaded dummy coderef");

$YAML::XS::LoadCode = 1;

$sub = Load($yaml);
$return = $sub->();
cmp_ok($return, 'eq', "Bye.\n", "Loaded coderef");
