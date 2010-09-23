use inc::Module::Install;

name            'YAML-LibYAML';
all_from        'lib/YAML/XS.pm';
readme_from;
manifest_skip;
version_check;
ack_xxx;

use_test_base;

build_subdirs    'LibYAML';

clean_files      't/output';

WriteAll;
