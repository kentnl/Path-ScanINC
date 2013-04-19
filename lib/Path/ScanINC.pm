use strict;
use warnings;

package Path::ScanINC;
BEGIN {
  $Path::ScanINC::AUTHORITY = 'cpan:KENTNL';
}
{
  $Path::ScanINC::VERSION = '0.003';
}

# ABSTRACT: Emulate Perls internal handling of @INC.


# Sub Lazy-Aliases

## no critic (ProhibitSubroutinePrototypes)
sub __try(&;@)   { require Try::Tiny;    goto \&Try::Tiny::try; }
sub __catch(&;@) { require Try::Tiny;    goto \&Try::Tiny::catch; }
sub __blessed($) { require Scalar::Util; goto \&Scalar::Util::blessed; }
sub __reftype($) { require Scalar::Util; goto \&Scalar::Util::reftype; }
## use critic
sub __pp    { require Data::Dump; goto \&Data::Dump::pp; }
sub __croak { require Carp;       goto \&Carp::croak; }

## no critic (RequireArgUnpacking)
sub __croakf { require Carp; my $str = sprintf @_; @_ = ($str); goto \&Carp::croak; }
## use critic

# Basically check $_[0] is a valid package
#
# sub foo {
#   __check_package_method( $_[0], 'WantedPkg', 'foo' );
# }
#
sub __check_package_method {
	my ( $package, $want_pkg, $method ) = @_;
	return 1 if defined $package and $package->ISA($want_pkg);

	## no critic (RequireInterpolationOfMetachars)
	my $format = qq[%s\n%s::%s should be called as %s->%s( \@args )];

	return __croakf( $format, q[Invocant is undefined], $want_pkg, $method, $want_pkg, $method ) if not defined $package;
	return __croakf( $format, qq[Invocant is not ISA $want_pkg], $want_pkg, $method, $want_pkg, $method )
		if not $package->ISA($want_pkg);
	return __croakf( $format, q[unknown reason], $want_pkg, $method, $want_pkg, $method );
}

# Check $_[0] is an object.
#
# sub bar {
#    __check_object_method( $_[0] , __PACKAGE__, 'bar' );
# }
#
sub __check_object_method {
	my ( $object, $want_pkg, $method ) = @_;
	return 1 if defined $object and ref $object and __blessed($object);

	my $format = qq[%s\n%s::%s should be called as \$object->%s( \@args )];

	return __croakf( $format, q[Invocant is undefined],       $want_pkg, $method, $method ) if not defined $object;
	return __croakf( $format, q[Invocant is not a reference], $want_pkg, $method, $method ) if not ref $object;
	return __croakf( $format, q[Invocant is not blessed],     $want_pkg, $method, $method ) if not __blessed($object);

	return __croakf( $format, q[unknown reason], $want_pkg, $method, $method ) if not defined $object;

}

sub _path_normalise {
	my ( $object, @args ) = @_;
	require File::Spec;
	my $suffix = File::Spec->catdir(@args);
	my $inc_suffix = join q{/}, @args;
	return ( $suffix, $inc_suffix );
}


sub new {
	my ( $class, @args ) = @_;
	__check_package_method( $class, __PACKAGE__, 'new' );
	return $class->_new(@args);
}

