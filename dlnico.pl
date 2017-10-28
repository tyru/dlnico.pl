#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use utf8;

# gnu_compat: --opt="..." is allowed.
# no_bundling: single character option is not bundled.
# no_ignore_case: no ignore case on long option.
use Getopt::Long qw(:config gnu_compat no_bundling no_ignore_case);
use Pod::Usage qw(pod2usage);
use WWW::NicoVideo::Download;
use LWP::Protocol::https;   # Raise error at compile-time. (because LWP dynamically loads it)
use URI;
use XML::Feed;
use XML::Simple ();
use File::Spec::Functions qw(catfile);
use File::Path qw(mkpath);
use Term::ProgressBar;


my $NICOVIDEO;
my $DEBUG_LEVEL = 1;

my $VIDEO_ID  = qr/\A[a-z0-9]+\Z/;
my $MYLIST_ID = qr/\A\d+\Z/;


sub usage {
    my $level = shift // 1;
    pod2usage(-verbose => $level);
}

sub debug {
    my $level = shift;
    print @_, "\n" if $level <= $DEBUG_LEVEL;
}

sub format_string {
    my ($format, $opt) = @_;
    $format =~ s[ (\$\{(\w+)\}) ][ $opt->{$2} // $1 ]gex;
    return $format;
}

my $SIZE_KiB = 1024;
my $SIZE_MiB = 1024 * 1024;
my $SIZE_GiB = 1024 * 1024 * 1024;
sub readable_size {
    my ($byte_num) = @_;

    my ($num, $postfix) = do {
        if ($byte_num < $SIZE_KiB) {
            # 0 <= $byte_num < 1024
            ($byte_num, "B");
        }
        elsif ($byte_num < $SIZE_MiB) {
            # 1024 <= $byte_num < 1024 * 1024
            ($byte_num / $SIZE_KiB, "KiB");
        }
        elsif ($byte_num < $SIZE_GiB) {
            # 1024 * 1024 <= $byte_num < 1024 * 1024 * 1024
            ($byte_num / $SIZE_MiB, "MiB");
        }
        else {
            # 1024 * 1024 * 1024 <= $byte_num
            ($byte_num / $SIZE_GiB, "GiB");
        }
    };
    return sprintf('%.3f', $num).$postfix;
}

# *video* ($video) is either:
# - *video ID* ($video_id)
# - *video URI* ($video_uri)
#
# *mylist* ($mylist) is either:
# - *mylist ID* ($mylist_id)
# - *mylist URI* ($mylist_uri)



# Download *video*.
sub download_video {
    my ($video, $file_path, $opt) = @_;

    # Get video ID.
    my $video_id = get_video_id($video) // do {
        warn "skipping '$video'... can't find video ID.\n";
        return;
    };
    debug 2, "video ID = $video_id";

    # Get and store info in $format.
    my $format = fetch_meta_data($video_id);

    # Check --overwrite.
    my $filename = format_string($opt->{filename_format}, $format);
    $filename = catfile $file_path, $filename;
    if (!$opt->{overwrite} && -e $filename) {
        warn "skipping '$video'... path '$filename' exists.\n";
        return;
    }

    debug 1, "downloading video '$filename'...";

    # Make parent directory of saving movie file.
    mkpath $file_path;
    unless (-d $file_path) {
        warn "skipping '$video'... can't create directory '$file_path'.\n";
        return;
    }

    # Build arguments for $NICOVIDEO->download().
    my @download_args;
    if ($opt->{progress}) {
        my $callback = make_progressbar_callback($filename, $video, $format->{title});
        @download_args = ($video_id, $callback);
    }
    else {
        @download_args = ($video_id, $filename);
    }

    eval { $NICOVIDEO->download(@download_args) };
    print "\n";    # go to next line of progressbar.
    if ($@) {
        warn "$@\n";
    }
    else {
        debug 1, "downloading video '$filename'...done!";
    }
}

# Get and store info from *video ID*.
sub fetch_meta_data {
    my ($video_id) = @_;

    # Fetch meta data using getthumbinfo API.
    my $URL = "http://ext.nicovideo.jp/api/getthumbinfo/$video_id";
    my $res = $NICOVIDEO->user_agent->get($URL);
    unless ($res->is_success) {
        die "Can't fetch meta data: ".$res->status_line;
    }
    my $xml = XML::Simple::XMLin($res->decoded_content);

    return {
        video_id => $video_id,
        title    => $xml->{thumb}{title},
        ext      => $xml->{thumb}{movie_type},
    };
}

# Make callback for WWW::NicoVideo::Download::download().
# This subroutine is called only unless --no-progressbar was given.
sub make_progressbar_callback {
    my ($filename, $video, $title) = @_;

    my $wfh = IO::File->new($filename, 'w') or do {
        warn "skipping '$video'... can't open '$filename' for writing.\n";
        return;
    };
    binmode $wfh;

    my $term;
    return sub {
        my($data, $res, $proto) = @_;
        $term ||= Term::ProgressBar->new($res->header('Content-Length'));
        $term->update($term->last_update + length $data);
        print $wfh $data;
    };
}

