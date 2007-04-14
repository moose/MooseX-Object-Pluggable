package MooseX::Object::Pluggable;

use Carp;
use strict;
use warnings;
use Moose::Role;
use Class::MOP;
use Module::Pluggable::Object;

our $VERSION = '0.0005';

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
it will add five methods and four attributes to assist you with the loading
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

Please note that when you load at runtime you lose the ability to wrap C<BUILD>
and roles using C<has> will not go through comile time checks like C<required>
and <default>.

Even though C<override> will work , I STRONGLY discourage it's use 
and a warning will be thrown if you try to use it.
This is closely linked to the way multiple roles being applies is handles and is not
likely to change. C<override> bevavior is closely linked to inheritance and thus will
likely not work as you expect it in multiple inheritance situations. Point being,
save yourself the headache.

=head1 How plugins are loaded

When roles are applied at runtime an anonymous class will wrap your class and
C<$self-E<gt>blessed> and C<ref $self> will no longer return the name of your object,
they will instead return the name of the anonymous class created at runtime.
See C<_original_class_name>.

=head1 Usage

For a simple example see the tests included in this distribution.

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

=head2 _plugin_app_ns

ArrayRef, Accessor automatically dereferences into array on a read call.
By default will be filled with the class name and it's prescedents, it is used
to determine which directories to look for plugins as well as which plugins
take presedence upon namespace collitions. This allows you to subclass a pluggable
class and still use it's plugins while using yours first if they are available.

=cut

=head2 _plugin_locator

An automatically built instance of L<Module::Pluggable::Object> used to locate
available plugins.

=cut

#--------#---------#---------#---------#---------#---------#---------#---------#

has _plugin_ns      => (is => 'rw', required => 1, isa => 'Str', 
                        default => 'Plugin');
has _plugin_ext     => (is => 'rw', required => 1, isa => 'Bool',
	                default => 1);
has _plugin_ext_ns  => (is => 'rw', required => 1, isa => 'Str', 
		        default => 'ExtensionFor');
has _plugin_loaded  => (is => 'rw', required => 1, isa => 'HashRef', 
		        default => sub{ {} });
has _plugin_app_ns  => (is => 'rw', required => 1, isa => 'ArrayRef', lazy => 1, 
                        auto_deref => 1, 
                        default => sub{ shift->_build_plugin_app_ns },
                        trigger => sub{ $_[0]->_clear_plugin_locator 
                                         if $_[0]->_has_plugin_locator; },
                       );
has _plugin_locator => (is => 'rw', required => 1, lazy => 1, 
                        isa       => 'Module::Pluggable::Object', 
		        clearer   => '_clear_plugin_locator',
                        predicate => '_has_plugin_locator',
                        default   => sub{ shift->_build_plugin_locator });

#--------#---------#---------#---------#---------#---------#---------#---------#

=head1 Public Methods

=head2 load_plugin $plugin

This is the only method you should be using. Load the apropriate role for 
C<$plugin> as well as any extensions it provides if extensions are enabled.

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


=head2 load_plugin_ext

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
    my $role = $self->_plugin_loaded->{$plugin};

    # $p for plugin, $r for role
    while( my($p,$r) = each %{ $self->_plugin_loaded }){

	my $ext = join "::", $role, $self->_plugin_ext_ns, $p;	
	if( $plugin =~ /^\+(.*)/ ){
	    eval{ $self->_load_and_apply_role( $ext ) };
	} else{
	    $self->_load_and_apply_role( $ext ) if
		grep{ /^${ext}$/ } $self->_plugin_locator->plugins;	
        }
	
	#go back to prev loaded modules and load extensions for current module?
	#my $ext2 = join "::", $r, $self->_plugin_ext_ns, $plugin;
	#$self->_load_and_apply_role( $ext2 ) 
	#    if Class::Inspector->installed($ext2);
    }
}

=head2 _original_class_name

Because of the way roles apply C<$self-E<gt>blessed> and C<ref $self> will
no longer return what you expect. Instead use this class to get your original
class name.

=cut

sub _original_class_name{
    my $self = shift;
    return (grep {$_ !~ /^Moose::/} $self->meta->class_precedence_list)[0];
}


=head1 Private Methods

There's nothing stopping you from using these, but if you are using them 
for anything thats not really complicated you are probably doing 
something wrong. Some of these may be inlined in the future if performance
becomes an issue (which I doubt).

=head2 _role_from_plugin $plugin

Creates a role name from a plugin name. If the plugin name is prepended 
with a C<+> it will be treated as a full name returned as is. Otherwise
a string consisting of C<$plugin>  prepended with the C<_plugin_ns> 
and the first valid value from C<_plugin_app_ns> will be returned. Example
   
   #assuming appname MyApp and C<_plugin_ns> 'Plugin'   
   $self->_role_from_plugin("MyPlugin"); # MyApp::Plugin::MyPlugin

=cut

sub _role_from_plugin{
    my ($self, $plugin) = @_;

    return $1 if( $plugin =~ /^\+(.*)/ );

    my $o = join '::', $self->_plugin_ns, $plugin;
    #Father, please forgive me for I have sinned. 
    my @roles = grep{ /${o}$/ } $self->_plugin_locator->plugins;
    
    die("Unable to locate plugin") unless @roles;
    return $roles[0] if @roles == 1;
    
    my $i = 0;
    my %presedence_list = map{ $i++; "${_}::${o}", $i } $self->_plugin_app_ns;
    
    @roles = sort{ $presedence_list{$a} <=> $presedence_list{$b}} @roles;

    return shift @roles;    
}

=head2 _load_and_apply_role $role

Require C<$role> if it is not already loaded and apply it. This is
the meat of this module.

=cut

sub _load_and_apply_role{
    my ($self, $role) = @_;
    die("You must provide a role name") unless $role;

    #don't re-require...
    unless( Class::MOP::is_class_loaded($role) ){
	eval Class::MOP::load_class($role) || die("Failed to load role: $role");
    }

    carp("Using 'override' is strongly discouraged and may not behave ".
	 "as you expect it to. Please use 'around'")
	if scalar keys %{ $role->meta->get_override_method_modifiers_map };   

    #apply the plugin to the anon subclass
    die("Failed to apply plugin: $role") 
	unless $role->meta->apply( $self );

    return 1;
}

=head2 _build_plugin_app_ns

Automatically builds the _plugin_app_ns attribute with the classes in the
class presedence list that are not part of Moose.

=cut

sub _build_plugin_app_ns{
    my $self = shift;
    my @names = (grep {$_ !~ /^Moose::/} $self->meta->class_precedence_list);
    return \@names;
}

=head2 _build_plugin_locator

Automatically creates a L<Module::Pluggable::Object> instance with the correct
search_path.

=cut

sub _build_plugin_locator{
    my $self = shift;

    my $locator = Module::Pluggable::Object->new
	( search_path => 
	  [ map { join '::', ($_, $self->_plugin_ns) } $self->_plugin_app_ns ] 
	);
    return $locator;    
}

=head2 meta

Keep tests happy. See L<Moose>

=cut

1;

__END__;

=head1 SEE ALSO

L<Moose>, L<Moose::Role>, L<Class::Inspector>

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
