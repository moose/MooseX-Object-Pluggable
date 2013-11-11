# NAME

MooseX::Object::Pluggable - Make your classes pluggable

# VERSION

version 0.0012

# SYNOPSIS

    package MyApp;
    use Moose;

    with 'MooseX::Object::Pluggable';

    ...

    package MyApp::Plugin::Pretty;
    use Moose::Role;

    sub pretty{ print "I am pretty" }

    1;

    #
    use MyApp;
    my $app = MyApp->new;
    $app->load_plugin('Pretty');
    $app->pretty;

# DESCRIPTION

This module is meant to be loaded as a role from Moose-based classes
it will add five methods and four attributes to assist you with the loading
and handling of plugins and extensions for plugins. I understand that this may
pollute your namespace, however I took great care in using the least ambiguous
names possible.

# How plugins Work

Plugins and extensions are just Roles by a fancy name. They are loaded at runtime
on demand and are instance, not class based. This means that if you have more than
one instance of a class they can all have different plugins loaded. This is a feature.

Plugin methods are allowed to `around`, `before`, `after`
their consuming classes, so it is important to watch for load order as plugins can
and will overload each other. You may also add attributes through has.

Please note that when you load at runtime you lose the ability to wrap `BUILD`
and roles using `has` will not go through compile time checks like `required`
and <default>.

Even though `override` will work , I STRONGLY discourage it's use
and a warning will be thrown if you try to use it.
This is closely linked to the way multiple roles being applied is handled and is not
likely to change. `override` behavior is closely linked to inheritance and thus will
likely not work as you expect it in multiple inheritance situations. Point being,
save yourself the headache.

# How plugins are loaded

When roles are applied at runtime an anonymous class will wrap your class and
`$self->blessed` and `ref $self` will no longer return the name of your object,
they will instead return the name of the anonymous class created at runtime.
See `_original_class_name`.

# Usage

For a simple example see the tests included in this distribution.

# Attributes

## \_plugin\_ns

String. The prefix to use for plugin names provided. MyApp::Plugin is sensible.

## \_plugin\_app\_ns

ArrayRef, Accessor automatically dereferences into array on a read call.
By default will be filled with the class name and its precedents, it is used
to determine which directories to look for plugins as well as which plugins
take precedence upon namespace collisions. This allows you to subclass a pluggable
class and still use it's plugins while using yours first if they are available.

## \_plugin\_locator

An automatically built instance of [Module::Pluggable::Object](http://search.cpan.org/perldoc?Module::Pluggable::Object) used to locate
available plugins.

## \_original\_class\_name

Because of the way roles apply `$self->blessed` and `ref $self` will
no longer return what you expect. Instead, upon instantiation, the name of the
class instantiated will be stored in this attribute if you need to access the
name the class held before any runtime roles were applied.

# Public Methods

## load\_plugins @plugins

## load\_plugin $plugin

Load the appropriate role for `$plugin`.

# Private Methods

There's nothing stopping you from using these, but if you are using them
for anything that's not really complicated you are probably doing
something wrong.

## \_role\_from\_plugin $plugin

Creates a role name from a plugin name. If the plugin name is prepended
with a `+` it will be treated as a full name returned as is. Otherwise
a string consisting of `$plugin`  prepended with the `_plugin_ns`
and the first valid value from `_plugin_app_ns` will be returned. Example

    #assuming appname MyApp and C<_plugin_ns> 'Plugin'
    $self->_role_from_plugin("MyPlugin"); # MyApp::Plugin::MyPlugin

## \_load\_and\_apply\_role @roles

Require `$role` if it is not already loaded and apply it. This is
the meat of this module.

## \_build\_plugin\_app\_ns

Automatically builds the \_plugin\_app\_ns attribute with the classes in the
class precedence list that are not part of Moose.

## \_build\_plugin\_locator

Automatically creates a [Module::Pluggable::Object](http://search.cpan.org/perldoc?Module::Pluggable::Object) instance with the correct
search\_path.

## meta

Keep tests happy. See [Moose](http://search.cpan.org/perldoc?Moose)

# SEE ALSO

[Moose](http://search.cpan.org/perldoc?Moose), [Moose::Role](http://search.cpan.org/perldoc?Moose::Role), [Class::Inspector](http://search.cpan.org/perldoc?Class::Inspector)

# BUGS

Holler?

Please report any bugs or feature requests to
`bug-MooseX-Object-Pluggable at rt.cpan.org`, or through the web interface at
[http://rt.cpan.org/Public/Dist/Display.html?Name=MooseX-Object-Pluggable](http://rt.cpan.org/Public/Dist/Display.html?Name=MooseX-Object-Pluggable).
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MooseX-Object-Pluggable

You can also look for information at:

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/MooseX-Object-Pluggable](http://annocpan.org/dist/MooseX-Object-Pluggable)

- CPAN Ratings

    [http://cpanratings.perl.org/d/MooseX-Object-Pluggable](http://cpanratings.perl.org/d/MooseX-Object-Pluggable)

- RT: CPAN's request tracker

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=MooseX-Object-Pluggable](http://rt.cpan.org/NoAuth/Bugs.html?Dist=MooseX-Object-Pluggable)

- Search CPAN

    [http://search.cpan.org/dist/MooseX-Object-Pluggable](http://search.cpan.org/dist/MooseX-Object-Pluggable)

# ACKNOWLEDGEMENTS

- \#Moose - Huge number of questions
- Matt S Trout <mst@shadowcatsystems.co.uk> - ideas / planning.
- Stevan Little - EVERYTHING. Without him this would have never happened.
- Shawn M Moore - bugfixes

# AUTHOR

Guillermo Roditi <groditi@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2007 by Guillermo Roditi <groditi@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
