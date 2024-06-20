SHELL := bash

ZILD := \
     clean \
     cpan cpanshell \
     dist distdir distshell disttest \
     install release update \

default:

.PHONY: test
test: distdir
	( \
	    cd YAML-LibYAML-* && \
	    perl Makefile.PL && \
	    make test \
	)

$(ZILD):
	zild $@
