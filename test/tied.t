use warnings;
use strict;
use FindBin '$Bin';
use lib $Bin;
use Test::More;
use YAML::XS qw/ Dump /;

BEGIN {
    if ($] < 5.010000) {
        plan skip_all => 'needs perl 5.10 or higher';
    }
    else {
        plan tests => 4;
    }
}

use Tie::Array;
use Tie::Hash;

subtest 'tie-array' => sub {
    my $yaml = <<'...';
---
- foo
- bar
- baz
...

    tie my @av, 'Tie::StdArray';
    $av[0] = 'foo';
    $av[1] = 'bar';
    $av[2] = 'baz';
    is Dump(\@av), $yaml, 'Dumping tied array works';
};

subtest 'tie-hash' => sub {
    my $yaml = <<'...';
---
bar: bar
baz: baz
foo: foo
...

    tie my %hv, 'Tie::StdHash';
    $hv{foo} = 'foo';
    $hv{bar} = 'bar';
    $hv{baz} = 'baz';
    is Dump(\%hv), $yaml, 'Dumping tied hash works';
};

{
    package Tie::OneIterationOnly;
    my @KEYS = qw(bar baz foo);

    sub TIEHASH {
        return bless \do { my $x }, shift;
    }

    sub FIRSTKEY {
        my ($self) = @_;
        return shift @KEYS;
    }

    sub NEXTKEY {
        my ($self, $last) = @_;
        return shift @KEYS;
    }

    sub FETCH {
        my ($self, $key) = @_;
        return;
    }
}

subtest 'tie-special' => sub {
    my $yaml3 = <<'...';
--- {}
...

    tie my %hv, 'Tie::OneIterationOnly';
    is Dump(\%hv), $yaml3, 'Dumping tied hash works';
};

subtest 'nested-tie' => sub {
    my $ref =  [qw/ a b c /];

    my %foo = (foo => $ref, bar => $ref );
    tie my %bar, 'TestStdHash', %foo;
    my $yaml = Dump \%bar;
    my $exp = <<'EOM';
---
bar: &1
- a
- b
- c
foo: *1
EOM
    is $yaml, $exp, 'Dumping nested tied hash works';

    my @foo = ($ref, $ref);
    tie my @bar, 'TestStdArray', @foo;
    $yaml = Dump \@bar;
    $exp = <<'EOM';
---
- &1
  - a
  - b
  - c
- *1
EOM
    is $yaml, $exp, 'Dumping nested tied array works';
};

package TestStdHash;
our @ISA = qw/ Tie::StdHash /;
sub TIEHASH { my $class = shift; return bless {@_}, $class }
sub FIRSTKEY { my $a = scalar keys %{$_[0]}; each %{$_[0]} }
sub NEXTKEY { each %{$_[0]} }
sub FETCH { $_[0]->{$_[1]} }


package TestStdArray;
our @ISA = qw/ Tie::StdArray /;
sub TIEARRAY { my $class = shift; return bless [@_], $class }
sub FETCH { $_[0]->[ $_[1]]  }
sub FETCHSIZE { scalar @{ $_[0] } }
