#!/usr/bin/env perl

package MyRotate;

use Moo;
extends 'File::Rotate::Simple';

use Path::Tiny;
use Types::Standard -types;

has digits => (
    is      => 'ro',
    isa     => Int,
    default => 3,
);

sub _build_file_regexp {
    my ($self) = @_;
    my $size = $self->digits;
    my $base = quotemeta($self->file->basename);
    qr/^${base}(?:[.](\d{$size}))?$/i;
}

around rotate_file => sub {
  my ($next, $self, @args) = @_;

  my $rotated = $self->$next(@args);
  if ($rotated) {

      if (my $file = $rotated->{rotated}) {

          if ($file =~ /[.](\d+)$/) {

              my $index = $1;
              my $size = $self->digits;
              my $ext   = sprintf("\%0${size}d", $index+0);
              my $name  = $file->basename;
              $name =~ s/[.]${index}$/.$ext/;

              $rotated->{rotated} = path($file->parent, $name);
          }

      }

  }


  return $rotated;
};

package main;

use strict;
use warnings;

use Test::More;
use Path::Tiny;

use_ok 'File::Rotate::Simple';

my $dir  = Path::Tiny->tempdir;
my $base = 'test.log';
my $file = path($dir, $base);

$file->touch;
path($dir, $base . '.' . sprintf('%03d', $_))->touch for (1..3);

MyRotate->new(
    file => $file->stringify,
    )->rotate;

ok !-e $file, 'file missing';
ok -e path($dir, $base . '.' . sprintf('%03d', $_)), "file $_ rotated" for (1..4);

done_testing;
