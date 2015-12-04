use strict;
use warnings;
use Module::Build;
use Module::Build::Pluggable qw(
    CPANfile
);

my $builder = Module::Build::Pluggable->new(
    license              => 'perl',
    name                 => 'dlnico',
    dist_name            => 'dlnico',
    dist_version         => '1.0',
    dist_author          => 'tyru <tyru.exe@gmail.com>',
    dist_abstract        => 'NicoVideo Downloader',
    module_name          => 'dlnico',
);
$builder->create_build_script;
