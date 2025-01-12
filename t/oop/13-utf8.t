use strict;
use warnings;
use Test::More;
use YAML::XS ();
use Data::Dumper;
use Devel::Peek;
use Encode;

my $xs = YAML::XS->new( indent => 8, utf8 => 0 );
my $xsu = YAML::XS->new( indent => 8, utf8 => 1 );

my $v = "_ö_";
my $vd = decode_utf8 $v;
my ($yaml, $data);
note "=================================================== YAML::XS utf8: 0";
$yaml = $vd;
$ENV{TEST_VERBOSE} and Dump $yaml;
$data = $xs->load_string($yaml);
$ENV{TEST_VERBOSE} and Dump $data;
is $data, $vd, "load_string utf8 => 0";

$yaml = $xs->dump_string($data);
is $yaml, "--- $vd\n", "dump_string utf8 => 0";;
$ENV{TEST_VERBOSE} and Dump $yaml;
note "---> $yaml";

note "=================================================== YAML::XS utf8: 1";
$yaml = "_ö_";
$ENV{TEST_VERBOSE} and Dump $yaml;
$data = $xsu->load_string($yaml);
$ENV{TEST_VERBOSE} and Dump $data;
is $data, $vd, "load_string utf8 => 1";

$yaml = $xsu->dump_string($data);
$ENV{TEST_VERBOSE} and Dump $yaml;
is $yaml, "--- $v\n", "dump_string utf8 => 1";;
note "---> $yaml";

{
    my ($json, $data);
    note "=================================================== YAML::XS Load/Dump";
    $data = YAML::XS::Load($v);
    $ENV{TEST_VERBOSE} and Dump $data;
    $yaml = YAML::XS::Dump($data);
    $ENV{TEST_VERBOSE} and Dump $yaml;

}
if (require JSON::PP) {
    my $j = JSON::PP->new;
    my $ju = JSON::PP->new->utf8;
    my ($json, $data);
    note "=================================================== JSON::PP utf8: 0";
    $json = decode_utf8 '["_ö_"]';
    $data = $j->decode($json);
    $ENV{TEST_VERBOSE} and Dump $data->[0];
    $json = $j->encode($data);
    $ENV{TEST_VERBOSE} and Dump $json;

    note "=================================================== JSON::PP utf8: 1";
    $json = '["_ö_"]';
    $data = $ju->decode($json);
    $ENV{TEST_VERBOSE} and Dump $data->[0];
    $json = $ju->encode($data);
    $ENV{TEST_VERBOSE} and Dump $json;
}

done_testing;
