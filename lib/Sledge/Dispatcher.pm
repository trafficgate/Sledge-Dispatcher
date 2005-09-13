package Sledge::Dispatcher;
# $Id$

use strict;
use vars qw($VERSION);
$VERSION = 0.09;

use Apache::Constants qw(:common);
use Apache::Log;
use File::Basename;
use Sledge::Exceptions;

use vars qw($DEBUG);
$DEBUG = 0;

my %loaded;

sub debug {
    my ($r, $args) = @_;
    chomp($args);
    $r->log->warn($args) if $DEBUG;
}

sub _load_module {
    my($class, $r, $module) = @_;
    debug($r, "loading $module");
    return if $loaded{$module};

    no strict 'refs';
    eval "require $module";
    if ($@ && $@ !~ /Can't locate/) {
	debug($r, "error loading $module: $@");
	die $@;
    } elsif ($@) {
	debug($r, "erorr loading $module: $@");
    }
    $loaded{$module} = 1;
}

sub null_method { }

sub determine {
    my($class, $r) = @_;

    # we can ignore extensions!
    my $ext = $r->dir_config('SledgeExtension') || '.cgi';

    # for static .html
    my $static = $r->dir_config('SledgeStaticExtension') || '.html';

    # determine directory and page name
    my($page, $dir, $suf) = File::Basename::fileparse($r->uri, $ext, $static);

    # don't match with $ext and $static
    if (index($page, '.') >= 0) {
	debug($r, "$page doesn't match with $ext and $static");
	return;
    }

    # <Location /foo>: /foo/bar => /bar
    (my $location = $r->location) =~ s!/$!!;
    $dir =~ s/^$location// if $location;
    $dir =~ s!/$!!;		# remove trailing slash

    my $loadclass = $class->do_determine($r, $dir);
    return $loadclass, $page, $suf eq $static, ($page eq '' && $suf eq '');
}


sub handler ($$) {
    my($class, $r) = @_;
    my($loadclass, $page, $is_static, $slash) = $class->determine($r);
    unless ($loadclass) {
	debug($r, "Can't determine loadclass");
	return DECLINED;
    };

    debug($r, "loadclass is $loadclass, page is $page");

    $class->_load_module($r, $loadclass);

    my $no_static = uc($r->dir_config('SledgeDispatchStatic') || 'On') eq 'OFF';
    if ($is_static && !$class->_generated($loadclass, $page)) {
	debug($r, 'static method, but not yet auto-generated');
	if ($no_static || $loadclass->can("dispatch_$page")) {
	    debug($r, "dispatch_$page exists, but access is $page.html");
	    return DECLINED;
	} else {
	    $class->_generate_method($r, $loadclass, $page);
	}
    } elsif ($slash) {
	my @indexes = $r->dir_config('SledgeDirectoryIndex') ?
	    split(/\s+/, $r->dir_config('SledgeDirectoryIndex')) : 'index';
	debug($r, "indexes: ", join(",", @indexes));
	for my $index (@indexes) {
	    if ($loadclass->can("dispatch_$index")) {
		debug($r, "$loadclass can do $index");
		$page = $index;
		last;
	    }
	}
	$page ||= $indexes[0];
	debug($r, "page is $page");

	if (!$loadclass->can("dispatch_$page")) {
	    if ($no_static) {
		debug($r, "access to slash, but no_static is on");
		return DECLINED;
	    }
	    $class->_generate_method($r, $loadclass, $page);
	}
    } elsif (!$is_static && $class->_generated($loadclass, $page)) {
	debug($r, "access to dynamic after static method $page made");
	return DECLINED;
    }

    unless ($loadclass->can("dispatch_$page")) {
	debug($r, "$loadclass can't do $page");
	return DECLINED;
    }

    debug($r, "ok now loading $loadclass - $page");
    $loadclass->new->dispatch($page);

    return OK;
}

my %generated;

sub _generate_method {
    my($class, $r, $loadclass, $page) = @_;
    debug($r, "generating $page on $loadclass");
    no strict 'refs';
    if (-e $loadclass->guess_filename($page)) {
	*{"$loadclass\::dispatch_$page"} = \&null_method;
	$generated{$loadclass, $page} = 1;
    }
}

sub _generated {
    my($class, $loadclass, $page) = @_;
    return $generated{$loadclass, $page};
}

sub do_determine { Sledge::Exception::AbstractMethod->throw }

1;
__END__

=head1 NAME

Sledge::Dispatcher - auto-dispatch mod_perl handler

=head1 SYNOPSIS

B<DO NOT USE THIS MODULE DIRECTORY>.

See L<Sledge::Dispatcher::Properties> or
L<Sledge::Dispatcher::Dynamic> for actual usage.

=head1 AUTHOR

Tatsuhiko Miyagawa with Sledge developers.

=cut

