use strict;
use warnings;
use Test::More;
use YAML::XS;

my $yaml = '@invalid';

subtest 'destroy-after-eval-error' => sub {
    # Here DESTROY is called after the exception handler
    {
        my $xs = YAML::XS->new;
        eval {
            my $data = $xs->load($yaml);
        };
    }
    my $err = $@;
    like $err, qr{Error};
};

subtest 'destroy-before-eval-error' => sub {
    # Here DESTROY is called before the exception handler
    {
        eval {
            my $xs = YAML::XS->new;
            my $data = $xs->load($yaml);
        };
    }
    my $err = $@;
    like $err, qr{Error};
};

done_testing;
