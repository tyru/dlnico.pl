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
my $DEBUG = 0;


sub usage () {
    pod2usage(-verbose => 1);
}

sub debug {
    return unless $DEBUG;
    warn @_, "\n";
}

sub download_mylist {
    my ($mylist, $file_path, $progressbar) = @_;

    debug "downloading mylist '$mylist'...";
    for my $video (get_videos_from_mylist($mylist)) {
        download_video($video, $file_path, $progressbar);
    }
    debug "downloading mylist '$mylist'...done!";
}

sub get_videos_from_mylist {
    my ($mylist) = @_;

    my $feed_uri = get_feed_from_mylist($mylist) // do {
        warn "skipping '$mylist'... can't find mylist URL.\n";
        return;
    };
    debug "feed URI = $feed_uri";
    my $feed = XML::Feed->parse($feed_uri) or do {
        warn "skipping '$mylist'... "
            . "error occurred while parsing RSS: "
            . XML::Feed->errstr();
        return;
    };

    return map { $_->link } $feed->entries;
}

sub download_video {
    my ($video, $file_path, $progressbar) = @_;

    debug "downloading video '$video'...";

    my $video_id = get_video_id($video) // do {
        warn "skipping '$video'... can't find video ID.\n";
        return;
    };
    debug "video ID = $video_id";
    eval {
        mkpath $file_path;
        unless (-d $file_path) {
            warn "skipping '$video'... can't create directory '$file_path'.\n";
            return;
        }

        my $filename = catfile $file_path, "$video_id.flv";
        if ($progressbar) {
            my $wfh = IO::File->new($filename, 'w') or do {
                warn "skipping '$video'... can't open '$filename' for writing.";
                return;
            };
            $NICOVIDEO->download($video_id, sub {
                my ($chunk, $res, $proto) = @_;
                print $wfh $chunk;
                my $size = tell $wfh;
                if (my $total = $res->header('Content-Length')) {
                    printf "%d/%d (%f%%)\r", $size, $total, $size/$total*100;
                }
                else {
                    printf "%d/Unknown bytes\r", $size;
                }
            });
        }
        else {
            $NICOVIDEO->download($video_id, $filename);
        }
    };
    warn $@ if $@;

    debug "downloading video '$video'...done!";
}

sub get_video_id {
    my ($video) = @_;

    return $video if $video =~ /\A[sn]m\d+\Z/;

    # we assume URI
    my $uri = URI->new($video);
    my @segments = $uri->path_segments();
    return @segments ? $segments[-1] : undef;
}

my $MYLIST_ID = qr/\A\d+\Z/;
sub get_feed_from_mylist {
    my ($mylist) = @_;

    # mylist ID
    if ($mylist =~ $MYLIST_ID) {
        return URI->new("http://www.nicovideo.jp/mylist/$mylist?rss=2.0");
    }

    # mylist URI
    my $uri = URI->new($mylist);
    if ($uri->scheme =~ /\Ahttps?\Z/
        && ($uri->path_segments)[-1] =~ $MYLIST_ID)
    {
        $uri->query_form('rss', '2.0');
        return $uri;
    }

    # else
    return undef;
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
    'debug' => \$DEBUG,
) or usage;
usage if $needhelp;
usage unless @ARGV;
if (!defined $email || !defined $password) {
    die "--email and --password are required.\n";
}

# Initialization
debug "email: $email";
debug "password: $password";
$NICOVIDEO = WWW::NicoVideo::Download->new(
    email    => $email,
    password => $password,
);

# Download all videos from mylist.
# TODO: recognize video or video ID (see SYNOPSIS for details).
my $mylist = shift;
my $file_path = shift // '.';
debug "mylist: $mylist";
debug "file_path: $file_path";
debug "progressbar: $progressbar";
download_mylist($mylist, $file_path, $progressbar);



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


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
