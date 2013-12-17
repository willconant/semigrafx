package Semigrafx::Transformer;

use strict;

sub transform {
    my ($class, $program) = @_;
    return $class->new($program)->_transform();
}

sub new {
    my $class = shift;
    my $program = shift;

    my $self = {
        program => $program,
        strings => [],
        lines   => [],
    };

    return bless $self, $class;
}

sub _transform {
    my $self = shift;

    for my $function (@{ $self->{program}{functions} }) {
        $self->line(0);

        $self->line(1,
            "funcs.$function->{name} = function(",
            join(', ', @{ $function->{args} }),
            ') {',
        );

        $self->body(2, $function->{body});

        $self->line(1, '};');
    }

    $self->line(0);
    $self->line(1, 'return funcs;');

    $self->line(0, '}');

    my $output = <<'END_HEADER'
function(builtins) {
    var funcs = Object.create(builtins);
    var globals = {};
END_HEADER
;
    
    foreach my $string (@{ $self->{strings} }) {
        $output .= "    funcs.buffer([" . join(',', @$string) . "]);\n";
    }

    foreach my $line (@{ $self->{lines} }) {
        $output .= ('    ' x $line->[0]) . $line->[1] . "\n";
    }

    return $output;
}

sub line {
    my $self = shift;
    my $indent = shift;

    push @{ $self->{lines} }, [$indent, join('', @_)];
}

sub body {
    my $self = shift;
    my $indent = shift;
    my $body = shift;
    for my $statement (@$body) {
        my $method = "stmt_$statement->{type}";
        $self->$method($indent, $statement);
    }
}

sub stmt_assignment {
    my $self = shift;
    my $indent = shift;
    my $statement = shift;

    if (substr($statement->{name}, 0, 1) eq '@') {
        $self->line($indent,
            'globals.',
            substr($statement->{name}, 1),
            ' = ',
            $self->expression($statement->{value}),
            ';',
        );
    }
    else {
        $self->line($indent,
            "var $statement->{name} = ",
            $self->expression($statement->{value}),
            ';',
        );
    }
}

sub stmt_if {
    my $self = shift;
    my $indent = shift;
    my $statement = shift;

    $self->line($indent,
        'if (',
        $self->expression($statement->{condition}),
        ') {',
    );

    $self->body($indent + 1, $statement->{body});

    $self->line($indent, '}');

    for my $branch (@{ $statement->{branches} }) {
        if ($branch->{condition}) {
            $self->line($indent,
                'else if (',
                $self->expression($branch->{condition}),
                ') {',
            );
        }
        else {
            $self->line($indent,
                'else {',
            );
        }

        $self->body($indent + 1, $branch->{body});

        $self->line($indent, '}');
    }
}

sub stmt_while {
    my $self = shift;
    my $indent = shift;
    my $statement = shift;

    $self->line($indent,
        'while (',
        $self->expression($statement->{condition}),
        ') {',
    );

    $self->body($indent + 1, $statement->{body});

    $self->line($indent, '}');
}

sub stmt_return {
    my $self = shift;
    my $indent = shift;
    my $statement = shift;

    $self->line($indent,
        'return ',
        $self->expression($statement->{value}),
        ';',
    );
}

sub stmt_call {
    my $self = shift;
    my $indent = shift;
    my $statement = shift;

    $self->line($indent, $self->expression($statement), ';');
}

sub expression {
    my ($self, $expr) = @_;
    my $method = "expr_$expr->{type}";
    return $self->$method($expr);
}

sub expr_variable {
    my ($self, $expr) = @_;

    my $name = $expr->{name};

    if (substr($name, 0, 1) eq '@') {
        return 'globals.' . substr($name, 1);
    }
    else {
        return $name;
    }
}

sub expr_integer {
    my ($self, $expr) = @_;
    return $expr->{value};
}

sub expr_string {
    my ($self, $expr) = @_;
    push @{ $self->{strings} }, $expr->{value};
    return @{ $self->{strings} } - 1;
}

sub expr_call {
    my ($self, $expr) = @_;

    return 'funcs.'
            . $expr->{name}
            . '(' . join(', ', map { $self->expression($_) } @{ $expr->{args} }) . ')';
}

1;