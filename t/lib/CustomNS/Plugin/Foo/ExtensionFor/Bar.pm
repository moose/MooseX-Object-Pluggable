package CustomNS::Plugin::Foo::ExtensionFor::Bar;

use strict;
use warnings;
use Moose::Role;

around bar => sub {
    my ($super, $self) = @_;
    "foo'd bar CNS " . $super->($self);
};

1;
