package Rudesind::Config;

use strict;

use Config::Auto;
use File::Spec;
use Path::Class;


my @Required = qw( root_dir data_dir );

my %Default = ( uri_root   => '/Rudesind',
                image_uri_root        => '',
                raw_image_subdir         => '/images',
                max_upload =>  (1024 ** 2) * 1000,
                view       => 'default',
                temp_dir   => File::Spec->tmpdir,
                charset    => 'UTF-8',
                admin_password  => undef,
                gallery_columns => 3,
                thumbnail_max_height  => 200,
                thumbnail_max_width   => 200,
                image_page_max_height => 400,
                image_page_max_width  => 500,
                error_mode => 'fatal',
              );

$Default{session_directory} =
    Path::Class::dir( $Default{temp_dir}, 'Rudesind-sessions' )->stringify;

foreach my $f ( @Required, keys %Default )
{
    no strict 'refs';
    *{$f} = sub { $_[0]->{$f} };
}

sub new
{
    my $class = shift;
    my $file = shift;

    unless ($file)
    {
        my @files = ( '/etc/Rudesind.conf',
                      '/etc/Rudesind/Rudesind.conf',
                      '/opt/Rudesind/Rudesind.conf',
                    );

        unshift @files, $ENV{RUDESIND_CONFIG} if defined $ENV{RUDESIND_CONFIG};

        unshift @files, Path::Class::file( $ENV{HOME}, '.Rudesind.conf' )
            if $ENV{HOME};

        foreach my $f (@files)
        {
            if ( -r $f )
            {
                $file = $f;
                last;
            }
        }

        die "No config file found.  Maybe you should set the RUDESIND_CONFIG env variable.\n"
            unless defined $file;
    }

    local $Config::Auto::DisablePerl = 1;
    my $config = Config::Auto::parse($file);

    foreach my $f (@Required)
    {
        die "No value supplied for the $f field in the config file at $f.\n"
            unless exists $config->{$f};
    }

    $config->{uri_root} =~ s{/$}{};

    return bless { %Default,
                   %$config,
                   config_file => $file,
                 }, $class;
}

sub config_file { $_[0]->{config_file} }

sub comp_root
{
    my $self = shift;

    my $view = $self->view();

    if ( $view eq 'default' )
    {
        return $self->main_comp_root;
    }
    else
    {
        my $dir = $self->root_dir;

        return [ [ main    => $self->main_comp_root ],
                 [ default => "$dir/default" ],
               ];
    }
}

sub main_comp_root
{
    my $self = shift;

    my $view = $self->view();

    my $dir = $self->root_dir;

    return "$dir/$view";
}

sub image_dir
{
    my $self = shift;

    return Path::Class::dir( $self->root_dir(), $self->raw_image_subdir );
}

sub image_cache_dir
{
    my $self = shift;

    return Path::Class::dir( $self->root_dir(), 'image-cache' );
}


1;

__END__
