on test => sub {
    requires 'Test::More', 0.98;
    requires 'FindBin';
};

on configure => sub {
    requires 'Module::Build::Tiny';
};

on 'develop' => sub {
    # v3.2.0: manage_changes in minil.toml (the change log is CHANGELOG.md)
    requires 'Minilla', 'v3.2.0';
    requires 'Pod::Markdown::Github';
    requires 'Test::MinimumVersion::Fast';
    requires 'Test::PAUSE::Permissions';
    requires 'Test::Pod';
    requires 'Test::Spellunker';
};

requires 'Devel::Cover', 1.02;
requires 'Digest::MD5';
requires 'HTTP::Tiny', 0.043;
requires 'IO::Socket::SSL', 1.42;
requires 'JSON::PP';
# Makes the JSON of a large distribution in a fraction of the time JSON::PP takes (#98).
recommends 'Cpanel::JSON::XS';
requires 'Mozilla::CA';
requires 'Net::SSLeay', 1.49;
requires 'YAML';
