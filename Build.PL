
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.4202"
  },
  "configure_requires" => {
    "Module::Build" => "0.4202"
  },
  "dist_abstract" => "Emulate Perls internal handling of \@INC.",
  "dist_author" => [
    "Kent Fredric <kentnl\@cpan.org>"
  ],
  "dist_name" => "Path-ScanINC",
  "dist_version" => "0.010",
  "license" => "perl",
  "module_name" => "Path::ScanINC",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Class::Tiny" => 0,
    "Data::Dump" => 0,
    "Path::Tiny" => 0,
    "Scalar::Util" => 0,
    "Try::Tiny" => 0,
    "perl" => "5.006",
    "strict" => 0,
    "subs" => 0,
    "warnings" => 0
  },
  "script_files" => [],
  "test_requires" => {
    "File::Spec" => 0,
    "FindBin" => 0,
    "List::Util" => 0,
    "Test::Fatal" => 0,
    "Test::More" => "1.001002",
    "lib" => 0
  }
);


my %fallback_build_requires = (
  "File::Spec" => 0,
  "FindBin" => 0,
  "List::Util" => 0,
  "Module::Build" => "0.4202",
  "Test::Fatal" => 0,
  "Test::More" => "1.001002",
  "lib" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
