package MooseX::Object::Pluggable;
# ABSTRACT: Make your classes pluggable

our $VERSION = '0.0015';

use Carp;
use Moose::Role;
use Module::Runtime 'use_module';
use Scalar::Util 'blessed';
use Try::Tiny;
use Module::Pluggable::Object;
use Moose::Util 'find_meta';
use namespace::autoclean;

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

This module is meant to be loaded as a role from Moose-based classes.
It will add five methods and four attributes to assist you with the loading
and handling of plugins and extensions for plugins. I understand that this may
pollute your namespace, however I took great care in using the least ambiguous
names possible.

=head1 How plugins Work

Plugins and extensions are just Roles by a fancy name. They are loaded at runtime
on demand and are instance, not class based. This means that if you have more than
one instance of a class they can all have different plugins loaded. This is a feature.

Plugin methods are allowed to C<around>, C<before>, C<after>
their consuming classes, so it is important to watch for load order as plugins can
and will overload each other. You may also add attributes through C<has>.

Please note that when you load at runtime you lose the ability to wrap C<BUILD>
and roles using C<has> will not go through compile time checks like C<required>
and C<default>.

Even though C<override> will work, I B<STRONGLY> discourage its use
and a warning will be thrown if you try to use it.
This is closely linked to the way multiple roles being applied is handled and is not
likely to change. C<override> behavior is closely linked to inheritance and thus will
likely not work as you expect it in multiple inheritance situations. Point being,
save yourself the headache.

=head1 How plugins are loaded

When roles are applied at runtime an anonymous class will wrap your class and
C<< $self->blessed >>, C<< ref $self >> and C<< $self->meta->name >>
will no longer return the name of your object;
they will instead return the name of the anonymous class created at runtime.
See C<_original_class_name>.

=head1 Usage

For a simple example see the tests included in this distribution.

=head1 Attributes

=head2 _plugin_ns

String. The prefix to use for plugin names provided. C<MyApp::Plugin> is sensible.

=head2 _plugin_app_ns

An ArrayRef accessor that automatically dereferences into array on a read call.
By default it will be filled with the class name and its precedents. It is used
to determine which directories to look for plugins as well as which plugins
take precedence upon namespace collisions. This allows you to subclass a pluggable
class and still use its plugins while using yours first if they are available.

=head2 _plugin_locator

An automatically built instance of L<Module::Pluggable::Object> used to locate
available plugins.

=head2 _original_class_name

=for stopwords instantiation

Because of the way roles apply, C<< $self->blessed >>, C<< ref $self >>
and C<< $self->meta->name >> will
no longer return what you expect. Instead, upon instantiation, the name of the
class instantiated will be stored in this attribute if you need to access the
name the class held before any runtime roles were applied.

=cut

#--------#---------#---------#---------#---------#---------#---------#---------#

has _plugin_ns => (
  is => 'rw',
  required => 1,
  isa => 'Str',
  default => sub{ 'Plugin' },
);

has _original_class_name => (
  is => 'ro',
  required => 1,
  isa => 'Str',
  default => sub{ blessed($_[0]) },
);

has _plugin_loaded => (
  is => 'rw',
  required => 1,
  isa => 'HashRef',
  default => sub{ {} }
);

has _plugin_app_ns => (
  is => 'rw',
  required => 1,
  isa => 'ArrayRef',
  lazy => 1,
  auto_deref => 1,
  builder => '_build_plugin_app_ns',
  trigger => sub{ $_[0]->_clear_plugin_locator if $_[0]->_has_plugin_locator; },
);

has _plugin_locator => (
  is => 'rw',
  required => 1,
  lazy => 1,
  isa => 'Module::Pluggable::Object',
  clearer => '_clear_plugin_locator',
  predicate => '_has_plugin_locator',
  builder => '_build_plugin_locator'
);

#--------#---------#---------#---------#---------#---------#---------#---------#

=head1 Public Methods

=head2 load_plugins @plugins

=head2 load_plugin $plugin

Load the appropriate role for C<$plugin>.

=cut

sub load_plugins {
    my ($self, @plugins) = @_;
    die("You must provide a plugin name") unless @plugins;

    my $loaded = $self->_plugin_loaded;
    @plugins = grep { not exists $loaded->{$_} } @plugins;

    return if @plugins == 0;

    foreach my $plugin (@plugins)
    {
        my $role = $self->_role_from_plugin($plugin);
        return if not $self->_load_and_apply_role($role);

        $loaded->{$plugin} = $role;
    }

    return 1;
}


sub load_plugin {
  my $self = shift;
  $self->load_plugins(@_);
}

=head1 Private Methods

There's nothing stopping you from using these, but if you are using them
for anything that's not really complicated you are probably doing
something wrong.

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

    croak("Unable to locate plugin '$plugin'") unless @roles;
    return $roles[0] if @roles == 1;

    my $i = 0;
    my %precedence_list = map{ $i++; "${_}::${o}", $i } $self->_plugin_app_ns;

    @roles = sort{ $precedence_list{$a} <=> $precedence_list{$b}} @roles;

    return shift @roles;
}

=head2 _load_and_apply_role @roles

Require C<$role> if it is not already loaded and apply it. This is
the meat of this module.

=cut

sub _load_and_apply_role {
    my ($self, $role) = @_;
    die("You must provide a role name") unless $role;

    try { use_module($role) }
    catch { confess("Failed to load role: ${role} $_") };

    croak("Your plugin '$role' must be a Moose::Role")
        unless find_meta($role)->isa('Moose::Meta::Role');

    carp("Using 'override' is strongly discouraged and may not behave ".
        "as you expect it to. Please use 'around'")
    if scalar keys %{ $role->meta->get_override_method_modifiers_map };

    Moose::Util::apply_all_roles( $self, $role );

    return 1;
}

=head2 _build_plugin_app_ns

Automatically builds the _plugin_app_ns attribute with the classes in the
class precedence list that are not part of Moose.

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

__END__

=pod

=head1 SEE ALSO

=for :list
* L<Moose>
* L<Moose::Role>
* L<Class::Inspector>

=head1 ACKNOWLEDGEMENTS

=for stopwords Stevan

=for :list
* #Moose - Huge number of questions
* Matt S Trout <mst@shadowcatsystems.co.uk> - ideas / planning.
* Stevan Little - EVERYTHING. Without him this would have never happened.
* Shawn M Moore - bugfixes

=cut
