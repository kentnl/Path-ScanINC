use strict;
use warnings;

package Path::ScanINC;

# ABSTRACT: Emulate Perls internal handling of @INC.

=head1 SYNOPSIS

The Aim of this module is to fully implement everything Perl does with C<@INC>, to be feature compatible with it, including
the behaviour with regard to C<sub refs> in C<@INC>.


	use Path::ScanINC;

	# Normal usage.
	my $inc = Path::ScanINC->new( );

	# In case you need something that isn't @INC
	# but works like it

	my $inc = Path::ScanINC->new( inc => \@INC );

	# Freeze the value of @INC at the time of object instantiation
	# with regard to behaviour so later changes to @INC have no effect

	my $inc = Path::ScanINC->new( immutable => 1 );

	# Return the first file in @INC that matches.

	my $file = $inc->first_file('Path', 'ScanINC.pm' );

	# Find all possible versions of modules in @INC
	my ( @files ) = $inc->all_files('Path', 'ScanINC.pm');

	# Try to discover a File::ShareDir 'module' root.
	my $dir = $inc->first_dir('auto','share','module');

	# Should return the same as File::ShareDir::module_dir('Path::ScanINC')
	# ( assuming such a directory existed, which there is presently no plans of )
	my $dir = $inc->first_dir('auto','share','module','Path-ScanINC');


	# Find All File::ShareDir roots in @INC
	my ( @dirs ) = $inc->all_dirs('auto', 'share');

=head1 REF SUPPORT IN @INC

This module has elemental support for discovery of results in C<@INC> using C<CODE>/C<ARRAY>/C<BLESSED> entries in
C<@INC>. However, due to a limitation as to how perl itself implements this functionality, the best we can do at present
is simply return what the above are expected to return. This means if you have any of the above ref-types in C<@INC>,
and one of those returns C<a true value>, you'll get handed back an C<ARRAY> reference instead of the file you were
expecting.

Fortunately, C<@INC> barely ever has refs in it. But in the event you I<need> to work with refs in C<@INC> and you
expect that those refs will return C<true>, you have to pick one of two options, either :

=over 4

=item a. Write your code to work with the C<array-ref> returned by the respective reference on a match

=item b. Use the C<all_> family of methods and try pretendeding that there are no C<array-refs> in the list it returns.

=back

Its possible in a future release we may have better choices how to handle this situation in future, but don't bet on it.

Given that the API as defined by Perl mandates C<code-ref>'s return lists containing C<file-handles> or iterative
C<code-ref>'s , not actual files, the best I can forsee at this time we'd be able to do to make life easier for you is
creating a fake library somewhere in a C<tempdir> and stuffing the result of the C<code-ref>'s into files in that dir
prior to returning a path to the generated file.

( And it also tells me that they have to be "Real" file handles, not tied or blessed ones, so being able to ask a
filehandle what file it represents is equally slim.... if that is of course what you require )

For more details, see L<< C<perldoc perlfunc> or C<perldoc -f require> |perlfunc/require >>.

=cut

# Sub Lazy-Aliases

sub __try(&;@) {
	require Try::Tiny;
	goto \&Try::Tiny::try;
}

sub __catch(&;@) {
	require Try::Tiny;
	goto \&Try::Tiny::catch;
}

sub __blessed($) {
	require Scalar::Util;
	goto \&Scalar::Util::blessed;
}

sub __reftype($) {
	require Scalar::Util;
	goto \&Scalar::Util::reftype;
}

sub __pp {
	require Data::Dump;
	goto \&Data::Dump::pp;
}

sub __croak {
	require Carp;
	goto \&Carp::croak;
}

sub __croakf {
	require Carp;
	my $str = sprintf @_;
	@_ = ($str);
	goto \&Carp::croak;
}

sub __check_package_method {
	my ( $package, $method ) = @_;
	if ( not defined $package ) {
		__croakf( '%s::%s should be called as %s->%s( @args )', __PACKAGE__, $method, __PACKAGE__, $method );
	}
}

sub __check_object_method {
	my ( $object, $method ) = @_;
	if ( not defined $object ) {
		__croakf( '%s::%s should be called as $object->%s( @args )', __PACKAGE__, $method, $method );
	}
	if ( not ref $object ) {
		__croakf( '%s::%s should be called as $object->%s( @args )', __PACKAGE__, $method, $method );
	}
	if ( not __blessed $object ) {
		__croakf( '%s::%s should be called as $object->%s( @args ) not %s::%s( $unblessed_ref, @args )',
			__PACKAGE__, $method, $method, __PACKAGE__, $method );
	}
}

sub new {
	my ( $class, @args ) = @_;
	__check_package_method( $class, 'new' );
	return $class->_new(@args);
}

sub _new {
	my ( $class, @args ) = @_;
	__check_package_method( $class, '_new' );
	my $ref = {};
	my $obj = bless $ref, $class;
	my $config;
	if ( @args == 1 ) {
		if ( not ref $args[0] or not __try { my $i = $args[0]->{'key'}; 1 } __catch { undef } ) {
			__croakf(
				'%s->new( @args ) expects either %s->new( x => y, x => y ) or %s->new({ x => y, x => y }). '
					. '  You gave: %s->new( %s )',
				$class, $class, $class, $class, __pp(@args)
			);
		}
		$config = $args[0];
	}
	else {
		if ( @args % 2 != 0 ) {
			__croakf(
				'%s->new( @args ) expects either %s->new( x => y, x => y ) or %s->new({ x => y, x => y }). '
					. '  You gave: %s->new( %s )',
				$class, $class, $class, $class, __pp(@args)
			);
		}
		$config = {@args};
	}
	$obj->_init_immutable($config);
	$obj->_init_inc($config);
	return $obj;
}

