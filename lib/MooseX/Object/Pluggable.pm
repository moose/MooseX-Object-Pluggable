package MooseX::Object::Pluggable;

use Carp;
use strict;
use warnings;
use Moose::Role;
use Class::Inspector;


our $VERSION = '0.0002';

=head1 NAME

    MooseX::Object::Pluggable - Make your classes pluggable

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This module is meant to be loaded as a role from Moose-based classes
it will add five methods and five attributes to assist you with the loading
and handling of plugins and extensions for plugins. I understand that this may
pollute your namespace, however I took great care in using the least ambiguous
names possible.

=head1 How plugins Work

Plugins and extensions are just Roles by a fancy name. They are loaded at runtime
on demand and are instance, not class based. This means that if you have more than
one instance of a class they can all have different plugins loaded. This is a feature.

Plugin methods are allowed to C<around>, C<before>, C<after>
their consuming classes, so it is important to watch for load order as plugins can
and will overload each other. You may also add attributes through has.

Even thouch C<override> will work in basic cases, I STRONGLY discourage it's use 
and a warning will be thrown if you try to use it.
This is closely linked to the way multiple roles being applies is handles and is not
likely to change. C<override> bevavior is closely linked to inheritance and thus will
likely not work as you expect it in multiple inheritance situations. Point being,
save yourself the headache.

=head1 How plugins are loaded

You don't really need to understand anything except for the first paragraph. 

The first time you load a plugin a new anonymous L<Moose::Meta::Class> will be
created. This class will inherit from your pluggable object and then your object
will be reblessed to an instance of this anonymous class. This means that 
C<$self-E<gt>blessed> and C<ref $self> will no longer return the name of your object,
they will instead return the name of the anonymous class created at runtime. Your
original class name can be located at C<($self-E<gt>meta-E<gt>superclasses)[0]>

Once the anonymous subclass exists all plugin roles will be C<apply>ed to this class
directly. This "subclass" though is in fact now C<$self> and it C<isa($yourclassname)>.
 If this is confusing.. it should be, thats why you let me handle it. Just know that it
has to be done this way in order for plugins to override core functionality.

=head1

For a simple example see the tests for this distribution.

=head1 Attributes

=head2 _plugin_ns

String. The prefix to use for plugin names provided. MyApp::Plugin is sensible.

=head2 _plugin_ext

Boolean. Indicates whether we should attempt to load plugin extensions.
Defaults to true;

=head2 _plugin_ext_ns

String. The namespace plugin extensions have. Defaults to 'ExtensionFor'.

This means that is _plugin_ns is "MyApp::Plugin" and _plugin_ext_ns is
"ExtensionFor" loading plugin "Bar" would search for extensions in
"MyApp::Plugin::Bar::ExtensionFor::*". 

=head2 _plugin_loaded

HashRef. Keeps an inventory of what plugins are loaded and what the actual
module name is to avoid multiple loading.

=head2 __plugin_subclass

Object. This holds the subclass of our pluggable object in the form of an
anonymous L<Moose::Meta::Class> instance. All roles are actually applied to 
this instance instead of the original class instance in order to not lose
the original object name as roles are applied. The anonymous class will be
automatically generated upon first use.

=cut

#--------#---------#---------#---------#---------#---------#---------#---------#

has _plugin_ns     => (is => 'rw', required => 1, isa => 'Str', 
                       default => 'Plugin');

has _plugin_ext    => (is => 'rw', required => 1, isa => 'Bool',
	               default => 1);
has _plugin_ext_ns => (is => 'rw', required => 1, isa => 'Str', 
		       default => 'ExtensionFor');
has _plugin_loaded => (is => 'rw', required => 1, isa => 'HashRef', 
		       default => sub{ {} });

has __plugin_subclass => ( is => 'rw', required => 0, isa => 'Object', );

#--------#---------#---------#---------#---------#---------#---------#---------#

=head1 Public Methods

=head2 load_plugin $plugin

This is the only method you should be using.
Load the apropriate role for C<$plugin> as well as any 
extensions it provides if extensions are enabled.

=cut

sub load_plugin{
    my ($self, $plugin) = @_;
    die("You must provide a plugin name") unless $plugin;

    my $loaded = $self->_plugin_loaded;
    return 1 if exists $loaded->{$plugin};
    
    my $role = $self->_role_from_plugin($plugin);

    $loaded->{$plugin} = $role      if $self->_load_and_apply_role($role);
    $self->load_plugin_ext($plugin) if $self->_plugin_ext;

    return exists $loaded->{$plugin};
}


=head2 _load_plugin_ext

