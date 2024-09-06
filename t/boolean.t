use FindBin '$Bin';
use lib $Bin;
use constant HAVE_BOOLEANS => ($^V ge v5.36);
use TestYAMLTests tests => 5 + (HAVE_BOOLEANS ? 4 : 0);

my $yaml = <<'...';
---
a: true
b: 1
c: false
d: ''
...

my $hash = Load $yaml;

cmp_ok $hash->{a}, '==', $hash->{b},
    "true is loaded as a scalar whose numeric value is 1";
is "$hash->{a}", "$hash->{b}",
    "true is loaded as a scalar whose string value is '1'";
is "$hash->{c}", "$hash->{d}",
    "false is loaded as a scalar whose string value is ''";

my $yaml2 = Dump($hash);

is $yaml2, $yaml,
    "Booleans YNY roundtrip";

my $yaml3 = <<'...';
---
- true
- false
- 'true'
- 'false'
- 1
- 0
- ''
...

my $yaml4 = Dump Load $yaml3;

is $yaml4, $yaml3,
    "Everything related to boolean YNY roundtrips";

if( HAVE_BOOLEANS ) {
    no if HAVE_BOOLEANS, warnings => "experimental::builtin";

    is Dump({ true => builtin::true, false => builtin::false }),
        <<'...',
---
'false': false
'true': true
...
        'core booleans dump as booleans';

    ok builtin::is_bool(Load(<<'...',)->{false}),
---
'false': false
'true': true
...
        'booleans loaded as core booleans';

    eval { $hash->{a} = 'something else' };
    is $@, '', "core boolean element in hash is not readonly";
    is $hash->{a}, 'something else', "core boolean element is changed";
}
