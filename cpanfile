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
requires 'HTTP::Tiny';
requires 'IO::Socket::SSL', 1.42;
requires 'JSON::PP';
requires 'Mozilla::CA';
requires 'Net::SSLeay', 1.49;
requires 'YAML';