sub _new {
	my ( $class, @args ) = @_;
	__check_package_method( $class, __PACKAGE__, '_new' );
	my $ref = {};
	my $obj = bless $ref, $class;
	my $config;
	if ( @args == 1 ) {
		if ( not ref $args[0] or not __try { my $i = $args[0]->{'key'}; 1 } __catch { undef } ) {
			## no critic (RequireInterpolationOfMetachars)
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
			## no critic (RequireInterpolationOfMetachars)
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
	__check_object_method( $obj, __PACKAGE__, 'immutable' );
	return   if ( not exists $obj->{immutable} );
	return 1 if $obj->{immutable};
	return;
}

sub _init_immutable {
	my ( $obj, $config ) = @_;
	__check_object_method( $obj, __PACKAGE__, '_init_immutable' );
	if ( exists $config->{immutable} ) {
		if ( not ref $config->{immutable} ) {
			$obj->{immutable} = !!( $config->{immutable} );
		}
		else {
			## no critic (RequireInterpolationOfMetachars)

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
	return $obj;
}


sub inc {
	my ( $obj, @args ) = @_;
	__check_object_method( $obj, __PACKAGE__, 'inc' );
	return @INC if ( not exists $obj->{inc} );
	return @{ $obj->{inc} };
}

sub _init_inc {
	my ( $obj, $config ) = @_;
	__check_object_method( $obj, __PACKAGE__, '_init_inc' );
	if ( exists $config->{inc} ) {
		if ( not __try { my $i = $config->{inc}->[0]; 1 } __catch { undef } ) {
			## no critic (RequireInterpolationOfMetachars)
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
	return $obj;
}

sub _ref_expand {
	my ( $self, $ref, $query ) = @_;
	__check_object_method( $self, __PACKAGE__, '_ref_expand' );

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
	## no critic (RequireInterpolationOfMetachars)

	__croakf( 'Unknown type of ref in @INC not supported: %s', __reftype($ref) );
	return [ undef, ];
}


sub first_file {
	my ( $self, @args ) = @_;
	__check_object_method( $self, __PACKAGE__, 'first_file' );

	my ( $suffix, $inc_suffix ) = $self->_path_normalise(@args);

	for my $path ( $self->inc ) {
		if ( ref $path ) {
			my $result = $self->_ref_expand( $path, $inc_suffix );
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
	__check_object_method( $self, __PACKAGE__, 'all_files' );

	my ( $suffix, $inc_suffix ) = $self->_path_normalise(@args);

	my @out;
	for my $path ( $self->inc ) {
		if ( ref $path ) {
			my $result = $self->_ref_expand( $path, $inc_suffix );
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
	__check_object_method( $self, __PACKAGE__, 'first_dir' );
	my ( $suffix, $inc_suffix ) = $self->_path_normalise(@args);

	for my $path ( $self->inc ) {
		if ( ref $path ) {
			my $result = $self->_ref_expand( $path, $inc_suffix );
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
	__check_object_method( $self, __PACKAGE__, 'all_dirs' );
	my ( $suffix, $inc_suffix ) = $self->_path_normalise(@args);
	my @out;
	for my $path ( $self->inc ) {
		if ( ref $path ) {
			my $result = $self->_ref_expand( $path, $inc_suffix );
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

__END__

=pod

=encoding utf-8

=head1 NAME

Path::ScanINC - Emulate Perls internal handling of @INC.

=head1 VERSION

version 0.003

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

=head1 METHODS

=head2 new

	my $object = $class->new(
		 inc => [ 'x', 'y', 'z' , ],
		 immutable => 1 | undef
	);

=head2 immutable

	if( $inc->immutable ) {
		print "We're working with a snapshotted version of @INC";
	}

=head2 inc

	for my $i ( $inc->inc ) {
		say "Plain: $incer" if not ref $incer;
		say "Callback: $incer" if ref $incer;
	}

Returns a copy of the internal version of C<@INC> it will be using.

If the object is C<immutable>, then this method will continue to report the same value as c<@INC>, or will be updated
every time the orignal array reference passed during construction gets updated:

	my $ref = [];
	my $a = Path::ScanINC->new( inc => $ref );
	my $b = Path::ScanINC->new( inc => $ref, immutable => 1 );

	push @{$ref} , 'a';

	is( [ $a->inc ]->[0] , 'a' , "non-immutable references keep tracking their original" );
	isnt( [ $b->inc ]->[0] , 'a' , "immutable references are shallow-copied at construction" );

Do note of course that is a B<SHALLOW> copy, so if you have multiple C<@INC> copies sharing the same C<array>/C<bless>
references, changes to those references will be shared amongst all C<@INC>'s .

=head2 first_file

	if( defined ( my $file = $inc->first_file('Moose.pm') ) {
		print "Yep, Moose seems to be available in \@INC , its at $file, but its not loaded (yet)\n";
	}

This proves to be a handy little gem that replaces the oft used

	if( try { require Moose ; 1 } ){
		Yadayadayada
	}

And adds the benefit of not needing to actually source the file to see if it exists or not.

=head4 B<IMPORTANT>: PORTABILITIY

For best system portability, where possible, its suggested you specify paths as arrays
of strings, not slash-separatad strings.

	$inc->first_file('MooseX' , 'Declare.pm')  # Good
	$inc->first_file('MooseX/Declare.pm')      # Bad.

This is for several reasons, all of which can be summarised as "Windows".

=over 4

=item * C<%INC> keys all use Unix notation.

=item * C<@INC> callbacks expect Unix notataion.

=item * C<\> is a valid path part on Unix.

=item * On Win32, we have to use C<\> Separation, not C</> for resolving physical files.

=back

The sum of these means if you do this:

	$inc->first_file('MooseX/Declare.pm')

On win32, it might just end up doing:

	C:\some\path\here/MooseX/Declare.pm

Which may or may not work.

And additionally, if the above module is loaded, it will be loaded as

	"MooseX/Declare.pm"

in C<%INC>, not what you'd expect, C<MooseX\Declare.pm>

=head2 all_files

Returns all matches in all C<@INC> paths.

	my $inc = Path::ScanINC->new();
	push @INC, 'lib';
	my ( @files ) = $inc->all_files('Something','Im','Working','On.pm');
	pp(\@files );

	# [
	#    '/something/........./lib/Something/Im/Working/On.pm',
	#    '/something/....../share/per5/lib/site_perl/5.15.9/Something/Im/Working/On.pm',
	# ]

Chances are if you understand how this can be useful, you'll do so immediately.

Useful for debugging what module is being loaded, and possibly introspecting information about
multiple parallel installs of modules in C<%ENV>, such as frequently the case with 'dual-life' modules.

	perl -MPath::ScanINC -E 'my $scanner = Path::ScanINC->new(); say for $scanner->all_files(qw( Scalar Util.pm ))'
	/usr/lib64/perl5/vendor_perl/5.12.4/x86_64-linux/Scalar/Util.pm
	/usr/lib64/perl5/5.12.4/x86_64-linux/Scalar/Util.pm

Sort-of like ye' olde' C<perldoc -l>, but more like C<man -a>

I might even be tempted to make a sub-module to make one-liners easier like

	perl -MPath::ScanINC::All=Scalar/Util.pm

B<REMINDER>: If there are C<REFS> in C<@INC> that match, they'll return C<array-ref>'s, not strings.

=head2 first_dir

Just like C<first_file> except for locating directories.

=head2 all_dirs

Just like C<all_dirs> except for locating directories.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
