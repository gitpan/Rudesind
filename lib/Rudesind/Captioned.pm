package Rudesind::Captioned;

use strict;

use File::Slurp ();
use Rudesind;


sub has_caption
{
    my $self = shift;

    return exists $self->{caption} || -e $self->_caption_file;
}

sub caption
{
    my $self = shift;

    return $self->{caption} if exists $self->{caption};

    return unless $self->has_caption;

    my $file = $self->_caption_file;

    my $caption = File::Slurp::read_file( $file . '' );
    chomp $caption;

    return $self->{caption} = $caption;
}

sub save_caption
{
    my $self = shift;
    my $caption = shift;

    delete $self->{caption};

    my $file = $self->_caption_file;
    if ( length $caption )
    {
        open my $fh, '>', $file
            or die "Cannot write to $file: $!";
        print $fh $caption
            or die "Cannot write to $file: $!";
        close $fh;
    }
    else
    {
        return unless -f $file;

        unlink $file
            or die "Cannot unlink $file: $!";
    }
}

sub caption_as_html
{
    my $self = shift;

    return Rudesind::text_to_html( $self->caption );
}


1;

__END__
