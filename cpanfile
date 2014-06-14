on test => sub {
    requires 'Test::More', 0.98;
    requires 'FindBin';
};

on configure => sub {
};

on 'develop' => sub {
    requires 'Version::Next';
    requires 'CPAN::Uploader';
};

requires 'Devel::Cover', 1.02;
requires 'JSON::MaybeXS';
requires 'YAML';
requires 'Furl';
