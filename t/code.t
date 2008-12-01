use t::TestYAMLTests tests => 3;

#-------------------------------------------------------------------------------
my $sub = sub { print "Hi.\n" };

my $yaml = <<'...';
--- !!perl/code '{ "DUMMY" }'
...

is Dump($sub), $yaml,
    "Dumping a code ref works produces DUMMY";

#-------------------------------------------------------------------------------
$sub = sub { print "Bye.\n" };
bless $sub, "Barry::White";

$yaml = <<'...';
--- !!perl/code:Barry::White |-
  {
      use warnings;
      use strict 'refs';
      print "Bye.\n";
  }
...

$YAML::XS::DumpCode = 1;
is Dump($sub), $yaml,
    "Dumping a blessed code ref works (with B::Deparse)";

#-------------------------------------------------------------------------------
$sub = sub { print "Bye.\n" };
bless $sub, "Barry::White";

$yaml = <<'...';
--- !!perl/code:Barry::White '{ "DUMMY" }'
...

$YAML::XS::DumpCode = 0;
is Dump($sub), $yaml,
    "Dumping a blessed code ref works (with DUMMY again)";

