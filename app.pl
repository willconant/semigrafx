use Mojolicious::Lite;

BEGIN {
    unshift @INC, './lib';
};

use Semigrafx::Parser;
use Semigrafx::Transformer;
use JSON;

my $test_program = <<'END_PROGRAM'
init() {
    @screen = buffer(1024)
    screen(@screen)

    @row = 16
    @col = 16
    set(@screen, add(mul(@row, 32), @col), 1)

    $msg = "Hello, world! "
    $x = 0
    while lt(mul($x, size($msg)), size(@screen)) {
        $dest = mul($x, size($msg))
        $len = least(sub(size(@screen), $dest), size($msg))
        copy(@screen, $msg, $dest, 0, $len)
        $x = add($x, 1)
    }
}

least($x, $y) {
    if lt($x, $y) {
        return $x
    }
    return $y
}

keydown($key) {
    if eq($key, 65) {
        move_hero(@row, add(@col, -1))
    }
    el eq($key, 68) {
        move_hero(@row, add(@col, 1))
    }
    el eq($key, 87) {
        move_hero(add(@row, -1), @col)
    }
    el eq ($key, 83) {
        move_hero(add(@row, 1), @col)
    }
}

move_hero($row, $col) {
    if gte($row, 32) {
        return 0
    }
    el gte($col, 32) {
        return 0
    }
    el lt($row, 0) {
        return 0
    }
    el lt($col, 0) {
        return 0
    }

    set(@screen, add(mul(@row, 32), @col), 0)
    @row = $row
    @col = $col
    set(@screen, add(mul(@row, 32), @col), 1)
}

END_PROGRAM
;

get '/' => sub {
    my $self = shift;
    $self->redirect_to('/index.html');
};

get '/program/:program_id.js' => sub  {
    my $self = shift;

    my $program_id = $self->param('program_id');

    my $source;
    if ($program_id eq '0') {
        $source = $test_program;
    }

    my $parsed = Semigrafx::Parser->parse($source);
    my $transformed = Semigrafx::Transformer->transform($parsed);

    my $json_source = JSON->new->allow_nonref->encode($source);

    my $output = "Semigrafx.programReady('$program_id', (function(p){ p.source = $json_source; return p; })($transformed));";
    $self->render(text => $output, format => 'js');
};

get '/program/:program_id.txt' => sub  {
    my $self = shift;

    my $program_id = $self->param('program_id');

    my $source;
    if ($program_id eq '0') {
        $source = $test_program;
    }

    $self->render(text => $source);
};

post '/compile' => sub {
    my $self = shift;

    my $source = $self->param('source');

    my $parsed = Semigrafx::Parser->parse($source);
    my $transformed = Semigrafx::Transformer->transform($parsed);

    my $json_source = JSON->new->allow_nonref->encode($source);

    my $output = "(function(p){ p.source = $json_source; return p; })($transformed)";
    $self->render(text => $output, format => 'txt');
};

app->start;
