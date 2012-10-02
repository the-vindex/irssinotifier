use POSIX;
use Data::Dumper;

my $scriptname = "irssinotifier";
#my $version = "6";
my $version = "11";
my $lastKeyboardActivity = time;

my %SCRIPT = (
				name => $scriptname,
				author => "weechat version by Gus Luxton <webvictim\@gmail.com> - original irssi version by Lauri \'murgo\' Härsilä <murgo\@iki.fi>",
				version => "0.".$version,
				license => "Apache License, version 2.0",
				desc => "Send notifications about weechat highlights to server",
);

weechat::register($SCRIPT{"name"}, $SCRIPT{"author"}, $SCRIPT{"version"}, $SCRIPT{"license"}, $SCRIPT{"desc"}, "", "");

sub text_handler {
	my ( $data, $buffer, undef, undef, undef, $ishilight, $nick, $msg ) = @_;

	$short_channel = weechat::buffer_get_string($buffer, "localvar_channel") || 'UNDEF';

	# $target is the name of the channel that is sent to the notification server
	if (weechat::config_get_plugin("use_full_buffer_name") eq "on") {
		$target = weechat::buffer_get_string($buffer, "localvar_name") || 'UNDEF';
	} else {
		$target = weechat::buffer_get_string($buffer, "localvar_channel") || 'UNDEF';
	}

	# $type is either "channel" for public channels or "private" for queries
	my $type = weechat::buffer_get_string($buffer, "localvar_type") || 'UNDEF';

	# $away is the value of the away message if the user is away, and blank if not
	my $away = weechat::buffer_get_string($buffer, "localvar_away") || "";

	# $active is the number of windows currently displaying the buffer on screen
	my $active = weechat::buffer_get_integer($buffer, "num_displayed") || 0; 

	# private messages are handled slightly differently
	# the special value "!PRIVATE" flags it as a private message to the IrssiNotifier servers
	# we change the "channel" of the message to server.nick of the person sending the PM
	if ($type eq "private") {
		my $nick = $target;
		my $target = "!PRIVATE";
	}
	
	# do the check as to whether we should send notifications
	if (
		($ishilight == 1 || $type eq "private") &&
		((weechat::config_get_plugin("away_only") eq "on" && length($away)>0) || (weechat::config_get_plugin("away_only") eq "off")) &&
		((weechat::config_get_plugin("ignore_active_window") eq "on" && $active == 0) || (weechat::config_get_plugin("ignore_active_window") eq "off")) && 
		activity_allows_hilight() &&
		target_allows_hilight($short_channel)
    ) {
		hilite($msg, $nick, $target);
	}	
	
	return weechat::WEECHAT_RC_OK;
}

sub activity_allows_hilight {
	my $timeout = weechat::config_get_plugin('require_idle_seconds');
    return ($timeout <= 0 || (time - $lastKeyboardActivity) > $timeout);
}

sub target_allows_hilight {
	my $target_channel = $_[0];
	my $hilight_allowed = 1;
	my $channel_list = weechat::config_get_plugin('channels_to_ignore');
	my @channels = split(',', $channel_list);
	foreach my $channel (@channels) {
		if ($target_channel eq $channel) {
			$hilight_allowed = 0;
		}
	}
	return $hilight_allowed;
}

sub dangerous_string {
  my $s = @_ ? shift : $_;
  return $s =~ m/"/ || $s =~ m/`/ || $s =~ m/\\/;
}

sub hilite {
	my ($msg, $nick, $target) = @_;

	if (weechat::config_get_plugin('api_token') eq "") {
        prt($scriptname.": Set API token to send notifications: /set plugins.var.perl.irssinotifier.api_token [token]");
		return weechat::WEECHAT_RC_OK;
    }
	
    # check openssl is installed
	`/usr/bin/env openssl version`;
	 if ($? != 0) {
		prt($scriptname.": You'll need to install openssl to use irssinotifier");
		return weechat::WEECHAT_RC_OK;
    }

	# check wget is installed
    `/usr/bin/env wget --version`;
    if ($? != 0) {
		prt($scriptname.": You'll need to install wget to use irssinotifier");
		return weechat::WEECHAT_RC_OK;
    }
		
	# verify that the API token is not badly written
	my $api_token = weechat::config_get_plugin('api_token');
    if (dangerous_string $api_token) {
		prt($scriptname.": API token cannot contain backticks, double quotes or backslashes");
		return weechat::WEECHAT_RC_OK;
    }

	# verify that the encryption password is 1) set and 2) not badly written
	my $encryption_password = weechat::config_get_plugin('encryption_password');
    if ($encryption_password) {
        if (dangerous_string $encryption_password) {
			prt($scriptname.": Encryption password cannot contain backticks, double quotes or backslashes");
			return weechat::WEECHAT_RC_OK;
        }
        $msg = encrypt($msg);
        $nick = encrypt($nick);
		$target = encrypt($target);
    } else {
		prt($scriptname.": set encryption password to send notifications (must be same as in the Android device): /set plugins.var.perl.".$scriptname.".encryption_password [password]");
    }

	# make up a POST data string to send to the servers
	my $data = "--post-data=apiToken=$api_token\\&message=$msg\\&channel=$target\\&nick=$nick\\&version=$version";

	# run wget with the necessary parameters
    my $result = `/usr/bin/env wget --no-check-certificate -qO- /dev/null $data https://irssinotifier.appspot.com/API/Message`;
    if ($? != 0) {
        # Something went wrong, might be network error or authorization issue. Probably no need to alert user, though.
		prt($scriptname.": Sending highlight to server failed, check http://irssinotifier.appspot.com for updates");
		return weechat::WEECHAT_RC_OK;
    }
		
	# if we get something back from the server, output it here
	# (this doesn't usually happen because of the "-qO- /dev/null", not sure if the original author realised this)
    if (length($result) > 0) {
		prt($scriptname.": $result");
    }
}

