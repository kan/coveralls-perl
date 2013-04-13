package Devel::Cover::Report::Coveralls;
use strict;
use warnings;
use 5.008005;
our $VERSION = "0.01";

use Devel::Cover::DB;
use JSON::XS;
use Furl;
use Data::Dumper;

sub report {
    my ($pkg, $db, $options) = @_;

    my $cover = $db->cover;

    my @sfs;

    for my $file (@{$options->{file}}) {
        my $f = $cover->file($file);
        my $c = $f->statement();

        my $source = '';
        my @coverage;

        open F, $file or warn("Unable to open $file: $!\n"), return;

        while (defined(my $l = <F>)) {
            chomp $l;
            my $n = $.;

            $source .= "$l\n";
            my $l = $c->location($n);
            push @coverage, $l ? $l->[0]->covered : $l;
        }

        close(F);

        push @sfs, {
            name => $file,
            source => $source,
            coverage => \@coverage,
        };
    }

    my $content = encode_json({
        repo_token => 'mw72Q8Crzpt4hJKy3GDHXIo8SbsTcL6zZ',
        service_name => 'travis-ci',
        source_files => \@sfs,
    });

    my $furl = Furl->new;
    my $response = $furl->post('https://coveralls.io/api/v1/jobs', [], [ json_file => [$content] ]);
    warn Dumper(decode_json $response->content);
}


1;
__END__

=encoding utf-8

=head1 NAME

Devel::Cover::Report::Coveralls - It's new $module

=head1 SYNOPSIS

    use Devel::Cover::Report::Coveralls;

=head1 DESCRIPTION

Devel::Cover::Report::Coveralls is ...

=head1 LICENSE

Copyright (C) Kan Fushihara

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kan Fushihara E<lt>kan.fushihara@gmail.comE<gt>

