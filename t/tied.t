use t::TestYAMLTests tests => 2;

use Tie::Array;
use Tie::Hash;

my $yaml1 = <<'...';
---
- 'foo'
- 'bar'
- 'baz'
...

tie my @av, 'Tie::StdArray'; 
$av[0] = 'foo';
$av[1] = 'bar';
$av[2] = 'baz';
is Dump(\@av), $yaml1, 'Dumping tied array works';


my $yaml2 = <<'...';
---
bar: 'bar'
baz: 'baz'
foo: 'foo'
...

tie my %hv, 'Tie::StdHash';
$hv{foo} = 'foo';
$hv{bar} = 'bar';
$hv{baz} = 'baz';
is Dump(\%hv), $yaml2, 'Dumping tied hash works';


