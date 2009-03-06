package Email::MIME::Kit::Validator::Rx;
use Moose;
with 'Email::MIME::Kit::Role::Validator';
# ABSTRACT: validate assembly stash with Rx (from JSON in kit)

use Data::Rx;
use Data::Rx::TypeBundle::Perl 0.002;
use Moose::Util::TypeConstraints;

use JSON;

has prefix => (
  is  => 'ro',
  isa => 'HashRef',
  default => sub { {} },
);

has type_plugins => (
  is  => 'ro',
  isa => 'ArrayRef[Str]',
  default    => sub { [] },
  auto_deref => 1,
);

has schema => (
  is  => 'ro',
  isa => 'Object',
  lazy     => 1,
  init_arg => undef,
  default  => sub {
    my ($self) = @_;

    my $rx_json_ref = $self->kit->get_kit_entry('rx.json');
    my $rx_data = JSON->new->decode($$rx_json_ref);
    $self->rx->make_schema($rx_data);
  },
);

has rx => (
  is  => 'ro',
  isa => class_type('Data::Rx'),
  lazy     => 1,
  init_arg => undef,
  default  => sub {
    my ($self) = @_;

    my $rx = Data::Rx->new({
      prefix       => $self->prefix,
      type_plugins => [
        'Data::Rx::TypeBundle::Perl',
      ],
    });

    for my $plugin ($self->type_plugins) {
      eval "require $plugin; 1" or die;
      $rx->register_type_plugin($plugin);
    }

    return $rx;
  },
);

sub BUILD {
  my ($self) = @_;
  # we force schema construction now to get it as early as possible
  $self->schema;
}

sub validate {
  my ($self, $stash) = @_;
  Carp::confess("assembly parameters don't pass validation")
    unless $self->schema->check($stash);

  return 1;
}

no Moose;
no Moose::Util::TypeConstraints;
__PACKAGE__->meta->make_immutable;
1;