Will load any extensions for a particular plugin. This should be called 
automatically by C<load_plugin> so you don't need to worry about it.
It basically attempts to load any extension that exists for a plugin 
that is already loaded. The only reason for using this is if you want to
keep _plugin_ext as false and only load extensions manually, which I don't
recommend.

=cut

sub load_plugin_ext{
    my ($self, $plugin) = @_;
    die("You must provide a plugin name") unless $plugin;
    my $role = $self->_role_from_plugin($plugin);

    # $p for plugin, $r for role
    while( my($p,$r) = each %{ $self->_plugin_loaded }){
	my $ext = join "::", $role, $self->_plugin_ext_ns, $p;	

	$self->_load_and_apply_role( $ext ) 
	    if Class::Inspector->installed($ext);

	#go back to prev loaded modules and load extensions for current module?
	#my $ext2 = join "::", $r, $self->_plugin_ext_ns, $plugin;
	#$self->_load_and_apply_role( $ext2 ) 
	#    if Class::Inspector->installed($ext2);
    }
}

=head1 Private Methods

There's nothing stopping you from using these, but if you are using them 
you are probably doing something wrong.

=head2 _plugin_subclass

Creates, if needed and returns the anonymous instance of the consuming objects 
subclass to which roles will be applied to.

=cut

sub _plugin_subclass{
    my $self = shift;
    my $anon_class = $self->__plugin_subclass;

    #initialize if we havnt been initialized already.
    unless(ref $anon_class && $self->meta->is_anon_class){

	#create an anon class that inherits from $self that plugins can be 
	#applied to safely and store it within the $self instance.
	$anon_class = Moose::Meta::Class->
	    create_anon_class(superclasses => [$self->meta->name]);
	$self->__plugin_subclass( $anon_class );

	#rebless $self as the anon class which now inherits from ourselves
	#this allows the anon class to override methods in the consuming
	#class while keeping a stable name and set of superclasses
	bless $self => $anon_class->name 
	    unless $self->meta->name eq $anon_class->name;
    }
    
    return $anon_class;
}

=head2 _role_from_plugin $plugin

Creates a role name from a plugin name. If the plugin name is prepended 
with a C<+> it will be treated as a full name returned as is. Otherwise
a string consisting of C<$plugin>  prepended with the application name 
and C<_plugin_ns> will be returned. Example
   
   #assuming appname MyApp and C<_plugin_ns> 'Plugin'   
   $self->_role_from_plugin("MyPlugin"); # MyApp::Plugin::MyPlugin

=cut

sub _role_from_plugin{
    my ($self, $plugin) = @_;

    my $name = $self->meta->is_anon_class ? 
	($self->meta->superclasses)[0] : $self->blessed;

    $plugin =~ /^\+(.*)/ ? $1 : join '::', $name, $self->_plugin_ns, $plugin;
}

=head2 _load_and_apply_role $role

Require C<$role> if it is not already loaded and apply it to 
C<_plugin_subclass>. This is the meat of this module.

=cut

sub _load_and_apply_role{
    my ($self, $role) = @_;
    die("You must provide a role name") unless $role;

    #Throw exception if plugin is not installed
    die("$role is not available on this system") 
	unless Class::Inspector->installed($role);

    #don't re-require...
    unless( Class::Inspector->loaded($role) ){
	eval "require $role" || die("Failed to load role: $role");
    }

    carp("Using 'override' is strongly discouraged and may not behave ".
	 "as you expect it to. Please use 'around'")
	if scalar keys %{ $role->meta->get_override_method_modifiers_map };   

    #apply the plugin to the anon subclass
    die("Failed to apply plugin: $role") 
	unless $role->meta->apply( $self->_plugin_subclass );

    return 1;
}


1;

__END__;

=head1 SEE ALSO

L<Moose>, L<Moose::Role>

=head1 AUTHOR

Guillermo Roditi, <groditi@cpan.org>

=head1 BUGS

Holler?

Please report any bugs or feature requests to
C<bug-moosex-object-pluggable at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MooseX-Object-Pluggable>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MooseX-Object-Pluggable

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MooseX-Object-Pluggable>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MooseX-Object-Pluggable>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MooseX-Object-Pluggable>

=item * Search CPAN

L<http://search.cpan.org/dist/MooseX-Object-Pluggable>

=back

=head1 ACKNOWLEDGEMENTS

=over 4

=item #Moose - Huge number of questions

=item Matt S Trout <mst@shadowcatsystems.co.uk> - ideas / planning.

=item Stevan Little - EVERYTHING. Without him this would have never happened.

=back

=head1 COPYRIGHT

Copyright 2007 Guillermo Roditi.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut
