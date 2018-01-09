package Selenium::Remote::Spec;

use strict;
use warnings;

# ABSTRACT: Implement commands for Selenium::Remote::Driver

=head1 DESCRIPTION

Defines all the HTTP endpoints available to execute on a selenium server.

If you have either a customized Selenium Server, or want new features
you should update the _cmds hash.

=for Pod::Coverage *EVERYTHING*

=cut

use List::Util qw{any};

use Moo;
extends 'Selenium::Remote::Commands';

#Ripped from the headlines: https://w3c.github.io/webdriver/webdriver-spec.html
#then add 2 params for our use

#Method    URI Template    no_content_success    internal_name    Command
our $spec = qq{
POST    session                                              0 newSession                   New Session
DELETE  session/:sessionId                                   1 quit                         Delete Session
GET     status                                               0 status                       Status
GET     session/:sessionId/timeouts                          0 getTimeouts                  Get Timeouts
POST    session/:sessionId/timeouts                          1 setTimeout                   Set Page Load timeout (v2->v3 shim)
POST    session/:sessionId/timeouts/async_script             1 setAsyncScriptTimeout        Set Async script timeout (v2->v3 shim)
POST    session/:sessionId/timeouts/implicit_wait            1 setImplicitWaitTimeout       Set Implicit wait timeout (v2->v3 shim)
POST    session/:sessionId/url                               1 get                          Navigate To
GET     session/:sessionId/url                               0 getCurrentUrl                Get Current URL
POST    session/:sessionId/back                              1 goBack                       Back
POST    session/:sessionId/forward                           1 goForward                    Forward
POST    session/:sessionId/refresh                           1 refresh                      Refresh
GET     session/:sessionId/title                             0 getTitle Get                 Title
GET     session/:sessionId/window                            0 getCurrentWindowHandle       Get Currently Focused Window Handle
DELETE  session/:sessionId/window                            1 close                        Close Currently Focused Window
POST    session/:sessionId/window                            1 switchToWindow               Switch To Window
GET     session/:sessionId/window/handles                    0 getWindowHandles             Get Window Handles
POST    session/:sessionId/frame                             1 switchToFrame                Switch To Frame
POST    session/:sessionId/frame/parent                      1 switchToParentFrame          Switch To Parent Frame
GET     session/:sessionId/window/rect                       0 getWindowSize                Get Window Size (v2->v3 shim)
GET     session/:sessionId/window/rect                       0 getWindowPosition            Get Window Position (v2->v3 shim)
POST    session/:sessionId/window/rect                       1 setWindowSize                Set Window Size (v2->v3 shim)
POST    session/:sessionId/window/rect                       1 setWindowPosition            Set Window Position (v2->v3 shim)
POST    session/:sessionId/window/maximize                   1 maximizeWindow               Maximize Window
POST    session/:sessionId/window/minimize                   1 minimizeWindow               Minimize Window
POST    session/:sessionId/window/fullscreen                 1 fullscreenWindow             Fullscreen Window
GET     session/:sessionId/element/active                    0 getActiveElement             Get Active Element
POST    session/:sessionId/element                           0 findElement                  Find Element
POST    session/:sessionId/elements                          0 findElements                 Find Elements
POST    session/:sessionId/element/:id/element               0 findChildElement             Find Element From Element
POST    session/:sessionId/element/:id/elements              0 findChildElements            Find Elements From Element
GET     session/:sessionId/element/:id/selected              0 isElementSelected            Is Element Selected
GET     session/:sessionId/element/:id/attribute/:name       0 getElementAttribute          Get Element Attribute
GET     session/:sessionId/element/:id/property/:name        0 getElementProperty           Get Element Property
GET     session/:sessionId/element/:id/css/:propertyName     0 getElementValueOfCssProperty Get Element CSS Value
GET     session/:sessionId/element/:id/text                  0 getElementText               Get Element Text
GET     session/:sessionId/element/:id/name                  0 getElementTagName            Get Element Tag Name
GET     session/:sessionId/element/:id/rect                  0 getElementSize               Get Element Rect
GET     session/:sessionId/element/:id/enabled               0 isElementEnabled             Is Element Enabled
POST    session/:sessionId/element/:id/click                 1 clickElement                 Element Click
POST    session/:sessionId/element/:id/clear                 1 clearElement                 Element Clear
POST    session/:sessionId/element/:id/value                 1 sendKeysToElement            Element Send Keys
GET     session/:sessionId/source                            0 getPageSource                Get Page Source
POST    session/:sessionId/execute/sync                      0 executeScript                Execute Script
POST    session/:sessionId/execute/async                     0 executeAsyncScript           Execute Async Script
GET     session/:sessionId/cookie                            0 getAllCookies                Get All Cookies
GET     session/:sessionId/cookie/:name                      0 getNamedCookie               Get Named Cookie
POST    session/:sessionId/cookie                            1 addCookie                    Add Cookie
DELETE  session/:sessionId/cookie/:name                      1 deleteCookieNamed            Delete Cookie
DELETE  session/:sessionId/cookie                            1 deleteAllCookies             Delete All Cookies
POST    session/:sessionId/actions                           1 generalAction                Perform Actions
DELETE  session/:sessionId/actions                           1 releaseGeneralAction         Release Actions
POST    session/:sessionId/alert/dismiss                     1 dismissAlert                 Dismiss Alert
POST    session/:sessionId/alert/accept                      1 acceptAlert                  Accept Alert
GET     session/:sessionId/alert/text                        0 getAlertText                 Get Alert Text
POST    session/:sessionId/alert/text                        1 sendKeysToPrompt             Send Alert Text
GET     session/:sessionId/screenshot                        0 screenshot                   Take Screenshot
GET     session/:sessionId/element/:id/screenshot            0 elementScreenshot            Take Element Screenshot
};

