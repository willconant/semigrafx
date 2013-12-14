package Semigrafx::Transformer;

use strict;

sub transform {
    my $program = shift;

    my $output = <<'END_HEADER'
function(builtins) {
    var funcs = Object.create(builtins);
    var globals = {};
END_HEADER
;

    my $line;
    my $body;
    my %statements;
    
    $line = sub {
        my $indent = shift;
        $output .= ' ' x ($indent*4);
        $output .= join('', @_);
        $output .= "\n";
    };

    $body = sub {
        my $indent = shift;
        my $body = shift;
        for my $statement (@$body) {
            $statements{ $statement->{type} }->($indent, $statement);
        }
    };

    %statements = (
        assignment => sub {
            my $indent = shift;
            my $statement = shift;

            if (substr($statement->{name}, 0, 1) eq '@') {
                $line->($indent,
                    'globals.',
                    substr($statement->{name}, 1),
                    ' = ',
                    expression($statement->{value}),
                    ';',
                );
            }
            else {
                $line->($indent,
                    "var $statement->{name} = ",
                    expression($statement->{value}),
                    ';',
                );
            }
        },
        if => sub {
            my $indent = shift;
            my $statement = shift;

            $line->($indent,
                'if (',
                expression($statement->{condition}),
                ') {',
            );

            $body->($indent + 1, $statement->{body});

            $line->($indent, '}');

            for my $branch (@{ $statement->{branches} }) {
                if ($branch->{condition}) {
                    $line->($indent,
                        'else if (',
                        expression($branch->{condition}),
                        ') {',
                    );
                }
                else {
                    $line->($indent,
                        'else {',
                    );
                }

                $body->($indent + 1, $branch->{body});

                $line->($indent, '}');
            }
        },
        while => sub {
            my $indent = shift;
            my $statement = shift;

            $line->($indent,
                'while (',
                expression($statement->{condition}),
                ') {',
            );

            $body->($indent + 1, $statement->{body});

            $line->($indent, '}');
        },
        return => sub {
            my $indent = shift;
            my $statement = shift;

            $line->($indent,
                'return ',
                expression($statement->{value}),
                ';',
            );
        },
        call => sub {
            my $indent = shift;
            my $statement = shift;

            $line->($indent, expression($statement), ';');
        }
    );

    for my $function (@{ $program->{functions} }) {
        $line->(0);

        $line->(1,
            "funcs.$function->{name} = function(",
            join(', ', @{ $function->{args} }),
            ') {',
        );

        $body->(2, $function->{body});

        $line->(1, '};');
    }

    $line->(0);
    $line->(1, 'return funcs;');

    $line->(0, '}');

    return $output;
}

BEGIN { 
    my %expressions = (
        variable => sub {
            my $name = shift()->{name};
            if (substr($name, 0, 1) eq '@') {
                return 'globals.' . substr($name, 1);
            }
            else {
                return $name;
            }
        },
        integer  => sub { shift()->{value} },
        string   => sub { '[' . join(',', @{ shift()->{value} }) . ']' },
        call     => sub {
            my $expression = shift;
            'funcs.'
                . $expression->{name}
                . '(' . join(', ', map { expression($_) } @{ $expression->{args} }) . ')';
        },
        index => sub {
            my $indices = shift()->{indices};
            if (@$indices == 2) {
                return 'bufGet1d(' . join(', ', map { expression($_) } @$indices) . ')';
            }
            else {
                return 'bufGet2d(' . join(', ', map { expression($_) } @$indices) . ')';
            }
        },
    );

    sub expression {
        my $expression = shift;
        $expressions{ $expression->{type} }->($expression);
    }
}

1;