# Download *mylist*.
sub download_mylist {
    my ($mylist, $file_path, $opt) = @_;

    debug 1, "downloading mylist '$mylist'...";
    for my $video (get_videos_from_mylist($mylist)) {
        download_video($video, $file_path, $opt);
    }
    debug 1, "downloading mylist '$mylist'...done!";
}

# Returns array of *video*s from *mylist*.
sub get_videos_from_mylist {
    my ($mylist) = @_;

    # Get mylist ID from $mylist.
    my $mylist_id = get_mylist_id($mylist) // do {
        warn "skipping '$mylist'... can't find mylist ID.\n";
        return; # empty list
    };

    # Get RSS feed from $mylist_id.
    my $feed_uri = URI->new("http://www.nicovideo.jp/mylist/$mylist_id?rss=2.0");
    debug 2, "feed URI = $feed_uri";

    # Parse RSS feed.
    my $feed = XML::Feed->parse($feed_uri) or do {
        warn "skipping '$mylist'... "
            . "error occurred while parsing RSS: "
            . XML::Feed->errstr(), "\n";
        return; # empty list
    };

    return map { $_->link } $feed->entries;
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

# Returns *mylist ID* from *mylist*
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

# Returns true if argument is *mylist*.
# Returns false otherwise.
sub is_mylist {
    my ($arg) = @_;
    return defined get_mylist_id($arg);
}

# Returns true if argument is *video*.
# Returns false otherwise.
sub is_video {
    my ($arg) = @_;
    return defined get_video_id($arg);
}



### Parse arguments.
my $email;
my $password;
my $opt = {
    progress        => 1,
    overwrite       => 0,
    filename_format => '${title}.${ext}',
};
GetOptions(
    'h'                 => sub { usage(1) },
    'help'              => sub { usage(2) },
    'email=s'           => \$email,
    'password=s'        => \$password,
    'no-progress'       => sub { $opt->{progress} = 0 },
    'overwrite'         => \$opt->{overwrite},
    'q|quiet'           => sub { $DEBUG_LEVEL-- },
    'v|verbose'         => sub { $DEBUG_LEVEL++ },
    'filename-format=s' => \$opt->{filename_format},
) or usage();
usage() unless @ARGV;

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
    warn "--email and --password are required.\n";
    warn "\n";
    warn "You can use config file if you installed Config::Pit module.\n";
    exit -1;
}

### Initialize $NICOVIDEO.
debug 2, "email: $email";
debug 2, "password: $password";
$NICOVIDEO = WWW::NicoVideo::Download->new(
    email    => $email,
    password => $password,
);

### Auto-conversion from Perl internal encoding to terminal encoding.
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

### Start downloading.
my $arg = shift;
my $file_path = shift // '.';
debug 2, "first arg: $arg";
debug 2, "file_path: $file_path";
if (is_video($arg)) {
    # Download and save the video to $file_path.
    download_video($arg, $file_path, $opt);
}
elsif (is_mylist($arg)) {
    # Download and save all videos in the mylist to $file_path.
    download_mylist($arg, $file_path, $opt);
}
else {
    die "error: don't know what to do for '$arg'.\n";
}



__END__

=head1 NAME

    dlnico.pl - NicoVideo downloader


=head1 SYNOPSIS

    $ dlnico.pl {video or mylist} [{saved directory}]

    {video}
        video URI or number prefixed with "sm" or "nm".

    {mylist}
        mylist URI or number.

    {saved directory}
        the directory where downloaded video(s) are saved.
        default value is "." (current directory) .


    $ dlnico.pl http://www.nicovideo.jp/mylist/22370493  # download all videos in mylist
    $ dlnico.pl 22370493                                 # same as above
    $ dlnico.pl http://www.nicovideo.jp/watch/sm14043624 # download the video
    $ dlnico.pl sm14043624                               # same as above


=head1 OPTIONS

=over

=item -h

Show short help.

=item --help

Show long help.

=item --email {email}

Your email (as ID).

if you have installed Config::Pit,
and does not specify C<--email>,
Config::Pit::pit_get() will invoke.

=item --password {password}

Your password.

if you have installed Config::Pit,
and does not specify C<--email>,
Config::Pit::pit_get() will invoke.

=item --progress

Show progress while downloading.

=item --overwrite

Default behavior is that
if there is already a file
on the path of saving movie file, skip it.
but overwrite it if you specify this C<--overwrite> option.

=item -q, --quiet

Run quietly.

=item -v, --verbose

Run verbosely.

=back


=head1 TODO

=over

=item parallel download using Coro.

=item write about C<--filename-format> syntax.

=item add available keys in C<--filename-format> syntax.

=item test, test, test.

=back


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
