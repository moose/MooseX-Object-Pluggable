package CustomNS::Plugin::Foo::ExtensionFor::Baz;

use strict;
use warnings;
use Moose::Role;

around baz => sub{ 
    my $super = shift;
    my $self = shift;
    "foo'd baz CNS " . $super->($self);
};

1;
