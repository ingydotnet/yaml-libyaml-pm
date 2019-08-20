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
#        say "EVAL_ERROR: $@\nfailed to convert YAML string: $str";
    }
}

my $str = do { local $/; <DATA> };

my $count = $ARGV[0] || 1000;
my $sleep = $ARGV[1] || 3;
my $m1 = mem();

for my $i (0 .. $count) {
    select undef, undef, undef, $sleep;
    yaml($str);

}
my $m2 = mem();
say $m2 - $m1;

sub mem {
    chomp(my $mem = qx{ps --no-headers -o vsize:3 --pid $$});
    say "Mem: $mem";
    return $mem;
}

=pod

=over

=item Mappings

    ---
    foo: [[[[[[[[[[bar]]]]]]]]]]
    aaa


    ---
    - {{{{{{{{{{

=item Sequences

    ---
    - [[[[[[[[[[foo]]]]]]]]]]
    - @error

    ---
    - [[[[[[[[[[

=back

=cut

__DATA__
---
foo: [[[[[[[[[[bar]]]]]]]]]]
aaa
