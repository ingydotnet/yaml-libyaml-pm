BEGIN {$main::PM = 'lib/YAML/XS.pm'}
use inc::Module::Package 'Ingy:modern 0.20';

name 'YAML-LibYAML';
all_from 'lib/YAML/XS.pm';
build_subdirs 'LibYAML';
clean_files 't/output';
