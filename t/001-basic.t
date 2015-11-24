#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 0.99;

use Time::Piece;
use Path::Tiny;

use_ok 'File::Rotate::Simple';

subtest '_rotated_name' => sub {

    {
        my $r = File::Rotate::Simple->new(
            file => 'test.dat',
        );

        is $r->_rotated_name(1) =>
            path('test.dat.1'), '_rotated_name(1) with default format';
    }

    {
        my $r = File::Rotate::Simple->new(
            file             => 'test.dat',
            extension_format => '.backup-%4#',
        );

        is $r->_rotated_name(2) => path('test.dat.backup-0002'),
            '_rotated_name(2) with changed format';
    }

    {
        my $r = File::Rotate::Simple->new(
            file              => 'test.log',
            extension_format  => '.%3#.log',
            replace_extension => '.log',
        );

        is $r->_rotated_name(2) =>
            path('test.002.log'), '_rotated_name(2) with replace_extension';
    }


    {
        my $time = localtime( time - 60 );

        my $r = File::Rotate::Simple->new(
            file             => 'test.dat',
            extension_format => '.%Y%m%d',
            time             => $time,
        );

        is $r->_rotated_name(1) =>
            path('test.dat' . $time->strftime($r->extension_format)),
            '_rotated_name(1) with date format';
    }

    {
        my $time = gmtime();

        my $r = File::Rotate::Simple->new(
            file             => 'test.dat',
            extension_format => '.%Y%m%d',
            time             => $time,
        );

        is $r->_rotated_name(1) =>
            path('test.dat' . $time->strftime($r->extension_format)),
            '_rotated_name(1) with date format';
    }

    {
        my $time = localtime;

        my $r = File::Rotate::Simple->new(
            file             => 'test.dat',
            extension_format => '.%y-%m-%d.%2#',
            time             => $time,
        );

        is $r->_rotated_name(9) =>
            path('test.dat' . $time->strftime('.%y-%m-%d.09')),
            '_rotated_name(9) with date format';
    }

};

my $dir  = Path::Tiny->tempdir;
my $base = 'test.log';
my $file = path($dir, $base);

$file->touch;
path($dir, $base . '.' . $_)->touch for (1..3);

File::Rotate::Simple->rotate(
    file => $file->stringify,
    if_missing => 1,
    );

ok !-e $file, 'file missing';
ok -e path($dir, $base . '.' . $_), "file $_ rotated" for (1..4);

File::Rotate::Simple->rotate(
    file => $file->stringify,
    if_missing => 1,
    );

ok !-e $file, 'file missing';
ok !-e path($dir, $base . '.' . $_), "file $_ missing" for (1);
ok -e path($dir, $base . '.' . $_), "file $_ rotated" for (2..5);

File::Rotate::Simple->rotate(
    file => $file->stringify,
    max  => 5,
    if_missing => 1,
    );

ok !-e $file, 'file missing';
ok !-e path($dir, $base . '.' . $_), "file $_ missing" for (1..2, 6);
ok -e path($dir, $base . '.' . $_), "file $_ rotated" for (3..5);


path($dir, $base . '.' . $_)->touch for (1..2,6);
path($dir, $base . '.' . $_)->touch( time - 86401 ) for (5);


File::Rotate::Simple->rotate(
    file => $file->stringify,
    age  => 1,
    if_missing => 1,
    );

ok !-e $file, 'file missing';
ok !-e path($dir, $base . '.' . $_), "file $_ missing" for (1, 6);
ok -e path($dir, $base . '.' . $_), "file $_ rotated" for (3..5, 7);

done_testing;
