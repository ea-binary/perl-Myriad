package microservice;

use strict;
use warnings;

# VERSION

=head1 NAME

microservice

=head1 SYNOPSIS

 package Example::Service;
 use microservice;

 async method startup {
  $log->infof('Starting %s', __PACKAGE__);
 }

 # Trivial RPC call, provides the `example` method
 async method example : RPC {
  return { ok => 1 };
 }

 # Slightly more useful - return all the original parameters.
 # Due to an unfortunate syntactical choice in core Perl, the
 # whitespace before the (%args) is *mandatory*, without that
 # you're actually passing (%args) to the RPC attribute...
 async method echo : RPC (%args) {
  return \%args;
 }

 # Default internal diagnostics checks are performed automatically,
 # this method is called after the microservice status such as Redis
 # connections, exception status etc. are verified
 async method diagnostics ($level) {
  my ($self, $level) = @_;
  return 'ok';
 }

 1;

=head1 DESCRIPTION

Since this is supposed to be a common standard across all our code, we get to enforce a few
language features:

=over 4

=item * L<strict>

=item * L<warnings>

=item * L<utf8>

=item * L<perlsub/signatures>

=item * no L<indirect>

=item * L<Syntax::Keyword::Try>

=item * L<Syntax::Keyword::Dynamically>

=item * L<Future::AsyncAwait>

=item * provides L<Scalar::Util/blessed>, L<Scalar::Util/weaken>, L<Scalar::Util/refaddr>

=back

This also makes available a L<Log::Any> instance in the C<$log> package variable.

=cut

no indirect;
use mro;
use Future::AsyncAwait;
use Syntax::Keyword::Try;
use Syntax::Keyword::Dynamically;
use Object::Pad;
use Scalar::Util;

use Heap;
use IO::Async::Notifier;
use IO::Async::SSL;
use Net::Async::HTTP;

use Myriad::Service;

use Log::Any qw($log);

sub import {
    my ($called_on) = @_;
    my $class = __PACKAGE__;
    my $pkg = caller(0);

    # Apply core syntax and rules
    strict->import;
    warnings->import;
    utf8->import;
    feature->import(':5.26');
    indirect->unimport(qw(fatal));
    # This one's needed for nested scope, e.g. { package XX; use microservice; method xxx (%args) ... }
    experimental->import('signatures');
    mro::set_mro($pkg => 'c3');

    # Helper functions which are used often enough to be valuable as a default
    Scalar::Util->export_to_level(1, $pkg, qw(refaddr blessed weaken));

    # Some well-designed modules provide direct support for import target
    Syntax::Keyword::Try->import_into($pkg);
    Syntax::Keyword::Dynamically->import_into($pkg);
    Future::AsyncAwait->import_into($pkg);

    # For history here, see this:
    # https://rt.cpan.org/Ticket/Display.html?id=132337
    # At the time of writing, ->begin_class is undocumented
    # but can be seen in action in this test:
    # https://metacpan.org/source/PEVANS/Object-Pad-0.21/t/70mop-create-class.t#L30
    Object::Pad->import_into($pkg);
    Object::Pad->begin_class($pkg, extends => 'Myriad::Service');

    {
        no strict 'refs';
        # Essentially the same as importing Log::Any qw($log) for now,
        # but we may want to customise this with some additional attributes.
        # Note that we have to store a ref to the returned value, don't
        # drop that backslash...
        *{$pkg . '::log'} = \Log::Any->get_logger(
            category => $pkg
        );
    }
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.

