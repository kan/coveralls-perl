on test => sub {
    requires 'Test::More', 0.98;
};

on configure => sub {
};

on 'develop' => sub {
};

requires 'Devel::Cover';
requires 'JSON::XS';
requires 'YAML';
requires 'Furl';
