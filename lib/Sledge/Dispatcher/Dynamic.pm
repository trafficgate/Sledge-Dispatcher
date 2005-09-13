package Sledge::Dispatcher::Dynamic;
# $Id$

use strict;

require Sledge::Dispatcher;
use base qw(Sledge::Dispatcher);

use Sledge::Exceptions;

sub do_determine {
    my($class, $r, $dir) = @_;

    my @class = grep length, split /\//, $dir;
    if (! @class and my $root = $r->dir_config('SledgeRootDirClassName')) {
	@class = ($root);
    }

    my $base = $r->dir_config('SledgeBaseClass')
	or Sledge::Exception::ConfigKeyUndefined->throw('PerlSetVar SledgeBaseClass needed');
    my $loadclass = join('::', $base, map { $class->_capitalize($_) } @class);
    return $loadclass;
}

sub _capitalize {
    my($class, $ent) = @_;

    # foo_bar => FooBar
    my $cap = ucfirst $ent;
    $cap =~ s/_(\w)/uc($1)/eg;
    return $cap;
}

1;
__END__

=head1 NAME

Sledge::Dispatcher::Dynamic - auto-dispatch mod_perl handler

=head1 SYNOPSIS

  <Location />
  SetHandler perl-script
  PerlHandler Sledge::Dispatcher::Dynamic
  PerlSetVar SledgeBaseClass MyProject::Pages
  PerlSetVar SledgeRootDirClassName Index
  </Location>

=head1 AUTHOR

Tatsuhiko Miyagawa with Sledge developers.

=cut

