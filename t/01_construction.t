use strict;
use warnings;

use Test::More 0.96;
use Test::Fatal;

# FILENAME: 01_basic.t
# CREATED: 23/03/12 23:54:55 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Basic tests for the class ( USE / Construct )

use_ok('Path::ScanINC');

is(
	exception {
		my $x = Path::ScanINC->new();
	},
	undef,
	"Basic Construction"
);

is(
	exception {
		my $x = Path::ScanINC->_new();
	},
	undef,
	"Basic Construction via _new"
);

is(
	exception {
		my $x = Path::ScanINC->_new( {} );
	},
	undef,
	"Basic Construction with empty hash"
);

is(
	exception {
		my $x = Path::ScanINC->_new( { x => 'y' } );
	},
	undef,
	"Basic Construction 1 item hash"
);

is(
	exception {
		my $x = Path::ScanINC->_new( x => 'y' );
	},
	undef,
	"Basic Construction 1 item hash as an array"
);

isnt(
	exception {
		my $x = Path::ScanINC->_new('x');
	},
	undef,
	"Basic Construction 1 item non-hash ( die! )"
);

isnt(
	exception {
		my $x = Path::ScanINC->_new( 'x', 'y', 'z' );
	},
	undef,
	"Basic Construction 3 item non-hash ( die! )"
);

is(
	exception {
		my $x = Path::ScanINC->_new( immutable => 1 );
	},
	undef,
	"Set immutable = 1 during construction"
);

is(
	exception {
		my $x = Path::ScanINC->_new( immutable => undef );
	},
	undef,
	"Set immutable = undef during construction"
);

isnt(
	exception {
		my $x = Path::ScanINC->_new( immutable => [] );
	},
	undef,
	"Set immutable = [] during construction ( die! )"
);

is(
	exception {
		my $x = Path::ScanINC->_new( inc => \@INC );
	},
	undef,
	"Set inc = \\\@INC during construction"
);

is(
	exception {
		my $x = Path::ScanINC->_new( inc => [ 'x', 'y', 'z' ] );
	},
	undef,
	"Set inc = [  ] during construction"
);

isnt(
	exception {
		my $x = Path::ScanINC->_new( inc => 'x' );
	},
	undef,
	"Set inc = 'x' during construction ( die! )"
);

done_testing;

