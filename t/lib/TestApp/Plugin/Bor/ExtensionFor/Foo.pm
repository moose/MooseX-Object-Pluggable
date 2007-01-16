package TestApp::Plugin::Bor::ExtensionFor::Foo;

use strict;
use warnings;
use Moose::Role;

around foo => sub{ 
    my $super = shift;
    my $self = shift;
    "bor'd foo  " . $super->($self);
};

1;
