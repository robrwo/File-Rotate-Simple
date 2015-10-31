package File::Rotate::Simple;

use Moo;

use Path::Tiny;
use Types::Standard -types;

use namespace::autoclean;

use version; our $VERSION = version->declare('v0.1.0');

=head1 NAME

File::Rotate::Simple - no-frills fill rotation

=head1 SYNOPSIS

  use File::Rotate::Simple;

  File::Rotate::Simple->rotate(
      file => '/foo/bar/backup.tar.gz',
      age  => 7,
      max  => 30,
  );

  File::Rotate::Simple->rotate(
      files => [ qw{ /var/log/foo.log /var/log/bar.log } ],
      max   => 7,
  );

=head1 DESCRIPTION

This module implements simple file rotation.

Files are renamed to have a numeric suffix, e.g. F<backup.tar.gz> is renamed to
F<backup.tar.gz.1>.  Existing file numbers are incremented.

If L</max> is specified, then any files with a larger numeric suffix
are deleted.

If L</age> is specified, then any files older than that number of days
are deleted.

Note that files with the extension C<0> are ignored.

=head1 ATTRIBUTES

=head2 C<age>

The maximum age of files (in days).  Older files will be deleted.

A value C<0> means there is no maximum age.

=cut

has age => (
    is      => 'ro',
    isa     => Int,
    default => 0,
);

=head2 C<max>

The maximum number of files to keep.  Numbered files larger than this
will be deleted.

A value of C<0> means that there is no maximum number.

Note that it does not track whether intermediate files are missing.

=cut

has max => (
    is      => 'ro',
    isa     => Int,
    default => 0,
);

=head2 C<file>

The file to rotate. This can be a string or L<Path::Tiny> object.

=head2 C<files>

When L</rotate> is called as a constructor, you can spefify an array
reference of files to rotate.

=cut

has file => (
    is       => 'ro',
    isa      => InstanceOf['Path::Tiny'],
    coerce   => sub { path(shift) },
    required => 1,
);

=begin internal

=head2 C<files>

This is an array reference of numbered backup files. It is used
internally.

=end internal

=cut

has files => (
    is        => 'lazy',
    isa       => ArrayRef[ Maybe[InstanceOf['Path::Tiny']] ],
    init_args => undef,
);

sub _build_files {
    my $self = shift;

    my $base = quotemeta($self->file->basename);
    my $re   = qr/^${base}(?:[.]([1-9]\d*))?$/;

    my @files;

    my $iter = $self->file->parent->iterator;

    while (my $file = $iter->()) {

        next unless $file->basename =~ $re;

        my $index = $1;

        $files[ $index // 0 ] = $file;

    }

    return \@files;
}

=head1 METHODS

head2 C<rotate>

Rotates the files.

This can be called as a constructor.

=cut

sub rotate {
    my $self = shift;

  unless (ref $self) {
      my %args = (@_ == 1) ? %{ $_[0] } : @_;

      if (my $files = delete $args{files}) {
          foreach my $file (@{$files}) {
              $self->new( %args, file => $file )->rotate;
          }
          return;
      }

      $self = $self->new(%args);
  }

  my @files = @{ $self->files };
  my $index = scalar( @files );

  my $age   = ($self->age)
      ? time - ($self->age * 86_400)
      : 0;

  while ($index--) {

      my $file = $files[$index] or next;

      if ($self->max && $index >= $self->max) {
          $file->remove;
          next;
      }

      if ($age && $file->stat->mtime < $age) {
          $file->remove;
          next;
      }

      my $ext = $index + 1;
      my $new = $index
          ? $file =~ s/[.]${index}$/.${ext}/r
          : $file . '.' . $ext;

      $file->move($new);
  }

}



1;
