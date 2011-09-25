BEGIN {$main::PM = 'lib/YAML/XS.pm'}
use inc::Module::Package 'Ingy:modern 0.16';

build_subdirs    'LibYAML';
clean_files      't/output';