our $spec_parsed;

sub get_spec {
    return $spec_parsed if $spec_parsed;
    my @split = split(/\n/,$spec);
    foreach my $line (@split) {
        next unless $line;
        my ($method,$uri,$nc_success,$key,@description) =  split(/ +/,$line);
        $spec_parsed->{$key} = {
           method             => $method,
           url                => $uri,
           no_content_success => int($nc_success), #XXX this *should* always be 0, but specs lie
           description        => join(' ',@description),
        };
    }
    return $spec_parsed;
}

has '_cmds' => (
    is      => 'lazy',
    reader  => 'get_cmds',
    builder => \&get_spec,
);

sub get_params {
    my ( $self, $args ) = @_;
    if ( !( defined $args->{'session_id'} ) ) {
        return;
    }
    my $data    = $self->SUPER::get_params($args);

    #URL & data polyfills for the way selenium2 used to do things, etc
    $data->{payload} = {};
    $data->{payload}->{pageLoad} = $args->{value} if $data->{url} =~ m/timeouts$/;
    $data->{payload}->{script}   = $args->{value} if $data->{url} =~ s/timeouts\/async_script$/timeouts/g;
    $data->{payload}->{implicit} = $args->{value} if $data->{url} =~ s/timeouts\/implicit_wait$/timeouts/g;
    #$data->{payload}->{handle}   = $args->{value} if $args->{command} eq 'switchToWindow'; #XXX probably not needed? lets hope not
    $data->{payload}->{handle}   = $args->{window_handle} if grep { $args->{command} eq $_ } qw{setWindowSize getWindowSize setWindowPosition getWindowPosition fullscreenWindow minimizeWindow maximizeWindow};
    return $data;
}


#Utility

sub get_spec_differences {
    my $v2_spec = Selenium::Remote::Commands->new()->get_cmds();
    my $v3_spec = Selenium::Remote::Spec->new()->get_cmds();

    foreach my $key (keys(%$v2_spec)) {
        print "v2 $key NOT present in v3 spec!!!\n" unless any { $_ eq $key } keys(%$v3_spec);
    }
    foreach my $key (keys(%$v3_spec)) {
        print "v3 $key NOT present in v2 spec!!!\n" unless any { $_ eq $key } keys(%$v2_spec);
    }
}

1;

__END__
