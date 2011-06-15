#!/usr/bin/env perl
use common::sense;
# use strict;
# use warnings;
# use utf8;

# gnu_compat: --opt="..." is allowed.
# no_bundling: single character option is not bundled.
# no_ignore_case: no ignore case on long option.
use Getopt::Long qw(:config gnu_compat no_bundling no_ignore_case);
use Pod::Usage;
use WWW::NicoVideo::Download;
use URI;
use Web::Scraper;
use XML::Feed;
use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);


my $NICOVIDEO;
my $DEBUG_LEVEL = 1;

my $VIDEO_ID  = qr/\A[sn]m\d+\Z/;
my $MYLIST_ID = qr/\A\d+\Z/;


sub usage () {
    pod2usage(-verbose => 1);
}

sub debug {
    my $level = shift;
    warn @_, "\n" if $level <= $DEBUG_LEVEL;
}



# *video* ($video) is either:
# - *video ID* ($video_id)
# - *video URI* ($video_uri)
#
# *mylist* ($mylist) is either:
# - *mylist ID* ($mylist_id)
# - *mylist URI* ($mylist_uri)



sub download_mylist {
    my ($mylist, $file_path, $progressbar) = @_;

    debug 1, "downloading mylist '$mylist'...";
    for my $video (get_videos_from_mylist($mylist)) {
        download_video($video, $file_path, $progressbar);
    }
    debug 1, "downloading mylist '$mylist'...done!";
}

# Returns array of *video*es from *mylist*.
sub get_videos_from_mylist {
    my ($mylist) = @_;

    my $mylist_id = get_mylist_id($mylist) // do {
        warn "skipping '$mylist'... can't find mylist ID.\n";
        return; # empty
    };
    my $feed_uri = URI->new("http://www.nicovideo.jp/mylist/$mylist_id?rss=2.0");
    debug 2, "feed URI = $feed_uri";
    my $feed = XML::Feed->parse($feed_uri) or do {
        warn "skipping '$mylist'... "
            . "error occurred while parsing RSS: "
            . XML::Feed->errstr(), "\n";
        return; # empty
    };

    return map { $_->link } $feed->entries;
}

sub download_video {
    my ($video, $file_path, $progressbar) = @_;

    debug 1, "downloading video '$video'...";

    my $video_id = get_video_id($video) // do {
        warn "skipping '$video'... can't find video ID.\n";
        return;
    };
    debug 2, "video ID = $video_id";

    mkpath $file_path;
    unless (-d $file_path) {
        warn "skipping '$video'... can't create directory '$file_path'.\n";
        return;
    }

    my @download_args = do {
        my $filename = catfile $file_path, "$video_id.flv";
        if ($progressbar) {
            my $wfh = IO::File->new($filename, 'w') or do {
                warn "skipping '$video'... can't open '$filename' for writing.\n";
                return;
            };
            my $callback = sub {
                my ($chunk, $res, $proto) = @_;
                print $wfh $chunk;
                my $size = tell $wfh;
                if (my $total = $res->header('Content-Length')) {
                    printf "%d/%d (%f%%)\r", $size, $total, $size/$total*100;
                }
                else {
                    printf "%d/Unknown bytes\r", $size;
                }
            };
            ($video_id, $callback);
        }
        else {
            ($video_id, $filename);
        }
    };

    eval { $NICOVIDEO->download(@download_args) };
    warn "$@\n" if $@;

    debug 1, "downloading video '$video'...done!";
}

# Returns *video ID* from *video*.
sub get_video_id {
    my ($video) = @_;

    # video ID
    if ($video =~ $VIDEO_ID) {
        return $video;
    }

    # video URI
    my $uri = URI->new($video);
    my @segments = $uri->path_segments();
    if (@segments && $segments[-1] =~ $VIDEO_ID) {
        return $segments[-1];
    }

    # else
    return undef;
}

sub get_mylist_id {
    my ($mylist) = @_;

    # mylist ID
    if ($mylist =~ $MYLIST_ID) {
        return $mylist;
    }

    # mylist URI
    my $uri = URI->new($mylist);
    if ($uri->scheme =~ /\Ahttps?\Z/
        && ($uri->path_segments)[-1] =~ $MYLIST_ID)
    {
        return ($uri->path_segments)[-1];
    }

    # else
    return undef;
}

sub is_mylist {
    my ($arg) = @_;
    return defined get_mylist_id($arg);
}

sub is_video {
    my ($arg) = @_;
    return defined get_video_id($arg);
}

my $needhelp;
my $email;
my $password;
my $progressbar = 0;
GetOptions(
    'h|help' => \$needhelp,
    'email=s' => \$email,
    'password=s' => \$password,
    'progressbar' => \$progressbar,
    'q|quiet' => sub { $DEBUG_LEVEL-- },
    'v|verbose' => sub { $DEBUG_LEVEL++ },
) or usage;
usage if $needhelp;
usage unless @ARGV;
if (!defined $email || !defined $password) {
    if (eval { require Config::Pit }) {
        my $c = Config::Pit::pit_get(
            'www.nicovideo.jp',
            require => {
                email    => 'your email (as ID)',
                password => 'your password',
            }
        );
        $email    //= $c->{email};
        $password //= $c->{password};
    }
}
if (!defined $email || !defined $password) {
    die "--email and --password are required.\n";
}

# Initialization
debug 2, "email: $email";
debug 2, "password: $password";
$NICOVIDEO = WWW::NicoVideo::Download->new(
    email    => $email,
    password => $password,
);

# Download all videos from mylist.
my $arg = shift;
my $file_path = shift // '.';
debug 2, "first arg: $arg";
debug 2, "file_path: $file_path";
debug 2, "progressbar: $progressbar";
if (is_video($arg)) {
    download_video($arg, $file_path, $progressbar);
}
elsif (is_mylist($arg)) {
    download_mylist($arg, $file_path, $progressbar);
}
else {
    die "error: don't know what to do for '$arg'.\n";
}



__END__

=head1 NAME

    dlnico.pl - NicoVideo downloader


=head1 SYNOPSIS

    $ dlnico.pl http://www.nicovideo.jp/mylist/22370493  # download all videos in mylist
    $ dlnico.pl 22370493                                 # same as above
    $ dlnico.pl http://www.nicovideo.jp/watch/sm14043624 # download the video
    $ dlnico.pl sm14043624                               # same as above


=head1 OPTIONS

=over

=item -h, --help

Show this help.

=back


=head1 TODO

=over

=item parallel download using Coro.

=back


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
