#!/usr/bin/perl

my @python = ("#!/usr/local/bin/python3.5 -u\n", "import sys, re, fileinput, copy\n", "\n");                # Holds python code - header and imports at the top
my @perl;                                                                                                   # Array - stores perl code
my $spaces = "";                                                                                            # Keeps track of indentation
my @for;                                                                                                    # Used for c-style for loops
my @forSpaces;                                                                                              # ^
my $braceCount = 0;                                                                                         # Used for indentation

while (<>) {                                                                                                # Push perl code to array
    push @perl, $_;
}

runCode(\@perl);                                                                                            # Run through code line by line

print @python;                                                                                              # Print the python code



#SUBROUTINES

sub runCode {
    @code = @{$_[0]};
    foreach $line (@code) {
        if ($line =~ /^\s*print[^f]/) {                                                                     # print
            my $toPush = printFunction($line);
            $toPush = "$spaces$toPush";
            push (@python, $toPush);
        } elsif ($line =~ /^\s*}?\s*(#.*)$/) {                                                              # comment
            if ($line =~ /^\s*#!.*/) {
                # do nothing
            } else {
                push (@python, "$spaces$1\n");
            }
        } elsif ($line =~ /^(?:\s*my)?\s*\$\w*\s*(=|\+=|\-=|\*=|\/=|%=|\*\*=|=~)\s*.*;/) {                  # variable
            if ($line =~ /^\s*\$(\w*)\s*=~\s*(.*);(.*)/) {                                                  # regex
                my $var = $1;
                my $regex = $2;
                my $end = $3;
                if ($regex =~ /^\/(.*)\/(\w*)$/) {                                                          # regex - match
                    (my $match, my $flag) = ($1, uc $2);
                    my $tmp = "match";
                    if ($flag eq 'G') {                                                                     # if global flag
                        $tmp = "findall";
                    }
                    if (length $flag > 0) {
                        $flag = ", re.$flag";
                    }
                    push @python, "$spaces$var = re.$tmp(r'$regex', $var)$end\n";
                } elsif ($regex =~ /^\s*s\/(.*)\/(.*)\/(\w*)$/) {                                           # regex - sed
                    (my $regex, my $replace, my $flag) = ($1, $2, uc $3);
                    if (length $flag > 0) {
                        $flag = ", re.$flag";
                    }
                    push @python, "$spaces$var = re.sub(r'$regex', '$replace', $var)$end\n";
                }
            } else {
                my $toPush = variableDeclaration($line);
                $toPush = "$spaces$toPush";
                push (@python, $toPush);
            }
        } elsif ($line =~ /^(?:\s*my)?\s*@\w*/) {                                                           # array
            my $toPush = arrayDeclaration($line);
            push (@python, "$spaces$toPush");
        } elsif ($line =~ /^\s*%\w+/) {                                                                     # hash
            if ($line =~ /^\s*%(\w+\s*=\s*{})\s*;(.*)/) {
                push @python, "$spaces$1$2\n"
            } else {
                push @python, "$spaces# hash: $line\n";
            }
        } elsif ($line =~ /^\s*$/) {                                                                        # empty line
            push (@python, "$spaces$line");
        } elsif ($line =~ /^\s*if\s*\([^\)]*\)/) {                                                          # if statement
            my $toPush = ifStatement($line);
            $toPush = "$spaces$toPush";
            push (@python, $toPush);
        } elsif ($line =~ /^\s*}?\s*elsif\s*\([^\)]*\)/) {                                                  # elsif statement
            my $toPush = ifStatement($line);
            $toPush = "$spaces$toPush";
            $toPush =~ s/if/elif/;
            if ($line =~ /^\s*}/) {
                $toPush =~ s/\t//;
            }
            push (@python, $toPush);
        } elsif ($line =~ /^\s*}?\s*else\s*{(.*)$/) {                                                       # else statement
            my $toPush = "${spaces}else:$1\n";
            if ($line =~ /^\s*}/) {
                $toPush =~ s/\t//;
            }
            push (@python, $toPush);
        } elsif ($line =~ /^\s*while\s*\([^\)]*\)/) {                                                       # while loop
            my $toPush = whileLoop($line);
            $toPush = "$spaces$toPush";
            push (@python, $toPush);
        } elsif ($line =~ /^\s*foreach\s*/) {                                                               # foreach loops
            my $toPush = foreachLoop($line);
            $toPush = "$spaces$toPush";
            push (@python, $toPush);
        } elsif ($line =~ /^\s*for\s*/) {                                                                   # for loops
            if ($line =~ /^\s*for\s*(\$\w*)?\s*\([^;]*\)/) {                                                # perl style for loops
                $line =~ s/for/foreach/;
                my $toPush = foreachLoop($line);
                $toPush = "$spaces$toPush";
                push (@python, $toPush);
            } else {                                                                                        # c style for loops
                my $temp = forLoop($line);
                my @condition = @$temp;
                my $end = $condition[3];
                foreach (@condition) {
                    $_ =~ s/^\s*//;
                }
                $condition[2] =~ s/\+\+/ \+= 1/;
                $condition[2] =~ s/\-\-/ \-= 1/;
                push @for, "\t$spaces$condition[2]\n";
                push @forSpaces, $braceCount;
                push @python, "$spaces$condition[0]\n";
                push @python, "${spaces}while $condition[1]:$end\n";
            }
        } elsif ($line =~ /^\s*}\s*$/) {                                                                    # just a '}' character
            push @python, "$spaces\n";
        } elsif ($line =~ /^\s*\$(\w*)\s*(\+\+|\-\-)\s*;(.*)/) {                                            # increment or decrement
            my $var = $1;
            my $end = $3;
            my $change = $2;
            my $toPush;
            if ($change =~ /\+\+/) {
                $toPush = "$var += 1$end\n";
            } elsif ($change =~ /\-\-/) {
                $toPush = "$var -= 1$end\n";
            }
            push @python, "$spaces$toPush";
        } elsif ($line =~ /^\s*last;(.*)$/) {                                                               # last statement
            push @python, "${spaces}break$1\n";
        } elsif ($line =~ /^\s*next;(.*)$/) {                                                               # next statement
            push @python, "${spaces}continue$1\n";
        } elsif ($line =~ /^\s*exit;(.*)$/) {                                                               # exit statement
            push @python, "${spaces}quit()$1\n";
        } elsif ($line =~ /chomp\s*\(?([^\);\s]*)\)?\s*;(.*)/) {                                            # chomp statement;
            my $var = $1;
            my $end = $2;
            $var =~ s/\$//;
            push @python, "$spaces$var = $var.rstrip()$end\n";
        } elsif ($line =~ /^\s*push\s*\(?\s*(.*)\s*,\s*([^\)]*)\s*\)?\s*;(.*)/) {                           # push statement
            (my $array, my $append, my $end) = ($1, $2, $3);
            $array =~ s/^@//;
            if ($append =~ /^\$/) {                                                                         # push variable
                $append =~ s/^\$//;
                push @python, "$spaces$array.append($append)$end\n";
            } elsif ($append =~ /^@/) {                                                                     # push array
                $append =~ s/^@//;
                push @python, "$spaces$array.extend($append)$end\n";
            } else {                                                                                        # push anything else
                $append = interpolate4Declaration($append);
                push @python, "$spaces$array.append($append)$end\n";
            }
        } elsif ($line =~ /^\s*pop\s*\(?\s*([^\)]*)\s*\)?\s*;(.*)/) {                                       # pop statement
            (my $array, my $end) = ($1, $2);
            $array =~ s/^@//;
            push @python, "$spaces$array.pop()$end\n";
        } elsif ($line =~ /^\s*shift\s*\(?\s*([^\)]*)\s*\)?\s*;(.*)/) {                                     # shift statement
            (my $array, my $end) = ($1, $2);
            $array =~ s/^@//;
            push @python, "$spaces$array.pop(0)$end\n";
        } elsif ($line =~ /^\s*unshift\s*\(?\s*(.*)\s*,\s*([^\)]*)\s*\)?\s*;(.*)/) {                        # unshift statement
            (my $array, my $unshift, my $end) = ($1, $2, $3);
            $array =~ s/^@//;
            if ($unshift =~ /^\$/) {                                                                        # unshift variable
                $unshift =~ s/^\$//;
                push @python, "$spaces$array.insert(0, $unshift)$end\n";
            } elsif ($unshift =~ /^@/) {                                                                    # unshift array
                $unshift =~ s/^@//;
                push @python, "$spaces$array.reverse()$end\n";
                push @python, "$spaces$unshift.reverse()\n";
                push @python, "$spaces$array.extend($unshift)\n";
                push @python, "$spaces$array.reverse()\n";
            } else {                                                                                        # unshift anything else
                $unshift = interpolate4Declaration($unshift);
                push @python, "$spaces$array.insert(0, $unshift)$end\n";
            }
        } elsif ($line =~ /^\s*printf\s*\(?\s*(".*")\s*,\s*(.*)\s*\)?\s*;(.*)/) {                           # simple printf statements
            my $string = $1;
            my $vars = $2;
            $vars =~ s/\)$//;
            $vars =~ s/\$//g;
            my $end = $3;
            $string =~ s/%((?:(\d*\.)?\d+)?[\w%])/{:$1}/g;
            push @python, "${spaces}print($string.format($vars)),\n";
        } else {                                                                                            # not handled
            push @python, "$spaces# not handled: $line";
        }
        if ($line =~ /{/) {                                                                                 # braceCount keeps track of open braces
            $spaces = "$spaces\t";                                                                          # and accordingly adjusts indentation
            $braceCount++;
        }
        if ($line =~ /}/) {                                                                                 # handles end of c-style for loop
            $braceCount--;
            if (@for) {
                if ($braceCount == $forSpaces[-1]) {
                    my $f = pop(@for);
                    push @python, "$f";
                    pop @forSpaces;
                }
            }
            chop($spaces);
        }
    }
}

