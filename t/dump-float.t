use strict;
use warnings;
use Test::More;
use YAML::XS ();
use B ();

# Tests for oo_dump_scalar float handling (fix for heap buffer overflow,
# perl_libyaml.c:2090).
#
# The bug: SvPV_nolen() returned a raw pointer into an SV's heap buffer
# (allocated to exactly strlen+1 bytes).  strcat(string, ".0") then wrote
# 3 bytes past the end of that buffer.  Additionally, scientific-notation
# values like 1e+100 had ".0" appended, producing the invalid YAML literal
# "1e+100.0".
#
# The fix appends ".0" only when the string contains neither '.' nor 'e'/'E'
# (i.e. it looks like a plain integer such as "100"), and does so on a
# mortal copy via sv_catpvs() rather than on the raw SvPV buffer.
#
# Test categories:
#   A. Scientific notation, no dot   -- was: overflow + invalid YAML ("1e+100.0")
#                                       now: pass-through ("1e+100")
#   B. Integer-looking NV             -- was: overflow + ".0" on raw buffer
#                                       now: ".0" appended safely ("100.0")
#   C. Decimal float                  -- unchanged ("1.5")
#   D. Scientific notation, with dot  -- unchanged ("1.5e+20")
#   E. Special values: inf/-inf/nan   -- unchanged (".inf"/".nan")
#   F. SV non-mutation                -- original SV unchanged after dump()

my $inf    = 9**9**9;
my $neginf = -$inf;
my $nan    = $inf - $inf;

my $xs = YAML::XS->new(header => 0);

# ---------------------------------------------------------------------------
# A. Scientific notation without a decimal point
#    These are the overflow-triggering values.  The fix keeps them as-is
#    because the 'e' marker already makes them recognisable as YAML floats.
# ---------------------------------------------------------------------------
subtest 'scientific notation (no dot) -- overflow triggers' => sub {
    my @cases = (
        [ 1e100,   '1e+100'  ],
        [ 1e20,    '1e+20'   ],
        [ 9e99,    '9e+99'   ],
        [ 1e300,   '1e+300'  ],
        [ -1e100,  '-1e+100' ],
        [ -1e20,   '-1e+20'  ],
    );
    for my $c (@cases) {
        my ($val, $want) = @$c;
        my $got = $xs->dump($val);
        $got =~ s/^---\s*//; chomp $got;
        is $got, $want, "dump($val) = '$want'";
    }
};

# ---------------------------------------------------------------------------
# B. NV values that stringify as plain integers (need ".0" suffix appended)
#    e.g. 100.0 stringifies as "100" -> must become "100.0" in YAML so that
#    a YAML loader does not misinterpret the value as an integer.
# ---------------------------------------------------------------------------
subtest 'integer-looking NV (dot must be appended)' => sub {
    my @cases = (
        [ 1.0,   '1.0'   ],
        [ 100.0, '100.0' ],
        [ -1.0,  '-1.0'  ],
        [ 0.0,   '0.0'   ],
    );
    for my $c (@cases) {
        my ($val, $want) = @$c;
        my $got = $xs->dump($val);
        $got =~ s/^---\s*//; chomp $got;
        is $got, $want, "dump($val) = '$want'";
    }
};

# ---------------------------------------------------------------------------
# C. Decimal floats -- must pass through unchanged
# ---------------------------------------------------------------------------
subtest 'decimal floats (pass-through)' => sub {
    my @cases = (
        [ 1.5,    '1.5'    ],
        [ 3.14,   '3.14'   ],
        [ -0.5,   '-0.5'   ],
        [ 0.001,  '0.001'  ],
    );
    for my $c (@cases) {
        my ($val, $want) = @$c;
        my $got = $xs->dump($val);
        $got =~ s/^---\s*//; chomp $got;
        is $got, $want, "dump($val) = '$want'";
    }
};

