use ExtUtils::MakeMaker;
use strict;
use Config;

 my $s = join " " => sort glob ("*.c"), glob ("src/*.c"), glob ("*.xs");
(my $o = $s) =~ s{\.(?:c|xs)\b}{$Config::Config{_o}}g;
(my $l = $o) =~ s{\bsrc/}{}g;

my $DEFINE = $^O eq 'MSWin32'
    ? '-DHAVE_CONFIG_H -DYAML_DECLARE_EXPORT'
    : '-DHAVE_CONFIG_H';

WriteMakefile(
    NAME => 'YAML::XS::LibYAML',
    ABSTRACT_FROM => 'lib/YAML/XS/LibYAML.pm',
    AUTHOR => 'Ingy döt Net <ingy@cpan.org>',
    PREREQ_PM => {},
    CCFLAGS => "-I. -Isrc -Iinclude $DEFINE",
    OBJECT => $o,
    LDFROM => $l,
);
