use strict;
use warnings;
use Test::More;
use YAML::XS ();
use B;
use Devel::Peek;
use Data::Dumper;
use FindBin '$Bin';
my $schema_file = "$Bin/schema-core.yaml";

my $xs = YAML::XS->new(header => 0);

my $core = YAML::XS::LoadFile($schema_file);

my $inf = 0 + 'inf';
my $inf_negative = 0 - 'inf';
my $nan = 0 + 'nan';
diag("inf: $inf -inf: $inf_negative nan: $nan");
my $inf_broken = $inf eq '0';
$inf_broken and diag("inf/nan seem broken, skipping those tests");
my $is_bool = eval 'use experimental qw/ builtin /; sub { builtin::is_bool($_[0]) }';
if ($] < 5.036000) {
    $is_bool = sub { 1 };
}
my %check = (
    null => sub { not defined $_[0] },
    inf => sub {
        my ($float) = @_;
        return $float eq $inf;
    },
    'inf-neg' => sub {
        my ($float) = @_;
        return $float eq $inf_negative;
    },
    nan => sub {
        my ($float) = @_;
        return $float eq $nan;
    },
    true => sub {
        my ($bool) = @_;
        return ($bool eq 1 and $is_bool->($bool));
    },
    false => sub {
        my ($bool) = @_;
        return ($bool eq '' and $is_bool->($bool));
    },
);

my @k = sort keys %$core;
#@k = @k[0..280];
for my $input (@k) {
    my $test_data = $core->{ $input };
    my $yaml = "---\n$input\n";
    my $data = eval { $xs->load($yaml) };
    my $error = $@;
    if ($test_data eq 'error') {
        like $error, qr{Invalid tag .* for value}, "load($input) error";
        next;
    }
    my ($type, $check, $dump) = @$test_data;
    my $data_copy = $data; # avoid stringifying original data
#    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$data_copy], ['data_copy']);
#    Dump $data_copy;
    my $flags = B::svref_2object(\$data)->FLAGS;
    my $is_str = $flags & B::SVp_POK;
    my $is_int = $flags & B::SVp_IOK;
    my $is_float = $flags & B::SVp_NOK;

    my $func;

    my $label = sprintf "type %s: load(%s) -> '%s'", $type, $input, (defined $data ? $data : 'undef');
    if ($check =~ m/^([\w-]+)\(\)$/) {
        my $func_name = $1;
        $func = $check{ $func_name };
        my $ok = $func->($data);
        ok($ok, "$label - check $func_name() ok");
    }
    if ($type eq 'str') {
        ok($is_str, "$label is str");
        ok(! $is_int, "$label is not int");
        ok(! $is_float, "$label is not float");

        unless ($func) {
            cmp_ok($data, 'eq', $data, "$label eq '$data'");
        }
    }
    elsif ($type eq 'int') {
        ok($is_int, "$label is int");
        ok(!$is_str, "$label is not str");

        unless ($func) {
            cmp_ok($data, '==', $data, "$label == '$data'");
        }
    }
    elsif ($type eq 'float' or $type eq 'inf' or $type eq 'nan') {
        unless ($inf_broken) {
            ok($is_float, "$label is float");
            ok(!$is_str, "$label is not str");
        }

        unless ($func) {
            cmp_ok(sprintf("%.2f", $data), '==', $data, "$label == '$data'");
        }
    }
    elsif ($type eq 'bool' or $type eq 'null') {
    }
    else {
        ok(0, "unknown type $type");
    }

    unless ($inf_broken) {
        my $yaml_dump = $xs->dump($data);
        $yaml_dump =~ s/\n\z//;
        if ($input =~ m/\b(false|true)\b/i) {
            if ($] >= 5.036000) {
                cmp_ok($yaml_dump, 'eq', $dump, "$label-dump as expected");
            }
        }
        else {
            cmp_ok($yaml_dump, 'eq', $dump, "$label-dump as expected");
        }
    }
}

done_testing; exit;

my $yaml = <<'EOM';
- test
- true
- false
- null
- nums

- 5
- -5
- 0xa
- 0xb
- 0.0

- 3.141
- -5.40
- 0o7
- 0o10
- 56789012345678901234

- 5678901234
- 567890123
- .inf
- .nan
- .23
EOM

my $data = $xs->load($yaml);
note __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$data], ['data']);
#is scalar @$data, 7, 'expected number of elements';
pass "test";

is $data->[0], "test", "test 0";
is $data->[1], "1", "test 1";
is $data->[2], "", "test 2";
is $data->[3], undef, "test 3";
is $data->[4], "nums", "test 4";

is $data->[5], 5, "test 5";
is $data->[6], -5, "test 6";
is $data->[7], 10, "test 7";
is $data->[8], 11, "test 8";
is $data->[9], 0.0, "test 9";

is $data->[10], 3.141, "test 10";
is $data->[11], -5.4, "test 11";
is $data->[12], 7, "test 12";
is $data->[13], 8, "test 13";
is $data->[14], -1, "test 14";

is $data->[15], 5678901234, "test 15";
is $data->[16], 567890123, "test 16";
is $data->[17], "Inf", "test 17";
is $data->[18], "NaN", "test 18";
is $data->[19], .23, "test 19";

use Devel::Peek;
#diag $data->[10];
#Dump $data->[10];
#diag $data->[11];
#Dump $data->[11];
#my $x = "3.141";
#Dump $x;

#diag $data->[-3];
#Dump $data->[-3];
diag $data->[-2];
Dump $data->[-2];
diag $data->[-1];
Dump $data->[-1];

done_testing;

