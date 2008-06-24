package My::Codec::Foo;

use Badger::Class
    base    => 'Badger::Codec',
    version => 0.01;

sub encode {
    my ($self, $text) = @_;
    return 'FOO:' . $text;
}

sub decode {
    my ($self, $text) = @_;
    $text =~ s/^FOO://;
    return $text;
}

1;