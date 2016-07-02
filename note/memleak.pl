#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use YAML::XS qw/ Load /;

sub yaml {
    my ($str) = @_;

    eval {
        my $obj = Load($str);
    };
    if ($@) {
        say "EVAL_ERROR: $@\nfailed to convert YAML string: $str";
    }
}

my $str = do { local $/; <DATA> };

my $count = $ARGV[0] || 1000;
my $sleep = $ARGV[1] || 3;
for my $i (0 .. $count) {
    say "== Loop $i";
    select undef, undef, undef, 0.005;
    yaml($str);

    if ($i and not $i % 50) {
        say "Process size:";
        system("ps -o pid,vsz --pid $$");
        select undef, undef, undef, $sleep;
    }
}

__DATA__
---
foo: bar
aaa
