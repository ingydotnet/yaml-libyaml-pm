use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests tests => 1;

# https://github.com/ingydotnet/yaml-libyaml-pm/issues/120
#

use YAML::XS   qw/DumpFile LoadFile/;
use File::Temp qw/ tempdir /;

use Cwd qw/ getcwd /;

my $PWD = getcwd();
my $dir = tempdir( CLEANUP => 1 );

chdir($dir);

my $fn = "dont-clobber-me";
open my $fh, ">", ">$fn";
$fh->print( "$fn\n" x 500 );
close($fh);

my $ret = LoadFile(">$fn");

my $size = ( -s ">$fn" );
ok( scalar( $size > 2000 ), "file was not clobbered; size = '$size'" );

chdir($PWD);