sub printFunction {
    $_[0] =~ /\s*print\s*\(?(.*)\)?;?(.*)\n/;
    my $stringLiteral = $1;                                                                                 # Extract string to be printed
    $stringLiteral =~ s/\)?;.*//;
    my $end = $2;
    my @matches = $stringLiteral =~ /("[^"]*"|(?<!\\)(?:[\$@]#?\w*(?:\[\$?\w*\])?(?:\s*(?:\+|\*|\-|\/|\%|\*\*)\s*\$\w*)*)|(?<![\$@])join\s*\(.*\)|<.*>)/g;
    foreach $m (@matches) {                                                                                 # Extracts comma separated parts of a print statment
        if ($m =~ /^".*"$/) {                                                                               # Handle interpolation if surrounded by quotes
            my @var = $m =~ /(?<!\\)[\$@]#?\{?\w*\}?(?:\[.*\])?/g;                                          # Extract array of variable names
            $m =~ s/(?<!\\)[\$@]#?\{?\w*\}?(?:\[.*\])?/\{\}/g;                                              # Replace variables (if operator - replaces more) with a single {}
            foreach $n (@var) {
                if ($n =~ /\$#/) {
                    $n =~ s/\$#//;
                    $n = "len($n) - 1";
                }
                $n =~ s/\$//g;                                                                              # Remove $ sign from variable names
                $n =~ s/(?<=@)ARGV/sys.argv[1:]/;
                $n =~ s/ARGV\[/sys.argv[1 + /;
                if ($n =~ /^@/) {
                    $n =~ s/@//;
                    $n = "' '.join($n)";
                }
                $n =~ s/^\{//;
                $n =~ s/\}$//;
            }
            $v = join(', ', @var);
            $m = "$m";
            if (length $v > 0) {
                $m = "$m.format($v)";
            } else {
                $m = "$m";
            }
        } elsif ($m =~ /^join\(\s*(.*)\s*\)/) {                                                             # Join statement
            (my $delim, my $array) = $1 =~ /('.*')[,\s]*(.*)/;
            $m =~ s/join\(\s*(.*)\s*\)/{}/;
            $m = joinFunction($delim, $array);
        } else {
            if ($m =~ /\$#/) {
                $m =~ s/\$#//;
                $m = "len($m) - 1";
            }
            $m =~ s/\$//g;                                                                                  # Remove $ signs
            $m =~ s/<STDIN>/sys.stdin.read\(\)/;                                                            # If from stdin
        }
    }
    my $retval = join(", ", @matches);
    return "print ($retval, sep='', end='')$end\n";
}

sub variableDeclaration {                                                                                   # Declares a variable
    $_[0] =~ /\s*\$(\w*)\s*(=|\+=|\-=|\*=|\/=|%=|\*\*=)\s*(.*);(.*)\n/;
    my $name = $1;
    my $operator = $2;
    my $declaration = $3;
    my $end = $4;
    my $formattedDec = interpolate4Declaration($declaration);
    if ($formattedDec =~ /^"\d+"$/) {
        $formattedDec =~ s/"//g;
    }
    return "$name $operator $formattedDec$end\n";
}

sub interpolate4Declaration {                                                                               # Interpolate variables - works similar to print
    my $stringLiteral = $_[0];
    my @var;
    if ($stringLiteral =~ /^"[^"]*"$/) {                                                                    # Quotes
        @var = $stringLiteral =~ /(?<!\\)[\$@]#?\{?\w*\}?(?:\[.*\])?/g;
        $stringLiteral =~ s/(?<!\\)[\$@]#?\{?\w*\}?(?:\[.*\])?/\{\}/g;
    } elsif ($stringLiteral =~ /[^"]/) {                                                                    # No quotes
        if ($stringLiteral =~ /\$#(\w*)/) {
            $stringLiteral =~ s/\$#(\w*)/len($1) - 1/;
            if ($1 eq "ARGV") {
                $stringLiteral = "$stringLiteral - 1";
            }
        }
        $stringLiteral =~ s/(?<=@)ARGV/sys.argv[1:]/;                                                       # Handle command line arguments
        $stringLiteral =~ s/ARGV\[/sys.argv[1 + /;
        $stringLiteral =~ s/ARGV/sys.argv/;
        $stringLiteral =~ s/\$//g;                                                                          # Remove $ signs
        $stringLiteral =~ s/<STDIN>/sys.stdin.readline\(\)/;                                                # If from stdin
        if ($stringLiteral =~ /^@/) {
            $stringLiteral =~ s/@//;
            $stringLiteral = "len($stringLiteral)";
        }
    }
    foreach $n (@var) {
        if ($n =~ /\$#/) {
            $n =~ s/\$#//;
            $n = "len($n) - 1";
        }
        $n =~ s/\$//g;                                                                                      # Remove $ sign from variable names
        $n =~ s/(?<=@)ARGV/sys.argv[1:]/;
        $n =~ s/ARGV\[/sys.argv[1 + /;
        if ($n =~ /^@/) {
            $n =~ s/@//;
            $n = "' '.join($n)";
        }
        $n =~ s/^\{//;
        $n =~ s/\}$//;                                                                                      # Remove $ sign from variable names
    }
    if ($stringLiteral =~ /join\(\s*(.*)\s*\)/) {                                                           # declaring a variable with join
        $stringLiteral = "\"$stringLiteral\"";
        (my $delim, my $array) = $1 =~ /('.*')[,\s]*(.*)/;
        $stringLiteral =~ s/join\(\s*(.*)\s*\)/{}/;
        push @var, joinFunction($delim, $array);
    }
    $v = join( ',', @var);
    $retval = "$stringLiteral";
    if (length $v > 0) {
        $retval = "$retval.format($v)";
    }
    return $retval;
}

sub ifStatement {                                                                                           # handles if statements
    $_[0] =~ /\s*if\s*\((.*)\)\s*{(.*)/;
    my $statement = $1;
    my $end = $2;
    $statement =~ s/(?<!\\)\$//g;
    $statement =~ s/<=>/!=/;
    $statement =~ s/eq/==/;
    if ($statement =~ /^\s*\$(\w*)\s*=~\s*("*.*"*);/) {                                                     # regex
        my $var = $1;
        my $regex = $2;
        if ($regex =~ /^\/(.*)\/(\w*)$/) {                                                                  # regex match
            my $match = $1;
            my $tmp = uc $2;
            my $flag = "";
            if (length $tmp > 0) {
                $flag = ", re.$tmp";
            }
            $statement = "$spaces$var = re.match(r'$regex'$flag)";
        }
    }
    $retval = "if $statement:$end\n";
    return $retval;
}

sub whileLoop {                                                                                             # deals with while loops
    $_[0] =~ /\s*while\s*\((.*)\)\s*{(.*)/;
    my $statement = $1;
    my $end = $2;
    $statement =~ s/(?<!\\)\$//g;
    $statement =~ s/<=>/!=/;
    if ($statement =~ /(?:(\w*)\s*=\s*)?<>/) {                                                              # special case for <>
        my $var = $1;
        if ($var eq "") {                                                                                   # anonymous variable
            $var = "_";
        }
        return "for $var in fileinput.input():$end\n";
    } elsif ($statement =~ /(?:(\w*)\s*=\s*)?<STDIN>/) {                                                    # special case for <STDIN>
        my $var = $1;
        if ($var eq "") {                                                                                   # anonymous variable
            $var = "_";
        }
        return "for $var in sys.stdin:$end\n";
    }
    $retval = "while $statement:$end\n";
    return $retval;
}

sub forLoop {                                                                                               # returns an array of all 3 parts of a c-style for loop
    $_[0] =~ /^\s*for\s*\((.*)\)\s*{(.*)/;
    my $in = $1;
    @condition = split(/;/, $in);
    my $end = $2;
    push @condition, $end;
    $condition[0] =~ s/^my\s+//g;
    $condition[0] =~ s/\$//g;
    $condition[1] =~ s/\$//g;
    $condition[2] =~ s/\$//g;
    return \@condition;                                                                                     # conditions run individual as a while loop - handled in runCode
}

sub foreachLoop {                                                                                           # handles all the different arguments for foreach loops
    (my $var, my $array, my $end) = $_[0] =~ /^\s*foreach\s*(\$\w*)?\s*\(([^\)]*)\)\s*{(.*)/;
    if ($var eq "") {
        $var = "_";
    }
    $var =~ s/\$//;
    if ($array =~ /^\s*\@ARGV/) {
        $array =~ s/\@ARGV/sys\.argv\[1:\]/;
    } elsif ($array =~ /^\s*@/) {
        $array =~ s/@//;
    } elsif ($array =~ /\$?#?(\w+)\.\.(\$?#?\w+)/) {
        my $from = $1;
        my $to = $2;
        if ($to eq "\$#ARGV") {
            if ($from =~ /\d+/) {
                $from += 1;
            } else {
                $from = "$to + 1";
            }
            $to = "len(sys.argv)";
        } elsif ($to =~ /\$#/) {
            $to =~ s/\$#//;
            $to = "len($to)";
        } else {
            $to =~ s/\$//g;
            if ($to =~ /\d+/) {
                $to += 1;
            } elsif ($to =~ /\$#/) {
                $to =~ s/\$#//;
                $to = "len($to)";
            }  else {
                $to = "$to + 1";
            }
        }
        $array = "range($from, $to)";
    } elsif ($array =~ /^\s*reverse\s*@(\w*)/) {
        $array = "reversed($1)";
    } elsif ($array =~ /^\s*\$(\w*)\s*=~\s*\/(.*)\/(\w*)/) {
        (my $var, my $regex, my $flag) = ($1, $2, uc $3);
        my $tmp = "match";
        if ($flag eq 'G') {
            $tmp = "findall";
        }
        if (length $flag > 0) {
            $flag = ", re.$flag";
        }
        $array = "re.$tmp(r'$regex', $var)";
    } else {
        my @temp = split( /,/, $array);
        foreach (@temp) {
            if ($_ =~ /^\s*([a-zA-Z]*)\s*$/) {
                $_ = " \"$1\"";
            }
        }
        $array = join(",", @temp);
        $array = "[$array]";
    }
    return "for $var in $array:$end\n";
}

sub joinFunction {                                                                                          # join function
    my $delim = $_[0];
    my $array = $_[1];
    if ($array eq '@ARGV') {
        return "$delim.join(sys.argv[1:])";                                                                 # different handling for command line arguments
    } else {
        $array =~ s/@//;
        return "$delim.join($array)";
    }
}

sub arrayDeclaration {
    my $statement = $_[0];
    if ($statement =~ /^(?:\s*my)?\s*@(\w*)\s*(?:=\s*\((.*)\))?\s*;(.*)$/) {                                # initialise array - empty or otherwise
        (my $array, my $contents, my $end) = ($1, $2, $3);
        return "$array = [$contents]$end\n";
    } elsif ($statement =~ /^(?:\s*my)?\s*@(\w*)\s*=\s*split\s*\(?([^\)]*)\)?\s*;(.*)$/) {                  # Split function
        (my $array, my $toSplit, my $end) = ($1, $2, $3);
        my @parts = split(/\s*,\s*/, $toSplit);
        $parts[0] =~ s/^\s*\///;
        $parts[0] =~ s/\/\s*$//;
        $parts[1] =~ s/\$//g;
        if ($parts[2] =~ /^\d*$/) {
            $parts[2] -= 1;
        } else {
            $parts[2] = "$parts[2] - 1";
        }
        if (scalar @parts == 3) {
            return "$array = $parts[1].split('$parts[0]', $parts[2])\n";
        } else {
            return "$array = $parts[1].split('$parts[0]')\n";
        }
    } elsif ($statement =~ /^(?:\s*my)?\s*@(\w*)\s*=\s*@(\w*)\s*;(.*)/) {                                   # array = a different array (deepcopy)
        return "$1 = copy.deepcopy($2)$3";
    } elsif ($statement =~ /^(?:\s*my)?\s*@(\w*)\s*=\s*reverse\s*\(?\s*@(\w*)\s*\)?\s*;(.*)/) {             # reverse
        (my $array, my $toReverse, my $end) = ($1, $2, $3);
        if ($array eq $toReverse) {
            return "$array.reverse()$end";
        }
        return "$array = $toReverse.reverse()$end";
    }
}
