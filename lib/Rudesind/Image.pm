package Rudesind::Image;

use strict;

use Rudesind::Captioned;
use base 'Rudesind::Captioned';

use File::Basename ();
use File::Path ();
use File::Slurp ();
use Image::Magick;
use Image::Size ();
use Params::Validate qw( validate UNDEF SCALAR ARRAYREF );
use Path::Class ();

use Rudesind::Config;


sub new
{
    my $class = shift;
    my %p = validate( @_,
                      { file   => { type => SCALAR },
                        path   => { type => SCALAR },
                        config => { isa => 'Rudesind::Config' },
                      },
                    );

    # XXX - check if image module can handle this type

    my ( $w, $h ) = Image::Size::imgsize( $p{file} );

    return bless { %p,
                   dir => Path::Class::dir( File::Basename::dirname( $p{file} ) ),
                   height => $h,
                   width  => $w,
                 }, $class;
}

sub file   { $_[0]->{file} }
sub path   { $_[0]->{path} }
sub config { $_[0]->{config} }

sub uri    { $_[0]->{path} . '.html' }

sub height { $_[0]->{height} }
sub width  { $_[0]->{width} }

sub filename { File::Basename::basename( $_[0]->file ) }
sub title    { $_[0]->filename }

sub directory
{
    Rudesind::Directory->new( path   => File::Basename::dirname( $_[0]->path ),
                              config => $_[0]->config );
}

sub _transforms
{
    my $config = $_[0]->config;

    return
    { default   =>
      { max_width   => $config->image_page_max_width,
        max_height  => $config->image_page_max_height,
      },
      thumbnail =>
      { max_width   => $config->thumbnail_max_width,
        max_height  => $config->thumbnail_max_height
      },
      double    => '_double_size',

      'rotate-90'  =>
      { rotate => 90,
        max_width   => $config->image_page_max_width,
        max_height  => $config->image_page_max_height,
      },
      'rotate-270'  =>
      { rotate => 270,
        max_width   => $config->image_page_max_width,
        max_height  => $config->image_page_max_height,
      },
      'rotate-180'  =>
      { rotate => 180,
        max_width   => $config->image_page_max_width,
        max_height  => $config->image_page_max_height,
      },
    };
}

sub _double_size
{
    my $self = shift;

    my $height =
        ( $self->height * 2 > $self->config->image_page_max_width * 2
          ? $self->config->image_page_max_width * 2
          : $self->height * 2
        );

    my $width =
        ( $self->width * 2 > $self->config->image_page_max_width * 2
          ? $self->config->image_page_max_width * 2
          : $self->width * 2
        );

    return ( width => $width, height => $height );
}

sub thumbnail_uri { $_[0]->transformed_image_uri( transforms => 'thumbnail' ) }
sub has_thumbnail { -f $_[0]->thumbnail_image_file }
sub thumbnail_image_file { $_[0]->transformed_image_file( transforms => 'thumbnail' ) }

sub transformed_image_uri
{
    my $self = shift;

    $self->_make_transformed_image_file(@_);

    my $file = $self->transformed_image_file(@_);

    my $root = $self->config->root_dir;
    $file =~ s/\Q$root\E//;

    $file =~ s:\\:/:g;

    return $self->config->image_uri_root . $file;
}

sub has_transformed_image_file
{
    my $self = shift;

    -f $self->transformed_image_file(@_);
}

sub _make_transformed_image_file
{
    my $self = shift;

    my $file = $self->transformed_image_file(@_);

    return if -f $file;

    $self->_transform( $self->_transform_params(@_),
                       output_file => $file,
                     );
}

sub transformed_image_file
{
    my $self = shift;
    my %transform = $self->_transform_params(@_);

    my $file = $self->file;

    my $image_dir = $self->config->image_dir;

    my $t = join '-', sort ( keys %transform, values %transform );
    my $transform_dir = Path::Class::dir( $self->config->image_cache_dir, $t );

    $file =~ s/\Q$image_dir\E/$transform_dir/;

    return $file;
}

sub _transform_params
{
    my $self = shift;
    my %p = validate( @_, { transforms => { type => SCALAR | ARRAYREF,
                                            default => [ 'default' ] },
                          },
                    );

    my %transform;
    foreach my $name ( ref $p{transforms} ? @{ $p{transforms} } : $p{transforms} )
    {
        my $t = $self->_transforms->{$name};

        %transform = ( %transform,
                       ref $t ? %$t : $self->$t()
                     );
    }

    return %transform;
}

sub _transform
{
    my $self = shift;
    my %p = validate( @_,
                      { max_width  => { type    => SCALAR,
                                        default => undef,
                                        depends => 'max_height',
                                      },
                        max_height => { type    => SCALAR,
                                        default => undef,
                                        depends => 'max_width',
                                      },
                        width      => { type    => SCALAR,
                                        default => $self->width,
                                      },
                        height     => { type    => SCALAR,
                                        default => $self->height,
                                      },
                        rotate     => { type    => SCALAR,
                                        default => 0,
                                      },
                        output_file => { type => SCALAR },
                      },
                    );

    my $img = Image::Magick->new;
    $img->Read( filename => $self->file );

    if ( $p{max_width} && $p{max_height} )
    {
        if ( $p{max_width}  < $img->Get('width')
             ||
             $p{max_height} < $img->Get('height')
           )
        {
            my $width_r  = $p{max_width}  / $img->get('width');
            my $height_r = $p{max_height} / $img->get('height');

            my $ratio;
            $ratio = $height_r < $width_r ? $height_r : $width_r;

            $img->Scale( width  => int( $img->get('width') * $ratio ),
                         height => int( $img->get('height') * $ratio ),
                       );
        }
    }
    elsif ( $p{height} != $self->height
            ||
            $p{width}  != $self->width
          )
    {
        $img->Scale( height => $p{height},
                     width  => $p{width},
                   );
    }

    if ( $p{rotate} )
    {
        $img->Rotate( degrees => $p{rotate} );
    }

    File::Path::mkpath( File::Basename::dirname( $p{output_file} ), 0, 0755 );

    my $q = $img->Get('quality');
    $img->Write( filename => $p{output_file},
                 ( defined $q ? ( quality  => $q ) : () ),
                 type     => 'Palette',
               );
}

sub _caption_file
{
    my $self = shift;

    return $self->{dir}->file( '.' . $self->filename . '.caption' );
}

{
    my $ext =
        ( join '|',
          map { "\Q.$_\E" }
          qw( gif jpg jpeg jpe png )
        );

    sub image_extension_re { qr/(?:$ext)$/i }
}



1;

__END__
