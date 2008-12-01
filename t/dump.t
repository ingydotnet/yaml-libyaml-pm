use t::TestYAMLTests tests => 4;

spec_file('t/data/basic.t');
filters {
    perl => ['eval', 'test_dump'],
};

run_is perl => 'libyaml_emit';

sub test_dump {
    Dump(@_) || "Dump failed";
}

