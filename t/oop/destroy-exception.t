use strict;
use warnings;
use Test::More;
use YAML::XS;

my $yaml = <<'EOM';
@invalid
EOM

if ($ARGV[0]) {

    {
        my $xs = YAML::XS->new;
        eval {
            my $data = $xs->load($yaml);
            #$data = YAML::XS::Load($yaml);
            warn __PACKAGE__.':'.__LINE__.": ??????????????????\n";
        };
    }
    my $err = $@;
    diag "!!!!!!!!!!!!!!!!!! $@";
    like $err, qr{Error};
}
else {
    {
        eval {
            my $xs = YAML::XS->new;
            warn __PACKAGE__.':'.__LINE__.": -> load\n";
            my $data = $xs->load($yaml);
            #$data = YAML::XS::Load($yaml);
            warn __PACKAGE__.':'.__LINE__.": ??????????????????\n";
        };
    }
    my $err = $@;
    diag "!!!!!!!!!!!!!!!!!! $@";
    like $err, qr{Error};
}


done_testing;
