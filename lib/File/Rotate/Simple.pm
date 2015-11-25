package File::Rotate::Simple;

use Moo 1.001000;

use Class::Load qw/ load_class /;
use Graph;
use Path::Tiny;
use Time::Seconds qw/ ONE_DAY /;
use Types::Standard -types;

use namespace::autoclean;

use version;
$File::Rotate::Simple::VERSION = version->declare('v0.2.0');

# RECOMMEND PREREQ: Class::Load::XS
# RECOMMEND PREREQ: Type::Tiny::XS

=head1 NAME

File::Rotate::Simple - no-frills file rotation

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

=for readme stop

=head1 ATTRIBUTES

=head2 C<age>

The maximum age of files (in days), relative to the L</time>
attribute.  Older files will be deleted.

A value C<0> (default) means there is no maximum age.

=cut

has age => (
    is      => 'ro',
    isa     => Int,
    default => 0,
);

=head2 C<max>

The maximum number of files to keep.  Numbered files larger than this
will be deleted.

A value of C<0> (default) means that there is no maximum number.

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

When L</rotate> is called as a constructor, you can specify an array
reference of files to rotate:

  File::Rotate::Simple->rotate(
     files => \@files,
     ...
  );

=cut

has file => (
    is       => 'ro',
    isa      => InstanceOf['Path::Tiny'],
    coerce   => sub { path(shift) },
    required => 1,
);

=head2 C<start_num>

The starting number to use when rotating files. Defaults to C<1>.

Added in v0.2.0.

=cut

has start_num => (
    is      => 'ro',
    isa     => Int,
    default => 1,
);

=head2 C<extension_format>

The extension to add when rotating. This is a string that is passed to
L<Time::Piece/strftime> with the following addition of the C<%#> code,
which corresponds to the rotation number of the file.

Added in v0.2.0.

=cut

has extension_format => (
    is      => 'ro',
    isa     => Str,
    default => '.%#',
);

=head2 C<replace_extension>

If defined, it replaces the extension with the one specified by
L</extension_format> rather than appending it.  Use this when you want
to preserve the existing extension in a rotated backup, e.g.

    my $r = File::Rotate::Simple->new(
        file              => 'myapp.log',
        extension_format  => '.%#.log',
        replace_extension => '.log',
    );

will rotate the log as F<myapp.1.log>.

Added in v0.2.0.

=cut

has replace_extension => (
    is  => 'ro',
    isa => Maybe[Str],
);

=head2 C<if_missing>

When true, rotate the files even when L</file> is missing. False by default.

Added in v0.2.0. Note that the default behaviour before this version
was to always rotate files.

=cut

has if_missing => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

=head2 C<time>

A time object corresponding to the time used for generating
timestamped extensions in L</extension_format>.  It defaults to a
L<Time::Piece> object with the current local time.

You can specify an alternative time (including time zone) in the
constructor, e.g.

    use Time::Piece;

    my $r = File::Rotate::Simple->new(
        file              => 'myapp.log',
        time              => gmtime(),
        extension_format  => '.%Y%m%d',
    );

L<Time::Moment> and L<DateTime> objects can also be given.

Added in v0.2.0.

=cut

has time => (
    is      => 'lazy',
    isa     => InstanceOf[qw/ Time::Piece Time::Moment DateTime /],
    default => sub { load_class('Time::Piece'); Time::Piece::localtime() },
    handles => {
        _strftime => 'strftime',
        _epoch    => 'epoch',
    },
);

=head1 METHODS

=head2 C<rotate>

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

    my $max   = $self->max;
    my $age   = ($self->age)
        ? $self->_epoch - ($self->age * ONE_DAY)
        : 0;

    my @files = @{ $self->_build_files_to_rotate };

    my $index = scalar( @files );

    while ($index--) {

        my $file = $files[$index] or next;

        my $current = $file->{current};
        my $rotated    = $file->{rotated};

        unless (defined $rotated) {
            $current->remove;
            next;
        }

        if ($max && $index >= $max) {
            $current->remove;
            next;
        }

        if ($age && $current->stat->mtime < $age) {
            $current->remove;
            next;
        }

        die "Cannot move ${current} -> ${rotated}: file exists"
          if $rotated->exists;

        $current->move($rotated);
    }

  }

=begin internal

=head2 C<_build_files_to_rotate>

This method builds a reverse-ordered list of files to rotate.

It gathers a list of files to rotate using L</rotate_file> and
L</file> and sorts them based on what the files will be renamed to.

=cut

sub _build_files_to_rotate {
    my ($self) = @_;

    my %files;

    my $num = $self->start_num;

    my $file = $self->_rotated_name( $num );
    if ($self->file->exists) {

        $files{ $self->file } = {
            current => $self->file,
            rotated => $file,
        };

    } else {

        return [ ] unless $self->if_missing;

    }

    my $max  = $self->max;
    while ($file->exists || ($max && $num <= $max)) {

        my $rotated = $self->_rotated_name( ++$num );

        last if $rotated eq $file;

        if ($file->exists) {
            $files{ $file } = {
                current => $file,
                rotated => (!$max || $num <= $max) ? $rotated : undef,
            };
        }

        $file = $rotated;

    }

    my $g = Graph->new;
    foreach my $file (values %files) {
        my $current = $file->{current};
        if (my $rotated = $file->{rotated}) {
            $g->add_edge( $current->stringify,
                          $rotated->stringify );
        } else {
            $g->add_vertex( $current->stringify );
        }
    }

    die "dependency chain is cyclic"
      if $g->has_a_cycle;

    return [
        grep { defined $_ }
        map  { $files{$_} } $g->topological_sort()
        ];

}

=begin internal

=head2 C<_rotated_name>

This is a utility method for generating rotated file names.

=end internal

=cut

sub _rotated_name {
    my ($self, $index) = @_;

    my $format = $self->extension_format;
    {
        no warnings 'uninitialized';
        $format =~ s/\%(\d+)*#/sprintf("\%0$1d", $index)/ge;
    }

    my $file      = $self->file->stringify;
    my $extension = $self->_strftime($format);
    my $replace   = $self->replace_extension;

    if (defined $replace) {

        my $re = quotemeta($replace);
        $file =~ s/${re}$/${extension}/;

        return path($file);

    } else {

        return path( $file . $extension );

    }
}

=for readme continue

=head1 SEE ALSO

The following modules have similar functionality:

=over

=item * L<File::Rotate::Backup>

=item * L<File::Write::Rotate>

=back

There are also several logging modueles that support log rotation.

=head1 AUTHOR

Robert Rothenberg, C<rrwo@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Robert Rothenberg.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

=for readme stop

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=for readme continue

=cut

1;
