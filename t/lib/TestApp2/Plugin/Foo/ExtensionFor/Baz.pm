package TestApp2::Plugin::Foo::ExtensionFor::Baz;

use strict;
use warnings;
use Moose::Role;

around baz => sub{ 
    my $super = shift;
    my $self = shift;
    "foo'd baz 2 " . $super->($self);
};

1;
