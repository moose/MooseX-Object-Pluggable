package TestApp::Plugin::Baz::ExtensionFor::Bar;

use strict;
use warnings;
use Moose::Role;

around bar => sub{ 
    my ($super, $self) = @_;
    "baz'd bar  " . $super->($self);
};

1;
