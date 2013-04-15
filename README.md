# NAME

Devel::Cover::Report::Coveralls - coveralls backend for Devel::Cover

# SYNOPSIS

    # .travis.yaml
    language: perl
    perl:
      - 5.16.3
      - 5.14.4
    before_install:
      cpanm Devel::Cover::Report::Coveralls
    script:
      perl Build.PL && ./Build build && cover -test
    after_success:
      cover -report coveralls

# DESCRIPTION

[https://coveralls.io/](https://coveralls.io/) is service to publish your coverage stats online with a lot of nice features. This module provides seamless integration with [Devel::Cover](http://search.cpan.org/perldoc?Devel::Cover) in your perl projects.

# SEE ALSO

[https://coveralls.io/](https://coveralls.io/)
[https://coveralls.io/docs](https://coveralls.io/docs)
[https://github.com/coagulant/coveralls-python](https://github.com/coagulant/coveralls-python)
[Devel::Cover](http://search.cpan.org/perldoc?Devel::Cover)

# LICENSE

Copyright (C) Kan Fushihara

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Kan Fushihara <kan.fushihara@gmail.com>
