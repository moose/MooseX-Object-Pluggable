#! /usr/bin/perl -w

# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name 'MooseX-Object-Pluggable';
abstract 'Add plugin support to your Moose classes via roles.';
all_from 'lib/MooseX/Object/Pluggable.pm';

# Specific dependencies
requires 'Moose'                      => 0.17;
requires 'Module::Pluggable::Object'  => 0;

build_requires 'Test::More'   => 0;

#no_index directory => 'dist';
    
auto_install;
WriteAll;
