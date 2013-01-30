#IrssiNotifier

##Weechat support

This is a fork of Lauri Härsilä's irssinotifier script for delivering IRC highlights to Android devices.

I've just ported the script so it'll work on Weechat, everything else is as before.

##GNTP

You'll need the python gntp package installed for this script to work. Your package manager may have it (try 'apt-cache search gntp' or 'yum search gntp') but if not, use pip to install it ('sudo pip-python install gntp') on Fedora.

##Variables:

- plugins.var.perl.irssinotifier.api_token

Set this to your irssinotifier API token, available from https://irssinotifier.appspot.com after registration

- plugins.var.perl.irssinotifier.away_only

Set to "on" or "off" to specify whether or not you want notifications only while away (defaults to "on")

- plugins.var.perl.irssinotifier.channels_to_ignore

Comma separated list of channels to ignore, e.g. "#idlerpg,#webvictim"

If you have issues with notification spam from your status window, try adding your nick into this list, i.e. "webvictim"

- plugins.var.perl.irssinotifier.encryption_password

The encryption password you set on your device, must be the same at both ends for notifications to work

- plugins.var.perl.irssinotifier.ignore_active_window

Set to "on" or "off" to decide whether you want to ignore notifications from the currently active window or not (defaults to "on")

- plugins.var.perl.irssinotifier.require_idle_seconds

Set to an integer to specify a certain idle time before notifications are sent (defaults to 0, because away_only is on by default)

- plugins.var.perl.irssinotifier.use_full_buffer_name

Set to "on" or "off" to determine whether you want to see the full buffer name (e.g. irc.freenode.#irssi) when notifications are sent. Useful if you're in multiple channels with the same name!

##Original README below

Now released on [Google Play](https://play.google.com/store/apps/details?id=fi.iki.murgo.irssinotifier)!

IRC notifications for Android (and possibly other devices).

Web page: https://irssinotifier.appspot.com/

##Goals:

- Low battery usage (uses C2dm)
- Easy to set up (hosted server)
- Good privacy (end-to-end -encryption)

##Dependencies

- [ActionBarSherlock](https://github.com/JakeWharton/ActionBarSherlock). Thanks, [Jake Wharton](https://github.com/JakeWharton).
- [ViewPagerIndicator](https://github.com/JakeWharton/Android-ViewPagerIndicator/). Thanks, [Jake Wharton](https://github.com/JakeWharton).
- [cwac-touchlist](https://github.com/commonsguy/cwac-touchlist). Thanks, commonsguy.

##License

    Copyright 2012 Lauri Härsilä where applicable (commits made by murgo, Lauri Härsilä or Unknown on this repository. I'm new to this github stuff).

    Licensed under the Apache License, Version 2.0, see LICENSE.
