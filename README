Dancer-Plugin-Auth-Google
=========================

This plugin provides a simplpe way to authenticate your users through Google's
OAuth API. It provides you with a helper to build easily a redirect to the
authentication URI, defines automatically a callback route handler and saves
the authenticated user to your session when done.

```perl
    package MyApp;
    use Dancer ':syntax';
    use Dancer::Plugin::Auth::Google;

    auth_google_init;

    before sub {
        redirect auth_google_authenticate_url
            unless session('google_user');
    };

    get '/' => sub {
        "welcome, " . session('google_user')->{name}
    };

    get '/fail' => sub {
        "oh noes!"
    };
```

Prerequisites
-------------

In order for this plugin to work, you need the following:

* Google Application

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

* Configuration

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

* Session backend

For the authentication process to work, you need a session backend so the plugin
can store the authenticated user's information.

Use the session backend of your choice, it doesn't make a difference, see
Dancer::Session for details about supported session engines, or search the CPAN
for new ones.


### Installation ###

    cpanm Dancer::Plugin::Auth::Google


Exports
-------

The plugin exports the following symbols to your application's namespace:

### auth_google_init ###

This function should be called before your route handlers in order to
initialize the underlying object and set up the proper routes. It will
read your configuration and create everything that it needs.

### auth_google_authenticate_url ###

This function returns an authorize URI for redirecting unauthenticated
users. You should use this in a before filter like the "synopsis"
demo above.


Route Handlers
--------------

The plugin defines the following route handler automatically:

* /auth/google/callback

This route handler is responsible for catching back a user that has just
authenticated herself with Google's OAuth. The route handler saves tokens
and user information in the session and then redirects the user to the URI
specified by callback_success.

If the validation of the token returned by Google failed or was denied,
the user will be redirected to the URI specified by callback_fail. Otherwise,
this route will point the user to callback_success.


Acknowledgements
----------------

This plugin was written following the same design as
Dancer::Plugin::Auth::Twitter and Dancer::Plugin::Auth::Facebook.


COPYRIGHT AND LICENCE
---------------------

Copyright (C) 2014, Breno G. de Oliveira

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