sub immutable {
	my ( $obj, @args ) = @_;
	__check_object_method( $obj, 'immutable' );
	return   if ( not exists $obj->{immutable} );
	return 1 if $obj->{immutable};
	return;
}

sub _init_immutable {
	my ( $obj, $config ) = @_;
	__check_object_method( $obj, '_init_immutable' );
	if ( exists $config->{immutable} ) {
		if ( not ref $config->{immutable} ) {
			$obj->{immutable} = !!( $config->{immutable} );
		}
		else {
			__croakf(
				'Initialization parameter \'%s\' to $object->new( ) ( %s->new() ) expects %s.'
					. '   You gave $object->new( immutable => %s )',
				'immutable',
				__blessed($obj),
				'a truthy(boolean-like) scalar',
				__pp( $config->{immutable} )
			);
		}
	}
}

sub inc {
	my ( $obj, @args ) = @_;
	__check_object_method( $obj, 'inc' );
	return @INC if ( not exists $obj->{inc} );
	return @{ $obj->{inc} };
}

sub _init_inc {
	my ( $obj, $config ) = @_;
	__check_object_method( $obj, '_init_inc' );
	if ( exists $config->{inc} ) {
		if ( not __try { my $i = $config->{inc}->[0]; 1 } __catch { undef } ) {
			__croakf(
				'Initialization parameter \'%s\' to $object->new( ) ( %s->new() ) expects %s.'
					. '   You gave $object->new( immutable => %s )',
				'inc',
				__blessed($obj),
				'an array-reference',
				__pp( $config->{immutable} )
			);
		}
		$obj->{inc} = $config->{inc};
	}
	if ( $obj->immutable ) {
		if ( exists $obj->{inc} ) {
			$obj->{inc} = [ @{ $obj->{inc} } ];
		}
		else {
			$obj->{inc} = [@INC];
		}
	}

}

sub _ref_expand {
	my ( $self, $ref, $query ) = @_;
	__check_object_method( $self, '_ref_expand' );

	# See perldoc perlfunc / require
	if ( __blessed($ref) ) {
		my (@result) = $ref->INC($query);
		if ( not @result ) {
			return [ undef, ];
		}
		return [ 1, @result ];
	}
	if ( __reftype($ref) eq 'CODE' ) {
		my (@result) = $ref->( $ref, $query );
		if ( not @result ) {
			return [ undef, ];
		}
		return [ 1, @result ];
	}
	if ( __reftype($ref) eq 'ARRAY' ) {
		my $code = $ref->[0];
		my (@result) = $code->( $ref, $query );
		if ( not @result ) {
			return [ undef, ];
		}
		return [ 1, @result ];
	}

	__croakf( 'Unknown type of ref in @INC not supported: %s', __reftype($ref) );
	return [ undef, ];
}

sub first_file {
	my ( $self, @args ) = @_;
	__check_object_method( $self, 'first_file' );

	require File::Spec;
	my $suffix = File::Spec->catfile(@args);

	for my $path ( $self->inc ) {
		if ( ref $path ) {
			my $result = $self->_ref_expand( $path, $suffix );
			if ( $result->[0] ) {
				shift @{$result};
				return $result;
			}
			next;
		}
		my $fullpath = File::Spec->catfile( $path, $suffix );
		if ( -e $fullpath and -f $fullpath ) {
			return $fullpath;
		}
	}
	return;
}

sub all_files {
	my ( $self, @args ) = @_;
	__check_object_method( $self, 'all_files' );
	require File::Spec;
	my $suffix = File::Spec->catfile(@args);
	my @out;
	for my $path ( $self->inc ) {
		if ( ref $path ) {
			my $result = $self->_ref_expand( $path, $suffix );
			if ( $result->[0] ) {
				shift @{$result};
				push @out, $result;
			}
			next;
		}
		require File::Spec;
		my $fullpath = File::Spec->catfile( $path, $suffix );
		if ( -e $fullpath and -f $fullpath ) {
			push @out, $fullpath;
		}
	}
	return @out;
}

sub first_dir {
	my ( $self, @args ) = @_;
	__check_object_method( $self, 'first_dir' );
	require File::Spec;
	my $suffix = File::Spec->catdir(@args);
	for my $path ( $self->inc ) {
		if ( ref $path ) {
			my $result = $self->_ref_expand( $path, $suffix );
			if ( $result->[0] ) {
				shift @{$result};
				return $result;
			}
			next;
		}
		my $fullpath = File::Spec->catdir( $path, $suffix );
		if ( -e $fullpath and -d $fullpath ) {
			return $fullpath;
		}
	}
	return;
}

sub all_dirs {
	my ( $self, @args ) = @_;
	__check_object_method( $self, 'all_dirs' );
	require File::Spec;
	my $suffix = File::Spec->catdir(@args);
	my @out;
	for my $path ( $self->inc ) {
		if ( ref $path ) {
			my $result = $self->_ref_expand( $path, $suffix );
			if ( $result->[0] ) {
				shift @{$result};
				push @out, $result;
			}
			next;
		}
		my $fullpath = File::Spec->catdir( $path, $suffix );
		if ( -e $fullpath and -d $fullpath ) {
			push @out, $fullpath;
		}
	}
	return @out;
}

1;
