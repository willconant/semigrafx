package Semigrafx::Parser;

use strict;

sub new {
    my ($class, $source) = @_;

    my $self = {
        source => $source,
    };

    pos($self->{source}) = 0;

    return bless $self, $class;
}

sub parse {
    my $self = shift;

    my $functions = [];

    FUNCTIONS:
    for (;;) {
        if ($self->{source} =~ m/ \G \s* $ /xgc) {
            last FUNCTIONS;
        }

        push @$functions, $self->parse_function();
    }

    return {
        type      => 'program',
        functions => $functions,
    };
}

sub parse_function {
    my $self = shift;

    if ($self->{source} !~ m/ \G \s* (\w+) \( /xgc) {
        die "invalid function declaration";
    }

    my $name = $1;
    my $args = [];

    ARGS:
    for (;;) {
        if ($self->{source} =~ m/ \G \s* \) /xgc) {
            last ARGS;
        }
        elsif ($self->{source} =~ m/ \G \s* (\$\w+) /xgc) {
            push @$args, $1;

            if ($self->{source} =~ m/ \G \s* \) /xgc) {
                last ARGS;
            }
            elsif ($self->{source} !~ m/ \G \s* , /xgc) {
                die "expected ,";
            }
        }
        else {
            die "invalid arg";
        }
    }

    if ($self->{source} !~ m/ \G \s* \{ /xgc) {
        die "expected {";
    }

    my $body = $self->parse_block();

    return {
        type => 'function',
        name => $name,
        args => $args,
        body => $body,
    };
}

sub parse_block {
    my $self = shift;

    my $statements = [];

    STATEMENTS:
    for (;;) {
        if ($self->{source} =~ m/ \G \s* \} /xgc) {
            last STATEMENTS;
        }
        else {
            push @$statements, $self->parse_statement();
        }
    }

    return $statements;
}

sub parse_statement {
    my $self = shift;

    if ($self->{source} =~ m/ \G \s* ([\@\$]\w+) /xgc) {
        # assignment to var
        my $name = $1;

        if ($self->{source} !~ m/ \G \s* =/xgc) {
            die "expected =";
        }

        my $value = $self->parse_expr();

        return {
            type  => 'assignment',
            name  => $name,
            value => $value,
        };
    }
    elsif ($self->{source} =~ m/ \G \s* if \s+ /xgc) {
        # if statement
        my $condition = $self->parse_expr();

        if ($self->{source} !~ m/ \G \s* \{ /xgc) {
            die "expected {";
        }

        my $body = $self->parse_block();
        my $branches = [];

        BRANCHES:
        for (;;) {
            if ($self->{source} =~ m/ \G \s* el \s+ /xgc) {
                if ($self->{source} =~ m/ \G \{ /xgc) {
                    push @$branches, { body => $self->parse_block() };
                    last BRANCHES;
                }
                else {
                    my $branch = {
                        condition => $self->parse_expr(),
                    };

                    if ($self->{source} !~ m/ \G \s* \{ /xgc) {
                        die "expected {";
                    }

                    $branch->{body} = $self->parse_block();

                    push @$branches, $branch;
                }
            }
            else {
                last BRANCHES;
            }
        }

        return {
            type      => 'if',
            condition => $condition,
            body      => $body,
            branches  => $branches,
        };
    }
    elsif ($self->{source} =~ m/ \G \s* while \s+ /xgc) {
        # while statement
        my $condition = $self->parse_expr();

        if ($self->{source} !~ m/ \G \s* \{ /xgc) {
            die "expected {";
        }

        my $body = $self->parse_block();

        return {
            type      => 'while',
            condition => $condition,
            body      => $body
        };
    }
    elsif ($self->{source} =~ m/ \G \s* return \s+ /xgc) {
        # return statement
        return {
            type   => 'return',
            value  => $self->parse_expr(),
        };
    }
    elsif ($self->{source} =~ m/ \G \s* ([a-zA-Z_]\w*) \(/xgc) {
        # call statement
        my $name = $1;
        my $args = $self->parse_args();

        return {
            type => 'call',
            name => $name,
            args => $args,
        };
    }
    else {
        die "invalid statement";
    }
}

sub parse_expr {
    my $self = shift;

    if ($self->{source} =~ m/ \G \s* ([\@\$]\w+) /xgc) {
        # variable expression
        return {
            type => 'variable',
            name => $1,
        }
    }
    elsif ($self->{source} =~ m/ \G \s* (-?\d+) /xgc) {
        # integer expression
        return {
            type => 'integer',
            value => int($1),
        };
    }
    elsif ($self->{source} =~ m/ \G \s* ([a-zA-Z_]\w*) /xgc) {
        # call expression
        my $name = $1;

        if ($self->{source} !~ m/ \G \s* \( /xgc) {
            die "expected ("
        }

        my $args = $self->parse_args();

        return {
            type => 'call',
            name => $name,
            args => $args,
        };
    }
    elsif ($self->{source} =~ m/ \G \s* " /xgc) {
        # string expression
        my $value = '';

        STRING:
        for (;;) {
            if ($self->{source} =~ m/ \G ([^"\\]*) \\ /xgc) {
                # handle backslash
                $value .= $1;

                if ($self->{source} !~ m/ \G (["\\]) /xgc) {
                    die "expected \" or \\";
                }

                $value .= $1;
            }
            elsif ($self->{source} =~ m/ \G ([^"\\]*) " /xgc) {
                # close quote
                $value .= $1;
                last STRING;
            }
            else {
                die "expected \"";
            }
        }

        return {
            type => 'string',
            value => [map { ord } split //, $value],
        };
    }
    elsif ($self->{source} =~ m/ \G \s* %\{ /xgc) {
        # buffer expression
        if ($self->{source} !~ m/ \G ([\s\.A-F0-9]*) \} /xgc) {
            die "invalid buffer";
        }

        my $hex = $1;
        $hex =~ s/\s+//g;
        $hex =~ tr/./0/;

        if (length($hex) % 2 != 0) {
            die "expected even number of hex digits";
        }

        my @octets = map { hex } ($hex =~ m/../g);

        return {
            type => 'string',
            value => \@octets,
        };
    }
    else {
        die "invalid expression";
    }
}

sub parse_args {
    my $self = shift;

    my $args = [];

    ARGS:
    for (;;) {
        if ($self->{source} =~ m/ \G \s* \) /xgc) {
            last ARGS;
        }
        else {
            push @$args, $self->parse_expr();

            if ($self->{source} =~ m/ \G \s* \) /xgc) {
                last ARGS
            }
            elsif ($self->{source} =~ m/ \G \s* , /xgc) {
                next ARGS;
            }
            else {
                die "unexpected token in args";
            }
        }
    }

    return $args
}

1;
