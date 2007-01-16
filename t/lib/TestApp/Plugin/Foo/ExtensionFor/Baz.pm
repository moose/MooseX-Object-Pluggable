package TestApp::Plugin::Foo::ExtensionFor::Baz;

use strict;
use warnings;
use Moose::Role;

around baz => sub{ 
    my $super = shift;
    my $self = shift;
    "foo'd baz  " . $super->($self);
};

1;
