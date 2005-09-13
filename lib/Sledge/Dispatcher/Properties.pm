package Sledge::Dispatcher::Properties;
# $Id$

use strict;
require Sledge::Dispatcher;
use base qw(Sledge::Dispatcher);

use Data::Properties;
use FileHandle;
use UNIVERSAL::require;

my %Cache;

sub load_property {
    my($class, $r, $path) = @_;
    if (!$Cache{$path} ||
	($class->_reload($r) && ($Cache{$path}->[1] < _mtime($path)))) {
	my $props  = Data::Properties->new;
	my $handle = FileHandle->new($path) or
	    Sledge::Exception::PropertiesNotFound->throw("$path: $!");
	$props->load($handle);
	$class->init_modules($props);
	$Cache{$path} = [ $props, _mtime($path) ];
    }
    return $Cache{$path}->[0];
}

sub _reload {
    my($class, $r) = @_;
    my $reload = $r->dir_config('SledgeMapReload');
    return !(defined $reload && uc($reload) eq 'OFF');
}

sub init_modules {
    my($class, $props) = @_;
    for my $name ($props->property_names) {
	my $module = $props->get_property($name);
	$module->require or die $UNIVERSAL::require::ERROR;
    }
}

sub _mtime { (stat(shift))[9] }

sub do_determine {
    my($class, $r, $dir) = @_;

    # load property file
    my $map_path = $r->dir_config('SledgeMapFile')
	or Sledge::Exception::MapFileUndefined->throw;
    my $props = $class->load_property($r, Apache->server_root_relative($map_path));

    return $props->get_property($dir) || $props->get_property("$dir/");
}

1;
__END__

=head1 NAME

Sledge::Dispatcher::Properties - auto-dispatch mod_perl handler

=head1 SYNOPSIS

  <Location />
  SetHandler perl-script
  PerlHandler Sledge::Dispatcher::Properties
  PerlSetVar SledgeMapFile conf/map.props
  # default is On
  PerlSetVar SledgeDispatchStatic Off
  # defauls is On
  PerlSetVar SledgeMapReload Off
  </Location>

  # map.props
  / = My::Pages::Index
  /bar = My::Pages::Bar

  # http://localhost/
  # => My::Pages::Index->new->dispatch('index')
  # http://localhost/bar/baz
  # => My::Pages::Bar->new->dispatch('baz')

  # like Struts!
  <Location /webapp>
  SetHandler perl-script
  PerlHandler Sledge::Dispatcher::Properties
  PerlSetVar SledgeMapFile conf/map.props
  PerlSetVar SledgeExtension .do
  </Location>

  # map.props
  # you DON'T need /webapp here!!!
  / = My::Pages::Index

  # then access http://localhost/webapp/bar.do
  # => My::Pages::Index->new->dispatch('bar')

=head1 AUTHOR

Tatsuhiko Miyagawa with Sledge developers.

=cut
