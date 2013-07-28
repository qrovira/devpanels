use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin 'DevPanels';

get '/' => sub {
  my $self = shift;
  $self->render(text => 'Hello Mojo!');
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)->content_like(qr/Hello Mojo!.*<!-- Mojolicious development panels -->/s);

# Missing proper tests

done_testing();
