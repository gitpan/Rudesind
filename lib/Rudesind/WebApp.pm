package Rudesind::WebApp;

use base 'MasonX::WebApp';

use Apache::Session::Wrapper;
use File::Path ();
use Rudesind::Config;


__PACKAGE__->UseSession(1);
__PACKAGE__->ActionURIPrefix('/submit/');


sub _init
{
    my $self = shift;

    $self->{config} = Rudesind::Config->new;

    $self->_make_session_wrapper;
}

sub config { $_[0]->{config} }

sub _make_session_wrapper
{
    my $self = shift;

    return unless $self->{config};

    my %p = ( class     => 'Flex',
              store     => 'File',
              lock      => 'File',
              generate  => 'MD5',
              serialize => 'Storable',
              use_cookie  => 1,
              cookie_name => 'Rudesind-session',
              cookie_path => '/',
            );

    $p{directory} = $self->config->session_directory;
    $p{lock_directory} = $self->config->session_directory;

    File::Path::mkpath( $p{directory}, 0, 0700 )
        unless -d $p{directory};

    $self->{wrapper} = Apache::Session::Wrapper->new(%p);
}

sub session_wrapper { $_[0]->{wrapper} }

sub is_admin
{
    my $self = shift;

    if ( defined $self->apache_req->connection->user ? 1 : 0 )
    {
        $self->session->{admin} = 1;
        $self->session->{basic_auth} = 1;
    }

    return $self->session->{admin} ? 1 : 0;
}

sub basic_auth { $_[0]->session->{basic_auth} }

sub _redirect_from_args
{
    my $self = shift;

    $self->redirect( uri => ( $self->args->{redirect_to}
                              ? $self->args->{redirect_to}
                              : $_[0] )
                   );
}

sub login
{
    my $self = shift;

    $self->_handle_error( error => 'No password defined in config file',
                          uri   => $self->config->uri_root . '/admin/login.mhtml',
                        )
        unless defined $self->config->admin_password;

    $self->_handle_error( error => 'Incorrect password',
                          uri   => $self->config->uri_root . '/admin/login.mhtml',
                        )
        unless $self->args->{password} eq $self->config->admin_password;

    $self->session->{admin} = 1;

    $self->_add_message( 'Admin login was successful.' );

    $self->_redirect_from_args( $self->config->uri_root . '/' );
}

sub logout
{
    my $self = shift;

    $self->session->{admin} = 0;

    $self->_add_message( 'Logout was successful.' );

    $self->_redirect_from_args( $self->config->uri_root . '/' );
}

sub edit_caption
{
    my $self = shift;

    $self->redirect( uri => $self->config->uri_root . '/' )
        unless $self->is_admin;

    my ( $dir, $image ) =
        Rudesind::new_from_path( $self->args->{path}, $self->config );
    my $thing = $image ? $image : $dir;

    $thing->save_caption( $self->args->{caption} );

    if ( length $self->args->{caption} )
    {
        $self->_add_message( 'Caption was edited.' );
    }
    else
    {
        $self->_add_message( 'Caption was deleted.' );
    }

    $self->_redirect_from_args( $self->config->uri_root . '/' );
}


1;

__END__

