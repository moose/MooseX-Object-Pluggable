package TestApp2::Plugin::Foo::ExtensionFor::Bar;

use strict;
use warnings;
use Moose::Role;

around bar => sub {
    my ($super, $self) = @_;
    "foo'd bar 2 " . $super->($self);
};

1;
