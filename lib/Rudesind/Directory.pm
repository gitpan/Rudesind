package Rudesind::Directory;

use strict;

use Rudesind::Captioned;
use base 'Rudesind::Captioned';

use Params::Validate qw( validate validate_pos SCALAR );
use Path::Class ();

use Rudesind::Config;


sub new
{
    my $class = shift;
    my %p = validate( @_,
                      { path   => { type => SCALAR },
                        config => { isa => 'Rudesind::Config' },
                      }
                    );

    $p{path} =~ s{/$}{};

    my @dirs = split /\//, $p{path};

    my $dir =
        Path::Class::dir( $p{config}->image_dir, @dirs )->cleanup;

    return unless -d $dir;

    my $title = @dirs ? $dirs[-1] : 'top';
    my $self =
        bless { dir    => $dir,
                path   => $p{path},
                title  => $title,
                config => $p{config},
              }, $class;

    return $self;
}

sub path   { $_[0]->{path} }
sub title  { $_[0]->{title} }
sub config { $_[0]->{config} }

sub uri    { $_[0]->path }

sub contents
{
    my $self = shift;

    return @{ $self->{contents} } if $self->{contents};

    local *DIR;
    opendir DIR, "$self->{dir}" or die "Cannot read $self->{dir}: $!";

    $self->{contents} =
        [ map { "$self->{dir}/$_" }
          grep { ! /^\./ }
          readdir DIR
        ];

    return @{ $self->{contents} };
}

sub subdirectories
{
    my $self = shift;

    return sort map { $self->_strip_dir($_) } grep { ! /^\./ && -d } $self->contents;
}

sub _strip_dir { $_[1] =~ s,$_[0]->{dir}/,,; $_ }

sub subdirectory_path { $_[0]->_add_path( $_[1] ) }

sub _add_path { $_[0]->{path} ? join '/', $_[0]->{path}, $_[1] : $_[1] }

sub images
{
    my $self = shift;

    return @{ $self->{images} } if $self->{images};

    my $re = Rudesind::Image->image_extension_re;

    $self->{images} =
        [ map { Rudesind::Image->new( file   => "$self->{dir}/$_",
                                      path   => $self->_add_path($_),
                                      config => $self->config,
                                    ) }
          map { $self->_strip_dir($_) }
          sort
          grep { /$re/ }
          $self->contents
        ];

    return @{ $self->{images} };
}

sub image
{
    my $self = shift;
    my ($file) = validate_pos( @_, { type => SCALAR } );

    return unless -f "$self->{dir}/$file";

    return
        Rudesind::Image->new( file => "$self->{dir}/$file",
                              path => $self->_add_path($file),
                              config => $self->config,
                            );
}

sub previous_image
{
    my $self = shift;
    my $image = shift;

    my $prev;
    foreach my $i ( $self->images )
    {
        return $prev if $i->path eq $image->path;

        $prev = $i;
    }
}

sub next_image
{
    my $self = shift;
    my $image = shift;

    my $next;
    foreach my $i ( reverse $self->images )
    {
        return $next if $i->path eq $image->path;

        $next = $i;
    }
}

sub _caption_file
{
    my $self = shift;

    return $self->{dir}->file('.caption');
}


1;

__END__
