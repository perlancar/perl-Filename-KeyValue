package Filename::KeyValue;

use 5.010001;
use strict;
use warnings;

use Exporter 'import';
use URI::Escape qw();

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(
                       parse_keyvalue_filename
               );
                       # normalize_keyvalue_filename

our %SPEC;

sub _decode_val {
    my ($opts, $kv, $key, $val) = @_;

    my @old_vals = exists($kv->{$key}) ? (ref($kv->{$key}) eq 'ARRAY' ? @{ $kv->{$key} } : ($kv->{$key})) : ();
    my @new_vals = split /,/, ($opts->{decode_value} ? URI::Escape::uri_unescape($val) : $val);
    my @vals = (@old_vals, @new_vals);
    if ($opts->{array_value} || @vals > 1) {
        $val = \@vals;
    } else {
        $val = $vals[0];
    }
}

$SPEC{parse_keyvalue_filename} = {
    v => 1.1,
    summary => 'Parse filename using the KeyValue naming scheme',
    description => <<'MARKDOWN',

The KeyValue naming scheme puts key=value pairs at the end of filename. Filename
must match this regex:

    /\A
     (?:
      (.+?)                                 # optional prefix (part before the first key)
      -
     )?
     (
     (?:
       ([A-Za-z_][A-Za_z0-9_]*)              # key
       =
       ([^-]*)                               # value
     )
     (?:
       -
       ([A-Za-z_][A-Za_z0-9_]*)
       =
       ([^-]*)
     )*
     (\.\w+)?                                # optional filename extension
     \z/x

KeyValue naming scheme is used in the AssetView media assets organization scheme
(see <pm:Media::AssetView>).

This routine parses a filename and return a structure containing parsed
elements.

MARKDOWN
    args => {
        filename => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
        array_value => {
            summary => 'Always/never/maybe return value as array',
            schema => ['int*', in => [0,1,2]],
            default => 1,
            description => <<'MARKDOWN',

The default (1) is to return a scalar when there is a single value, or an array
if there are multiple values, for example:

    foo-kw1=val1-kw2=val2,val2b-kw3=val3-kw1=val1b.jpg

then:

    kw1 = ['val1', 'val1b']
    kw2 = ['val2', 'val2b']
    kw3 = 'val3'

The setting 0 means to never return array, so will return a comma-separated
string instead. However, if the value is URI-decoded then this can potentially
be ambiguous:

    kw1=val1,val2-kw1=val3%2cval4.jpg

under array_value=0 and decode_value=1 will return:

    kw1 = 'val1,val2,val3,val4'

while under array_value=1 or 2 will return 3 elements:

    kw1 = ['val1', 'val2', 'val3,val4']

MARKDOWN
        },
        decode_value => {
            summary => 'Whether to decode value with URI-encoding',
            schema => 'bool*',
            default => 1,
        },
        # opt: case_insensitive
        # opt: check duplicate key
        # opt: required_keys
        # opt: required_value or schema for values
    },
    examples => [
        {
            args => {filename=>'foo-bar-kw1=val1.jpg'},
            summary => 'A single key=value pair',
        },
        {
            args => {filename=>'foo-bar-kw1=val1-kw2=val2.jpg'},
            summary => 'Two key=value pairs',
        },
        {
            args => {filename=>'foo-bar-kw1=val1,val1b.jpg'},
            summary => 'A single key=value pair containing two values',
        },
        {
            args => {filename=>'foo-bar-kw1=val1-kw2=val2,val2b,val2c-kw3=val3.jpg'},
            summary => 'Three key=value pairs, one containing multiple values',
        },
        {
            args => {filename=>'foo-bar-kw1=-kw2=-kw3=val.jpg'},
            summary => 'Empty key=value pairs',
        },
        {
            args => {filename=>'foo-bar-kw1_containing_dash=containing%2ddash-kw2_also_containing_dash=containing%2Dtwo%2Ddashes.jpg'},
            summary => 'A value containing dash',
        },
        {
            args => {filename=>'foo-bar-kw1=containing%2ccomma.jpg'},
            summary => 'A value containing comma',
        },
    ],
};
sub parse_keyvalue_filename {
    my %args = @_;

    defined(my $filename = $args{filename}) or return [400, "Please specify filename"];
    my $res = {};

    my $opts = {};
    $opts->{array_value}  = delete($args{array_value}) // 0;
    $opts->{decode_value} = delete($args{decode_value}) // 1;

    $filename =~ s!/+\z!!;

    length($filename) or return [400, "Filename cannot be empty"];
    $filename =~ s/\.(\w+)\z// and $res->{ext} = $1;

    $filename =~ /
                  \A
                  (?:
                      (.+?)                                     # optional prefix (part before the first key)
                      -
                  )?
                  (?:
                      (
                          (?:
                              (?:[A-Za-z_][A-Za-z0-9_]*)        # key
                              =
                              (?:[^-]*)                         # value
                          )
                          (?:
                              -
                              (?:
                                  (?:[A-Za-z_][A-Za-z0-9_]*)        # key
                                  =
                                  (?:[^-]*)                         # value
                              )
                          )*?
                      )
                  )?
                  \z/x
                      or return [400, "Invalid filename syntax, must be in (PREFIX-)?(KW=VAL)*(.EXT)? format"];
    $res->{prefix} = $1 // '';
    $res->{kv_raw} = $2 // '';
    $res->{kv} = {};
    if (length $res->{kv_raw}) {
        while ($res->{kv_raw} =~ /([A-Za-z_][^=]*)=([^-]+)/g) {
            $res->{kv}{$1} = _decode_val($opts, $res->{kv}, $1, $2);
        }
    }
    [200, "OK", $res];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

 use Filename::KeyValue qw(
     parse_keyvalue_filename
     normalize_keyvalue_filename
 );


=head1 DESCRIPTION


=head1 SEE ALSO

=cut
