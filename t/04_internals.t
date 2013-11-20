use strict;
use warnings;

use Test::More 0.98;
use FindBin;

use lib "$FindBin::Bin/lib";

use winfail;

use_ok('Path::ScanINC');

subtest __try => sub {
	will_win 'exceptions not fatal to caller';
	t { Path::ScanINC::__try( sub { die 'not a problem' } ) };
};

subtest __catch => sub {
	will_win 'exceptions not fatal to caller';

	my $caught;

	t { Path::ScanINC::__try( sub { die 'not a problem' }, Path::ScanINC::__catch( sub { $caught = $_ } ) ) };

	like( $caught, qr/^\Qnot a problem\E/, 'Catch still works' );

};

subtest __blessed => sub {
	will_win 'blessed loads ok';

	my $object = bless( {}, 'foo' );
	my $gotbless;

	t { $gotbless = Path::ScanINC::__blessed($object) };

	is( $gotbless, 'foo', '__blessed resolves ok' );
};

subtest __reftype => sub {
	will_win 'reftype loads ok';

	my $gotreftype;

	t { $gotreftype = Path::ScanINC::__reftype( [] ) };

	is( $gotreftype, 'ARRAY', '__reftype resolves ok' );

};

subtest __pp => sub {
	will_win 'pp loads ok';

	my $gotdump;

	t { $gotdump = Path::ScanINC::__pp( [] ) };

	is( $gotdump, '[]', '__pp resolves ok' );
};

subtest __croak => sub {

	will_fail 'croak loads ok ';

	t { Path::ScanINC::__croak("its ok") };
};

subtest __croakf => sub {
	will_fail 'basic croakf';
	t { Path::ScanINC::__croakf('test') };
};

subtest _path_normalise => sub {

	will_win 'can call _path_normalise';

	my ( $suffix, $inc_suffix );

	t { ( $suffix, $inc_suffix ) = Path::ScanINC->_path_normalise( 'a', 'b', 'c' ) };

	is( $inc_suffix, 'a/b/c', 'inc_suffix computation works' );
};

done_testing;

