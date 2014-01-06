#! /usr/bin/perl

use Test::More;
use Test::Warnings 'warning';
use lib 't/lib';

use warnings;
use strict;

use_ok('TestApp3');

my $app = TestApp3->new;

my $res;
my $warning = warning {$res = $app->load_plugin('Foo')};
like($warning, qr/Failed to load/i, 'loading plugin with missing dependency produces warning');

ok(!$res, 'loading plugin with missing dependency returns false');

$res = warning {$app->load_plugins('Baz', 'Bar')};
ok($res, 'loading plugins returns true if some plugins load correctly');
ok($app->can('bar'), 'loading of plugins continues after error');

ok(!exists $app->_plugin_loaded->{'Foo'}, 'Foo was not added to loaded plugin list');
ok(!exists $app->_plugin_loaded->{'Baz'}, 'Baz was not added to loaded plugin list');
ok(exists $app->_plugin_loaded->{'Bar'}, 'Bar was added to loaded plugin list');

done_testing;
