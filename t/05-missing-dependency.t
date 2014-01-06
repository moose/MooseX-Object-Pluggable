#! /usr/bin/perl

use Test::More;
use Test::Warn;
use lib 't/lib';

use warnings;
use strict;

plan tests => 5;

use_ok('TestApp3');

my $app = TestApp3->new;

my $res;
warning_like(sub {$res = $app->load_plugin('Foo')}, qr/Failed to load/i, 'loading plugin with missing dependency produces warning');
ok(!$res, 'loading plugin with missing dependency returns false');

ok($app->load_plugins('Baz', 'Bar'), 'loading plugins returns true if some plugins load correctly');
ok($app->can('bar'), 'loading of plugins continues after error');
