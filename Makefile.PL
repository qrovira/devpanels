use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::DevPanels',
  VERSION_FROM => 'lib/Mojolicious/Plugin/DevPanels.pm',
  AUTHOR       => 'Quim Rovira <met@cpan.org>',
  PREREQ_PM    => {'Mojolicious' => '6.26'},
  test         => {TESTS => 't/*.t'}
);
