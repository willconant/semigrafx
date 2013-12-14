use Mojolicious::Lite;

BEGIN {
    unshift @INC, './lib';
};

use Semigrafx::Parser;
use Semigrafx::Transformer;

my $test_program = <<'END_PROGRAM'
init() {
    @screen = buffer(1024)
    screen(@screen)

    @row = 16
    @col = 16
    set(@screen, add(mul(@row, 32), @col), 1)
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

get '/test_program.js' => sub  {
    my $self = shift;
    my $parsed = Semigrafx::Parser->new($test_program)->parse();
    my $transformed = Semigrafx::Transformer::transform($parsed);
    $self->render(text => 'var TestProgram = ' . $transformed);
};

app->start;