sub sanitize {
    my $str = @_ ? shift : $_;
    $str =~ s/((?:^|[^\\])(?:\\\\)*)'/$1\\'/g;
    $str =~ s/\\'/'/g; # stupid perl
    #$str =~ s/'/\'/g; # stupid perl
    return "\"$str\"";
}

sub encrypt {
    my $text = $_[0];
    $text = sanitize $text;
	my $encryption_password = weechat::config_get_plugin('encryption_password');
    my $result = `/usr/bin/env echo $text| /usr/bin/env openssl enc -aes-128-cbc -salt -base64 -A -k "$encryption_password" | tr -d '\n'`;
    $result =~ s/=//g;
    $result =~ s/\+/-/g;
    $result =~ s/\//_/g;
    chomp($result);
    return $result;
}

sub decrypt {
    my $text = $_[0];
    $text = sanitize $text;
	my $encryption_password = weechat::config_get_plugin('encryption_password');
    my $result = `/usr/bin/env echo $text| /usr/bin/env openssl enc -aes-128-cbc -d -salt -base64 -A -k "$encryption_password"`;
    chomp($result);
    return $result;
}

# done
sub setup_keypress_handler {
	weechat::unhook("event_key_pressed");
	if (weechat::config_get_plugin("require_idle_seconds") > 0) {
		weechat::hook_signal("key_pressed", "event_key_pressed", "");
    }
}

sub event_key_pressed {
    $lastKeyboardActivity = time;
	return weechat::WEECHAT_RC_OK
}

# little wrapper around weechat's print function
sub prt {weechat::print("", $_[0]);}
sub DEBUG {weechat::print('', "***\t" . $_[0]);}

# set up weechat plugin variables

# holds the password for encryption (must be set the same both on the Android device and within weechat)
# default: "password"
if (weechat::config_get_plugin("encryption_password") eq "") {
	weechat::config_set_plugin("encryption_password", "password");
	prt($scriptname.": Set encryption password to send notifications (must be same as on the Android device): /set plugins.var.perl.".$scriptname.".encryption_password [password]");
}

# holds the API token for your IrssiNotifier online account
# this must be set up at https://irssinotifier.appspot.com
# default: "" (blank)
if (weechat::config_get_plugin("api_token") eq "") {
	weechat::config_set_plugin("api_token", "");
	prt($scriptname.": Set API token to send notifications: /set plugins.var.perl.".$scriptname.".api_token [token]");	
}

# controls whether notifications are only sent while the user is marked as away (useful with screen_away)
# default: on
if (weechat::config_get_plugin("away_only") eq "") {
	weechat::config_set_plugin("away_only", "on");
}

# controls whether notifications are skipped while the buffer can actively be seen on screen
# default: on
if (weechat::config_get_plugin("ignore_active_window") eq "") {
	weechat::config_set_plugin("ignore_active_window", "on");
}

# specifies how many seconds the terminal must be idle for before notifications are dispatched
# default: 0
if (weechat::config_get_plugin("require_idle_seconds") eq "") {
	weechat::config_set_plugin("require_idle_seconds", 0);
}

# controls whether weechat uses "freenode.#weechat" (on) or "#weechat" (off) as the channel name
# default: off
if (weechat::config_get_plugin("use_full_buffer_name") eq "") {
	weechat::config_set_plugin("use_full_buffer_name", "off");
}

# defines a comma-separated list of channels to ignore hilights from (useful for spammy bots)
# default: ""
if (weechat::config_get_plugin("channels_to_ignore") eq "") {
	weechat::config_set_plugin("channels_to_ignore", "");
}


# add the hooks that will process all the data from weechat
#weechat::hook_print("", "", "", 1, "text_handler", "");
weechat::hook_print("", "irc_privmsg", "", 1, "text_handler", "");
weechat::hook_config("plugins.var.perl.".$scriptname.".require_idle_seconds", "setup_keypress_handler", "");

setup_keypress_handler();
