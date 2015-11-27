#!/usr/bin/env perl

use Test::Most;

use Path::Tiny 0.018;

use_ok 'File::Rotate::Simple';

my $dir  = Path::Tiny->tempdir;
my $base = 'test.log';
my $file = path($dir, $base);

my $r = File::Rotate::Simple->new(
    file => "$file",
    );

isa_ok $r => 'File::Rotate::Simple';

subtest 'default accessors' => sub {
    is $r->file       => $file, 'file';
    is $r->if_missing => 0, 'if_missing';
    is $r->max        => 0, 'max';
    is $r->age        => 0, 'age';
    is $r->extension_format => '.%#', 'extension_format';
    is $r->replace_extension => undef, 'replace_extension';
    is $r->touch      => 0, 'touch';
};

my @todo = (1..5);
my @done;

while (my $index = shift @todo) {

    $file->touch;

    subtest 'expected state of pre-rotated files' => sub {

        ok $file->exists, "${file} exists";

        foreach ($index, @todo) {
            my $path = path($file->parent, $base . '.' . $_);
            ok !$path->exists, "${path} does not exist";
        }
    };

    my $files = $r->_build_files_to_rotate;
    is scalar(@$files) => 1 + scalar(@done), 'number of files to rotate';

    $r->rotate;

    push @done, $index;

    subtest 'expected state of post-rotated files' => sub {

        ok !$file->exists, "${file} does not exist";

        foreach (@done) {
            my $path = path($file->parent, $base . '.' . $_);
            ok $path->exists, "${path} exists";
        }

    };

    is_deeply $r->_build_files_to_rotate => [], 'no files to rotate';
};


done_testing;