# ---------------------------------------------------------------------------
# D. Scientific notation with decimal point -- must pass through unchanged
# ---------------------------------------------------------------------------
subtest 'scientific notation with dot (pass-through)' => sub {
    my @cases = (
        [ 1.5e20,   '1.5e+20'   ],
        [ -2.5e100, '-2.5e+100' ],
    );
    for my $c (@cases) {
        my ($val, $want) = @$c;
        my $got = $xs->dump($val);
        $got =~ s/^---\s*//; chomp $got;
        is $got, $want, "dump($val) = '$want'";
    }
};

# ---------------------------------------------------------------------------
# E. Special float values: infinity and NaN
# ---------------------------------------------------------------------------
subtest 'special float values (inf / -inf / nan)' => sub {
    SKIP: {
        skip "inf/nan broken on this platform", 3
            if $inf eq '0';

        my $got_inf = $xs->dump($inf);
        $got_inf =~ s/^---\s*//; chomp $got_inf;
        is $got_inf, '.inf', 'dump(inf) = .inf';

        my $got_neginf = $xs->dump($neginf);
        $got_neginf =~ s/^---\s*//; chomp $got_neginf;
        is $got_neginf, '-.inf', 'dump(-inf) = -.inf';

        my $got_nan = $xs->dump($nan);
        $got_nan =~ s/^---\s*//; chomp $got_nan;
        is $got_nan, '.nan', 'dump(nan) = .nan';
    }
};

# ---------------------------------------------------------------------------
# F. SV non-mutation: dump() must not alter the caller's SV
#
#    The old strcat() wrote directly into the SV's PV buffer without
#    updating SvCUR.  While Perl's own string accessor masked this via
#    SvCUR, the buffer was silently corrupted.  The fix works on a mortal
#    copy, leaving the original SV untouched.
#
#    We check:
#      1. The string form of the SV is unchanged after dump().
#      2. SvCUR (the stored string length) is unchanged.
#      3. The NOK flag is unchanged (the SV is still a float).
# ---------------------------------------------------------------------------
subtest 'original SV unchanged after dump (non-mutation)' => sub {
    my @cases = (
        1e100,    # was an overflow trigger
        1e20,
        9e99,
        100.0,    # integer-looking NV
        1.0,
    );

    for my $val (@cases) {
        # Force stringification so Perl caches the PV before the call;
        # this matches the conditions under which oo_dump_scalar runs.
        my $before_str = "$val";
        my $before_cur = B::svref_2object(\$val)->CUR;
        my $before_nok = B::svref_2object(\$val)->FLAGS & B::SVp_NOK();

        $xs->dump($val);

        my $after_str = "$val";
        my $after_cur = B::svref_2object(\$val)->CUR;
        my $after_nok = B::svref_2object(\$val)->FLAGS & B::SVp_NOK();

        is $after_str, $before_str,
            "string form of NV $val unchanged after dump";
        is $after_cur, $before_cur,
            "SvCUR of NV $val unchanged after dump";
        ok $after_nok,
            "SVp_NOK still set on NV $val after dump";
    }
};

# ---------------------------------------------------------------------------
# G. Round-trip: load(dump($v)) == $v numerically
#    Validates that the YAML produced by dump() is parseable and that the
#    value survives the round trip.
# ---------------------------------------------------------------------------
subtest 'round-trip: load(dump(v)) == v' => sub {
    my @cases = (1e100, 1e20, 9e99, 1e300, 100.0, 1.5, 1.5e20, -1e100);

    SKIP: {
        skip "inf/nan broken on this platform", 2
            if $inf eq '0';
        push @cases, $inf, $neginf;
    }

    for my $val (@cases) {
        my $yaml    = $xs->dump($val);
        my ($rt)    = $xs->load($yaml);
        # Use string comparison for inf/nan since == may not work for NaN
        if ($val != $val) {
            ok $rt != $rt, "round-trip NaN: load(dump(nan)) is nan";
        } else {
            ok $rt == $val, "round-trip: load(dump($val)) == $val";
        }
    }
};

done_testing;
