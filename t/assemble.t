use strict;
use warnings;

use Test::More 'no_plan';
use lib 't/lib';

use Email::MIME::Kit;

{
  package TestFriend;
  sub new  { bless { name => $_[1] } => $_[0] }
  sub name { return $_[0]->{name} }
}

my $kit = Email::MIME::Kit->new({
  source => 't/kits/test.mkit',
});

sub assemble_ok {
  my ($desc, $want_ok, $stash) = @_;

  my $ok  = eval { $kit->assemble($stash); 1 };
  my $err = $@;
  $ok ||= 0;

  my $verb = $want_ok ? 'pass' : 'fail';
  ok($ok == $want_ok, "$desc should $verb")
    or diag "error: $@";
}

assemble_ok(
  first => 1 => {
    friend   => TestFriend->new('Jimbo Johnson'),
    how_long => '10 years',
  },
);

assemble_ok(
  'non-object' => 0 => {
    friend   => 'TestFriend',
    how_long => '10 years',
  },
);

assemble_ok(
  "no optional" => 1 => {
    friend   => TestFriend->new('Ricardo'),
  },
);
