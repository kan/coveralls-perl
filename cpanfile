on test => sub {
    requires 'Test::More', 0.98;
    requires 'FindBin';
};

on configure => sub {
    requires 'Module::Build::Tiny';
};

on 'develop' => sub {
    requires 'Minilla';
    requires 'Pod::Markdown::Github';
    requires 'Version::Next';
    requires 'Test::MinimumVersion::Fast';
    requires 'Test::PAUSE::Permissions';
    requires 'Test::Pod';
    requires 'Test::Spellunker';
    requires 'CPAN::Uploader';
};

requires 'Devel::Cover', 1.02;
requires 'HTTP::Tiny', 0.043;
requires 'IO::Socket::SSL', 1.42;
requires 'JSON::PP';
requires 'Mozilla::CA';
requires 'Net::SSLeay', 1.49;
requires 'YAML';
