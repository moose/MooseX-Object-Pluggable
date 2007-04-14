#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use lib 't/lib';

plan tests => 22;

use_ok('TestApp2');

my $app = TestApp2->new;

is($app->_role_from_plugin('+'.$_), $_)
    for(qw/MyPrettyPlugin My::Pretty::Plugin/);

is($app->_role_from_plugin($_), 'TestApp2::Plugin::'.$_)
    for(qw/Foo/);

is($app->_role_from_plugin($_), 'TestApp::Plugin::'.$_)
    for(qw/Bar/);

$app->_plugin_app_ns(['CustomNS', $app->_plugin_app_ns]);

is($app->_role_from_plugin($_), 'CustomNS::Plugin::'.$_)
    for(qw/Foo/);

is($app->_role_from_plugin($_), 'TestApp::Plugin::'.$_)
    for(qw/Bar/);

is( $app->foo, "original foo", 'original foo value');
is( $app->bar, "original bar", 'original bar value');
is( $app->bor, "original bor", 'original bor value');

ok($app->load_plugin('Bar'), "Loaded Bar");
is( $app->bar, "override bar", 'overridden bar via plugin');

ok($app->load_plugin('Baz'), "Loaded Baz");
is( $app->baz, "plugin baz", 'added baz via plugin');
is( $app->bar, "baz'd bar  override bar", 'baz extension for bar using around');

ok($app->load_plugin('Foo'), "Loaded Foo");
is( $app->foo, "around foo CNS", 'around foo via plugin');
is( $app->bar, "foo'd bar CNS baz'd bar  override bar", 'foo extension around baz extension for bar');
is( $app->baz, "foo'd baz CNS plugin baz", 'foo extension override for baz');

ok($app->load_plugin('+TestApp::Plugin::Bor'), "Loaded Bor");
is( $app->foo, "bor'd foo  around foo CNS", 'bor extension override for foo');
is( $app->bor, "plugin bor", 'override bor via plugin');
