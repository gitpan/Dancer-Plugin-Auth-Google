package Dancer::Plugin::Auth::Google;
use strict;
use warnings;

our $VERSION = 0.01;

use Dancer ':syntax';
use Dancer::Plugin;
use Carp ();
use Scalar::Util;

use Furl;
use IO::Socket::SSL;
use URI;

my $client_id;
my $client_secret;
my $scope;
my $access_type;
my $callback_url;
my $callback_success;
my $callback_fail;
my $furl;

register 'auth_google_init' => sub {
    my $config     = plugin_setting;
    $client_id     = $config->{client_id};
    $client_secret = $config->{client_secret};
    $callback_url  = $config->{callback_url};

    $scope            = $config->{scope}            || 'profile';
    $callback_success = $config->{callback_success} || '/';
    $callback_fail    = $config->{callback_fail}    || '/fail';
    $access_type      = $config->{access_type}      || 'online';

    foreach my $param ( qw(client_id client_secret callback_url) ) {
        Carp::croak "'$param' is expected but not found in configuration"
            unless $config->{$param};
    }

    debug "new google with $client_id, $client_secret, $callback_url";
    $furl = Furl->new(
        agent    => "Dancer-Plugin-Auth-Google/$VERSION",
        timeout  => 5,
        ssl_opts => {
            SSL_verify_mode => SSL_VERIFY_NONE(),
        },
    );

    return 1;
};

register 'auth_google_authenticate_url' => sub {
    Carp::croak 'auth_google_init() must be called first'
        unless defined $callback_url;

    my $uri = URI->new('https://accounts.google.com/o/oauth2/auth');
    $uri->query_form(
        response_type => 'code',
        client_id     => $client_id,
        redirect_uri  => $callback_url,
        scope         => $scope,
        access_type   => $access_type,
    );

    debug "google auth uri: $uri";
    return $uri;
};

get '/auth/google/callback' => sub {
    debug 'in google auth callback';

    return redirect $callback_fail if params->{'error'};

    my $code = params->{'code'};
    return redirect $callback_fail unless $code;

    my $res = $furl->post(
        'https://accounts.google.com/o/oauth2/token',
        [ 'Content-Type' => 'application/x-www-form-urlencoded' ],
        {
            code          => $code,
            client_id     => $client_id,
            client_secret => $client_secret,
            redirect_uri  => $callback_url,
            grant_type    => 'authorization_code',
        }
    );
    my $data = from_json($res->decoded_content);

    return send_error 'google auth: no access token present'
        unless $data->{access_token};

    $res = $furl->get(
        'https://www.googleapis.com/plus/v1/people/me',
        [ 'Authorization' => 'Bearer ' . $data->{access_token} ],
    );
    my $user = from_json($res->decoded_content);

    # we need to stringify our JSON::Bool data as some
    # session backends might have trouble storing objects
    foreach my $k (keys %$user) {
        $user->{$k} = "$user->{$k}" if Scalar::Util::blessed($user->{$k});
    }

    session 'google_user' => { %$data, %$user };
    redirect $callback_success;
};

register_plugin;
__END__

=head1 NAME

Dancer::Plugin::Auth::Google - Authenticate with Google

=head1 SYNOPSIS

    package MyApp;
    use Dancer ':syntax';
    use Dancer::Plugin::Auth::Google;

    auth_google_init;

    before sub {
        redirect auth_google_authenticate_url
            unless session('google_user');
    };

    get '/' => sub {
        "welcome, " . session('google_user')->{displayName}
    };

    get '/fail' => sub {
        "oh noes!"
    };


=head1 DESCRIPTION

This plugin provides a simplpe way to authenticate your users through Google's
OAuth API. It provides you with a helper to build easily a redirect to the
authentication URI, defines automatically a callback route handler and saves
the authenticated user to your session when done.


=head1 PREREQUISITES

In order for this plugin to work, you need the following:

=over 4

=item * Google Application

Anyone with a valid Google account can register an application. Go to
[http://console.developers.google.com], then select a project or create
a new one. After that, in the sidebar on the left, select "Credentials"
under the "APIs and auth" option. In the "OAuth" section of that page,
select **Create New Client ID**. A dialog will appear.

In the "Application type" section of the dialog, make sure you select
"Web application". In the "Authorized JavaScript origins" field, make
sure you put the domains of both your development server and your
production one (e.g.: http://localhost:3000 and http://mywebsite.com).
Same thing goes for the "Redirect URIs": those **MUST** be the same
as you will set in your app and Google won't redirect to any page that
is not listed (don't worry, you can edit this later too).

Again, make sure the "Redirect URIs" contains both your development
url (e.g. http://localhost:3000/auth/google/callback) and production
(e.g. http://mycoolwebsite.com/auth/google/callback).

=item * Configuration

After you set up your app, you need to configure this plugin. To do
that, copy the "Client ID" and "Client Secret" generated on the
previous step into your Dancer's configuration under
Plugins / Auth::Google, like so:

    # config.yml
    plugins:
        'Auth::Google':
            client_id:        'your-client-id'
            client_secret:    'your-client-secret'
            scope:            'profile'
            access_type:      'online'
            callback_url:     'http://localhost:3000/auth/google/callback'
            callback_success: '/'
            callback_fail:    '/fail'

Of those, only "client_id", "client_secret" and "callback_url" are mandatory.
If you omit the other ones, they will assume their default values, as listed
above.

See L<https://developers.google.com/+/api/oauth#login-scopes> for available
scopes to chose from. You can set as many as you like, separated by space.
A usual combination is 'profile email'. If you want a Google-specific scope
(i.e. those with a "." in the name) make sure you add the full URL as
specified in the document above. For example, the proper way to ask for a
user's social features is not "plus.login", but
"https://www.googleapis.com/auth/plus.login".

=item * Session backend

For the authentication process to work, you need a session backend so the plugin
can store the authenticated user's information.

Use the session backend of your choice, it doesn't make a difference, see
Dancer::Session for details about supported session engines, or search the CPAN
for new ones.

=back

=head1 EXPORTS

The plugin exports the following symbols to your application's namespace:

=head2 auth_google_init

This function should be called before your route handlers in order to
initialize the underlying object and set up the proper routes. It will
read your configuration and create everything that it needs.

=head2 auth_google_authenticate_url

This function returns an authorize URI for redirecting unauthenticated
users. You should use this in a before filter like the "synopsis"
demo above.

=head1 ROUTE HANDLERS

The plugin defines the following route handler automatically:

=head2 /auth/google/callback

This route handler is responsible for catching back a user that has just
authenticated herself with Google's OAuth. The route handler saves tokens
and user information in the session and then redirects the user to the URI
specified by callback_success.

If the validation of the token returned by Google failed or was denied,
the user will be redirected to the URI specified by callback_fail. Otherwise,
this route will point the user to callback_success.

=head1 ACCESSING OTHER GOOGLE APIS

Once the user is authenticated, your session data will contain the access
token:

    my $token = session('google_user')->{access_token};

You can use that access token to make calls to a Google API on behalf of
the user. See L<https://developers.google.com/accounts/docs/OAuth2WebServer>
for more information on this.

=head1 BUGS

Please submit any bug reports or feature requests either on RT or Github.

=head1 ACKNOWLEDGEMENTS

This plugin was written following the same design as
Dancer::Plugin::Auth::Twitter and Dancer::Plugin::Auth::Facebook.

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2014, Breno G. de Oliveira

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
