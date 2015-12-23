
# Usage

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

# Installation

## Carton and cpanminus

*Skip this step if you already installed both.*

Install Carton and cpanminus under `~/perl5`.

    $ cat ~/.bash_profile
    (省略)
    
    mkdir -p $HOME/perl5
    [ "$PERL5LIB" ] && export PERL5LIB="$HOME/perl5/lib/perl5:$PERL5LIB" || export PERL5LIB="$HOME/perl5/lib/perl5"
    [ "$PATH" ] && export PATH="$HOME/perl5/bin:$PATH" || export PATH="$HOME/perl5/bin"
    
    $ . ~/.bash_profile
    $ curl -L https://cpanmin.us | perl - -L $HOME/perl5 App::cpanminus Carton
    
## dlnico.pl

    $ git clone https://github.com/tyru/dlnico.pl
    $ cd dlnico.pl
    $ carton
    
In addition, if you want to save your email and password into `~/.pit/default.yaml`,<br/>
(if you **DON'T** want to specify your email and password by command-line arguments)

    $ cpanm -L local Config::Pit


# Options

    -h  Show short help.

    --help
        Show long help.

    --email {email}
        Your email (as ID).

        if you have installed Config::Pit, and does not specify "--email",
        Config::Pit::pit_get() will invoke.

    --password {password}
        Your password.

        if you have installed Config::Pit, and does not specify "--email",
        Config::Pit::pit_get() will invoke.

    --progress
        Show progress while downloading.

    --overwrite
        Default behavior is that if there is already a file on the path of
        saving .flv file, skip it. but overwrite it if you specify this
        "--overwrite" option.

    -q, --quiet
        Run quietly.

    -v, --verbose
        Run verbosely.

