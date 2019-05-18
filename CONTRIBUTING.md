# How to contribute

This module uses Zilla::Dist for creating releases. See also the `About` file.

## Commits

Try to follow these guidelines:

* Commit messages
  * Short commit message headline (if possible, up to 60 characters)
  * Blank line before message body
  * Message should be like: "Add foo ...", "Fix ..."
* Git workflow
  * Every branch will be rebased before merging it with --no-ff
  * No merging of master into feature branch
  * User branches might be heavily rebased/reordered/squashed because
    we like a clean history

## Code

* No Tabs please
* No trailing whitespace please
* Look at existing code for formatting ;-)

## Developing

For developing, it is necessary to install Zilla::Dist.  Also, this module puts
a copy of the Test::Base module into the `inc` directory.  For this you have to
clone https://github.com/ingydotnet/test-base-pm parallel to this git
repository.

The layout of the git repository is a bit different from the CPAN tarball.
For example, there is no `Makefile.PL`, and the tests are in the `test`
directory instead of `t`.
The documentation is in the `doc` directory in the `swim` format and
will be converted to pod when generating the CPAN tarball.

To avoid building the dist again and again during development, you can do the
following:

    % zild distdir
    # will create YAML-LibYAML-x.yz
    % cd YAML-LibYAML-x.yz
    % git init
    % git add .
    % git commit -m Initial

The generated directory will look like the final CPAN distribution, so you
can work with `Makefile.PL` as usual.

When development is finshed, copy the changed files one level up.
