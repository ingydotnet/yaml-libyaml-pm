use t::TestYAMLTests tests => 5;

spec_file('t/data/basic.t');
filters {
    yaml => ['parse_to_byte'],
    perl => ['eval'],
};

run_is_deeply yaml => 'perl';

sub parse_to_byte {
    Load($_);
}
