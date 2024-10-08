use ExtUtils::MakeMaker;
use strict;
use Config;
use utf8;

# update.sh shouldn't be used, needs fix
#if (-d '../.git') {
#    system("./update.sh") == 0
#        or die "update.sh failed";
#}

my $obj_files = join ' ', map {
    my $c = $_;
    $c =~ s/\.c$/$Config::Config{_o}/;
    $c;
} glob("*.c"), 'LibYAML.c';

my $DEFINE = $^O eq 'MSWin32'
? '-DHAVE_CONFIG_H -DYAML_DECLARE_EXPORT'
: '-DHAVE_CONFIG_H';
WriteMakefile(
    NAME => 'YAML::XS::LibYAML',
    PREREQ_PM => {},
    # CCFLAGS => '-ansi -pedantic -Wall',
    # CCFLAGS => '-ansi -Wall',
    # CCFLAGS => '-pedantic -Wall',
    # CCFLAGS => '-Wall',
    DEFINE => $DEFINE,
    LIBS => [''], # e.g., '-lm'
    INC => '-I.',
    OBJECT => $obj_files,
    ABSTRACT_FROM => 'lib/YAML/XS/LibYAML.pm',
    AUTHOR => 'Ingy döt Net <ingy@cpan.org>',
);
