use t::TestYAML tests => 5;

require YAML::XS;

my $entries = (int((($YAML::XS::VERSION + 0.001) * 100)) - 1);

open IN, "Changes" or die $!;
my $yaml = do {local $/; <IN>};
my @changes = YAML::XS::Load($yaml);

pass "Changes file Load-ed without errors";
ok @changes == $entries,
    "There are $entries Changes entries";
is $changes[0]->{version}, $YAML::XS::VERSION,
    "Changes file is up to date with current YAML::XS::VERSION";
is $changes[-1]->{date}, 'Fri May 11 14:08:54 PDT 2007',
    "Version 0.01 is from Fri May 11 14:08:54 PDT 2007";
is ref($changes[-3]->{changes}), 'ARRAY',
    "Version 0.03 has multiple changes listed";
