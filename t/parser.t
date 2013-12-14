use strict;
use warnings;
use utf8;

BEGIN {
    unshift @INC, './lib';
}

use Test::Simple qw(no_plan);
use Semigrafx::Parser;
use Semigrafx::Transformer;

my $source = <<'END_SOURCE'
init($y) {
    $x = 5
}
END_SOURCE
;

my $parsed = Semigrafx::Parser->new($source)->parse();

ok(ref($parsed) eq 'HASH', 'it is a hash');
ok(join(' ', sort keys %$parsed) eq 'functions type', 'has right keys');
ok($parsed->{type} eq 'program', 'type => program');
ok(ref($parsed->{functions}) eq 'ARRAY', 'ref(functions) => ARRAY');
ok(@{ $parsed->{functions} } == 1, 'exactly one function');
ok($parsed->{functions}[0]{name} eq 'init', 'function named init');
ok(join(' ', @{ $parsed->{functions}[0]{args} }) eq '$y', 'arg named $y');
ok(@{ $parsed->{functions}[0]{body} } == 1, 'one statement');
ok($parsed->{functions}[0]{body}[0]{type} eq 'assignment', 'is assignment');
ok($parsed->{functions}[0]{body}[0]{name} eq '$x', 'assign to var $x');
ok($parsed->{functions}[0]{body}[0]{value}{type} eq 'integer', 'integer expression');
ok($parsed->{functions}[0]{body}[0]{value}{value} eq '5', 'integer expression with value 5');
