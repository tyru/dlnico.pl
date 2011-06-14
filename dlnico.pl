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


my $NICOVIDEO = WWW::NicoVideo::Download->new;


sub usage () {
    pod2usage(-verbose => 1);
}

sub download_mylist {
    my ($mylist) = @_;

    for my $video (get_videos_from_mylist($mylist)) {
        download_video($video);
    }
}

sub get_videos_from_mylist {
    my ($mylist) = @_;

    ...
}

sub download_video {
    my ($video) = @_;
}


my $needhelp;
GetOptions(
    'h|help' => \$needhelp,
) or usage;
usage if $needhelp;
usage unless @ARGV;

download_mylist(shift);



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
