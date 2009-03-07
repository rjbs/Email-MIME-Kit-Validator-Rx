package Email::MIME::Kit::Validator::Rx;
use Moose;
with 'Email::MIME::Kit::Role::Validator';
# ABSTRACT: validate assembly stash with Rx (from JSON in kit)

use Data::Rx 0.007;
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

has rx => (
  is  => 'ro',
  isa => class_type('Data::Rx'),
  lazy     => 1,
  init_arg => undef,
  builder  => 'build_default_rx_object',
);

sub build_default_rx_object {
  my ($self) = @_;
  my $rx = Data::Rx->new({
    prefix       => $self->prefix,
  });

  for my $plugin ($self->all_default_type_plugins, $self->type_plugins) {
    eval "require $plugin; 1" or die;
    $rx->register_type_plugin($plugin);
  }

  my $prefix = $self->prefix;
  for my $key (keys %$prefix) {
    $rx->add_prefix($key, $prefix->{ $key });
  }

  return $rx;
}

sub all_default_type_plugins {
  # shamlessly stolen from Moose::Object::BUILDALL -- rjbs, 2009-03-06
  my ($self) = @_;
  my @plugins;
  for my $method (
    reverse
    $self->meta->find_all_methods_by_name('accumulate_default_type_plugins')
  ) {
    push @plugins, $method->{code}->execute($self);
  }

  return @plugins;
}

sub accumulate_default_type_plugins {
  return ('Data::Rx::TypeBundle::Perl');
}

has schema => (
  reader   => 'schema',
  writer   => '_set_schema',
  isa      => 'Object', # It'd be nice to have a better TC -- rjbs, 2009-03-06
  init_arg => undef,
);

has schema_struct => (
  reader    => '_schema_struct',
  init_arg  => 'schema',
);

has schema_path => (
  reader    => '_schema_path',
  writer    => '_set_schema_path',
  isa       => 'Str',
  init_arg  => 'path',
);

has combine => (
  is          => 'ro',
  initializer => sub {
    my ($self, $value, $set) = @_;
    confess "invalid combine logic: $value"
      unless defined $value and $value eq 'all';
    $set->($value);
  },
);

sub BUILD {
  my ($self) = @_;

  $self->_do_goofy_schema_initialization;
}

sub _do_goofy_schema_initialization {
  my ($self) = @_;

  my @paths = grep { defined } ref $self->_schema_path
            ? @{ $self->_schema_path }
            : $self->_schema_path;

  my @structs = grep { defined } (ref $self->_schema_struct eq 'ARRAY')
              ? @{ $self->_schema_struct }
              : $self->_schema_struct;

  confess("multiple schemata provided but no combine logic given")
    if @paths + @structs > 1 and ! $self->combine;

  @paths = ('rx.json') unless @paths or @structs;

  for my $path (@paths) {
    # Sure, someday we can add another decoder layer here to allow schemata in
    # YAML.  Whatever. -- rjbs, 2009-03-06
    my $rx_json_ref = $self->kit->get_kit_entry($path);
    my $rx_data = JSON->new->decode($$rx_json_ref);
    push @structs, $rx_data;
  }

  my $schema = @structs > 1
             ? $self->rx->make_schema({ type => '//all', of => \@structs })
             : $self->rx->make_schema($structs[0]);

  $self->_set_schema($schema);
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
