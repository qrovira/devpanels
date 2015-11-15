package Mojolicious::Plugin::DevPanels;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON qw/ encode_json /;

our $VERSION = '0.01';

has panels => sub {
    my $self = shift;
    return {
        log => sub {
            my $c = shift;
            my $logs = $self->logs;
            $self->logs({});

            return $logs;
        },
        stash => sub {
            my $c = shift;
            my @keys = grep !/^(:?mojo\.|config|devpanels)/ => keys %{ $c->stash };

            return { map { $_ => $c->stash($_) } @keys };
        },
        mojo_flags => sub {
            my $c = shift;
            my @keys = grep /^mojo\./ => keys %{ $c->stash };

            return { map { $_ => $c->stash($_) } @keys };
        },
        session => sub {
            my $c = shift;

            return $c->session;
        },
        config => sub {
            my $c = shift;

            return $c->config;
        },
    };
};

has logs => sub { return {}; };

sub register {
    my ($self, $app, $opts) = @_;

    push @{ $app->renderer->classes }, ref( $self );

    foreach my $panel ( keys %{ $opts || [] } ) {
        $self->panels->{ $panel } = $opts->{$panel};
    }

    $self->hook_log($app)
        if $self->panels->{log};

    $app->helper(
        devpanel => sub {
            my $c = shift;
            my $name = shift;
            my $data = shift;

            $c->stash->{devpanels}{$name} = $data;
        }
    );

    $app->hook(
        after_dispatch => sub {
            my $c = shift;
            my $logs = $self->logs;

            # Leave static content untouched
            return if $c->stash('mojo.static');

            # Do not allow if not development mode
            return if $app->mode ne 'development';

            # Mangle only html documents if possible
            return unless $c->res->headers->content_type =~ /html/;

            my %data = ();
            while( my ($panel, $gen) = each %{ $self->panels } ) {
                next unless ref($gen);

                my $out = $gen->($c);
                
                $data{$panel} = $out if defined $out;
            }

            my $extra_panels = $c->stash('devpanels');
            foreach my $panel ( keys %{ $extra_panels // {} } ) {
                $data{ $panel } = $extra_panels->{ $panel };
            }

            $c->res->body(
                $c->res->body .
                $c->render_to_string( 'devpanels', panels => \%data, json_panels => encode_json(\%data) )
            );
        }
    );
}

# Log panel
sub hook_log {
    my ($self, $app) = @_;

    # override Mojo::Log->log
    no strict 'refs';
    my $stash = \%{"Mojo::Log::"};
    my $orig  = delete $stash->{"log"};

    *{"Mojo::Log::log"} = sub {
        push @{$self->logs->{$_[1]}} => $_[-1];

        # Original Mojo::Log->log
        $orig->(@_);
    };
}



1;
__DATA__

@@ devpanels.html.ep

<!-- Mojolicious development panels -->

<style type="text/css">
#devpanels { display: none; position: fixed; top: 0px; right: 0px; width: 100px; opacity: 0.8; background-color: black; color: #DDD; z-index: 1000002; height: 100%; }
#devpanels-mini { position: fixed; top: 80px; right: 0px; padding: 10px; opacity: 0.8; background-color: black; color: #DDD; z-index: 1000001; text-align: centre; font-size: 25px; font-weight: bold; cursor: pointer; }
#devpanels div { float: left; padding: 10px 20px; margin: 0px; width: 100%; border: 0px 1px solid black; cursor: pointer; }
#devpanels div:hover { background-color: #333; }
#devpanel-overlay { display:none; position: fixed; top: 0px; left: 0px; right: 100px; height: 100%; background-color: black; opacity: 0.95; color: white; padding: 10px 20px; z-index: 1000000; overflow-y: auto; }
#devpanel-overlay .dp-close { position: fixed; bottom: 0px; right: 115px; }
#devpanel-overlay ul { list-style: none; margin-left: 8px; }
#devpanel-overlay ul ul { border-left: 1px solid white; padding-left: 8px; border-radius: 0px 6px; }
</style>

<div id="devpanels">
<div>hide</div>
% foreach my $name ( keys %$panels ) {
<div><%= $name %></div>
% }
</div>
<div id="devpanel-overlay">
</div>

<div id="devpanels-mini">dev</div>

<script type="text/javascript" src="http://code.jquery.com/jquery-latest.pack.js"></script>
<script type="text/javascript">
  var panels = <%== $json_panels %>;

  var dp = jQuery('#devpanels');
  var mdp = jQuery('#devpanels-mini');
  var ov = jQuery('#devpanel-overlay');

  dp.delegate('div','click', function() {
      var name = this.textContent;

      if( name == "hide" ) {
          dp.hide();
          ov.hide();
          mdp.show();
      } else {
          console.groupCollapsed(name);
          console.log(panels[name]);
          console.groupEnd(name);
          ov.html("<div class=\"dp-close\">Close</div>");
          if( typeof(panels[name]) == "string" ) {
              ov.prepend(panels[name]);
          } else {
              ov.prepend(parseObject(panels[name]));
          }
          ov.show();
          ov.find('.dp-close').click(function() { ov.hide(); });
      }
  });

  mdp.click( function() { dp.show(); mdp.hide(); } );

  function parseObject(obj) {
      var ol = document.createElement("UL");
      for(var k in obj) {
          var v = obj[k];
          var li = document.createElement("LI");
          jQuery(li).html("<b>" + k + "</b>");
          if( typeof(v) == "object") {
              li.appendChild(parseObject(v));
          } else {
              jQuery(li).append(": " + v);
          }
          ol.appendChild(li);
      }
      return ol;
  }
    
</script>

__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::DevPanels - Debug panels for Mojolicious

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin( 'DevPanels',

    # A data panel, will be displayed using nested lists
    mystash => sub {
      my $c = shift;

      return { key1 => "value1", key2 => "value2" };
    },

    # A raw html panel
    mytemplate => sub {
      my $c = shift;

      return $c->render( 'example/welcome', partial => 1 );
    },

    # Disable one of the default panels
    config => undef,
  );

  # Mojolicious::Lite
  plugin 'DevPanels';

=head1 DESCRIPTION

L<Mojolicious::Plugin::DevPanels> is a L<Mojolicious> development plugin,
that provides an easy way to dump data, structures, or even partial templates
in a panel overlay.

It adds an after_dispatch hook, tries to detect html pages, and injects a
crappy, simple html panel at the end. While this approach is broken by design,
it works for quickly debugging error pages, flash messages, and so on by looking
at the stash / config / session data (see L<DEFAULT PANELS>).

=head1 METHODS

L<Mojolicious::Plugin::DevPanels> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 DEFAULT PANELS

=over

=item stash

Dump of the stash, excluding keys starting with "mojo." and "config".

=item config

Dump of the configuration

=item session

Dump of the user session

=item log

Dump of the logs, captured the same way as L<Mojolicious::Plugin::ConsoleLogger>

=item mojo_flags

Dump of the "mojo." keys on the stash.

=back

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.
L<Mojolicious::Plugin::ConsoleLogger>.

=cut

