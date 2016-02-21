use strict;
use warnings;
use Data::Dumper;

use t::TestYAML tests => 2;
use YAML::XS qw/ DumpFile LoadFile /;

use Path::Class;

my $data = {
    foo => "boo",
};
my $file = file("t", "path-class-$$.yaml");
DumpFile($file, $data);
ok -f $file, "Path::Class $file exists";

my $data2 = LoadFile($file);
is_deeply($data, $data2, "Path::Class roundtrip works");

END {
    unlink $file;
}
