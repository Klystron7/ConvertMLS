#!/usr/bin/perl -w
use strict;

my $Any = 0;    # If -a was given.

Main( @ARGV );
exit;


sub Usage {
    warn @_, $/
        if  @_;
    die "Usage: exports [-a] [ Perl::Module [...] ] [ file [...] ]\n",
        "    Writes out what each listed module by-default exports\n",
        "    or reports all uses of those exports in the listed files.\n",
        "    If no module names are listed, then searches each file for\n",
        "    cases of 'use Perl::Module;' and suggests replacements.\n",
        "    -a: Searches for *any* exports, not just default ones.\n",
    ;
}


sub IsModName {
    local( $_ ) = @_;
    return 2    # Looks like 'Foo::Bar'; assume module name.
        if  /::/ && ! /[^\w:]/;
    return 1    # Just \w chars and not a file; perhaps a module name.
        if  ! /\W/ && ! -e;
    # Contains a non-module character (like '.') or is a file; assume file name:
    return 0;
}


sub ParseArgs {
    my( $mods_av, $files_av, @args ) = @_;
    Usage()
        if  ! @args;
    while( @args ) {
        last
            if  $args[0] !~ /^--?[^-]/;
        local $_ = shift @args;
        if( /^-a/ ) {
            $Any = 1;
        } else {
            Usage( "Unrecognized option: $_" );
        }
    }
    shift @args
        if  '--' eq $args[0];
    while( @args ) {
        last
            if  ! IsModName( $args[0] );
        push @$mods_av, shift @args;
    }
    while( @args ) {
        my $isMod = IsModName( $args[0] );
        die sprintf "Put all module names (%s) before all file names (%s)\n",
            $args[0], $files_av->[-1]
            if  2 == $isMod;
        if( '-' ne $args[0] ) {
            my $isFile = -e $args[0];
            die "Can't find file ($args[0]): $!\n"
                if  ! defined $isFile;
            die "Not a file: $args[0]\n"
                if  ! $isFile || -d _;
        }
        push @$files_av, shift @args;
    }
}


# Returns the list of symbols exported by the given module:

sub GetExports {
    my( $package ) = @_;
    eval { $package->import() };    # POSIX doesn't populate @EXPORT early
    my @exports = do {
        no strict 'refs';
        @{ "${package}::EXPORT" }
    };
    if( $Any ) {
        no strict 'refs';
        push @exports, @{ "${package}::EXPORT_OK" };
    }
    s/^&//
        for @exports;   # '&foo' and 'foo' are the same to Exporter.pm
    my %seen;
    @exports = grep ! $seen{$_}++, @exports;    # Remove duplicates
    return @exports;
}


sub PrintExports {
    my( $mod ) = @_;
    my @exports = GetExports( $mod );
    my $pref = '';
#   if( -t STDOUT ) {
        my $version = $mod->VERSION();
        if( $version ) {
            print "$mod $version:\n";
        } else {
            print "$mod:\n";
        }
        $pref = '    ';
#   }
    print "$pref$_\n"
        for @exports;
}


sub SearchFile {
    my( $file, @mods ) = @_;
    my $fh;
    if( '-' eq $file ) {
        $fh = \*STDIN;
    } else {
        open $fh, '<', $file
            or  die "Can't read $file: $!\n";
    }
    @mods = LoadModules( FindUsedModules( $fh ) )
        if  ! @mods;
    if( ! @mods ) {
        my $default = $Any ? '' : ' default';
        print "No$default imports: $file\n";
        return;
    }
    $. = 0;
    seek $fh, 0, 0
        or  die "Can't rewind handle to $file: $!\n";
    print "$file:\n";
    ReportExportUse( $fh, @mods );
}


sub MatchWords {
    my( @exports ) = @_;
    my @res;
    for( @exports ) {
        if( s/^\$// ) {
            push @res, '\$' . "\Q$_" . '(?![\[\{\w])';
        } elsif( s/^\%// ) {
            push @res,  '%' . "\Q$_" . '\b';
            push @res, '\$' . "\Q$_" . '\{';
        } elsif( s/^@// ) {
            push @res, '\@' . "\Q$_" . '\b';
            push @res, '\$' . "\Q$_" . '\[';
        } else {
            push @res, '(?<![\$\@%\w])' . "\Q$_" . '(?!\w)';
        }
    }
    return join '|', @res;
}


sub ReportExportUse {
    my( $fh, @mods ) = @_;
    my( @exports, %export_mod, %conflict );
    GroupExports( \( @exports, %export_mod, %conflict ), @mods );
    my %mod_export;
    my $inuse = 0;
    if( @exports ) {
        my $match = MatchWords( @exports );
        $match = qr/$match/;
        local $_;
        while( <$fh> ) {
            my $underline = '';
            my $line = $_;
            if( $inuse ) {
                next
                    if  ! s/^([^;]*;)/ ' ' x length($1) /e;
                $inuse = 0;
            } elsif( $Any ) {
                $inuse = 1
                    if  s/^(\s*use\s+[\w:]+[^;]*(;?))/ ' ' x length($1) /e
                    &&  ! $2;
            }
            while( /$match/g ) {
                my( $start, $end ) = ( $-[0], $+[0] );
                my $export = substr( $_, $start, $end - $start );
                s/\$(.*)\[$/\@$1/,
                s/\$(.*)\{$/\%$1/,
                    for $export;
                my $len = length($export);
                $underline .= ' ' x ( $start - length($underline) );
                $underline .= $export;
                my $mod = $export_mod{$export};
                if( $mod ) {
                    $mod_export{$mod}{$export}++;
                } else {
                    warn "Can't find module that exports '$export'\n";
                }
            }
            printf "%6d: %s%8s%s\n", $., $line, '', $underline
                if  $underline;
        }
    }
    for my $mod ( @mods ) {
        my @used = sort keys %{ $mod_export{$mod} };
        if( @used ) {
            Print( "# use $mod\tqw< @used >;\n" );
        } elsif( $export_mod{''}{$mod} ) {
            my $default = $Any ? '' : ' default';
            Print( "# use $mod();\t# No$default exports\n" );
        } else {
            Print( "# use $mod();\t# Not used?\n" );
        }
        my $hv = $conflict{$mod};
        for my $prev ( keys %$hv ) {
            my @e = sort grep {
                $mod_export{$prev}{$_}
            } keys %{ $hv->{$prev} };
            print "#     Also (see $prev): @e\n"
                if  @e;
        }
    }
}


# Expands tab characters ("\t"s) then prints:

sub Print {
    my @strings = @_;
    my $pos = 0;
    for( @strings ) {
        my $plus = 0;
        s{\t}{
            my $total = $pos + $plus + pos() - 1;
            my $pad = 9 - $total % 8;
            $pad += 8
                if  $total < 16;
            $pad += 8
                if  $total < 8;
            $plus += $pad - 1;
            ' ' x $pad
        }gex;
        $pos += length;
    }
    print @strings;
}


# Note duplicate exports and assign each export to only one module:

sub GroupExports {
    my( $exports_av, $export_mod_hv, $conflict_hv, @mods ) = @_;
    for my $mod ( @mods ) {
        my @e = GetExports( $mod );
        if( ! @e ) {
            $export_mod_hv->{''}{$mod} = 1;
            next;
        }
        for my $export ( @e ) {
            my $prev = $export_mod_hv->{$export};
            if( $prev ) {
                $conflict_hv->{$mod}{$prev}{$export} = 1;
            } else {
                push @$exports_av, $export;
                $export_mod_hv->{$export} = $mod;
            }
        }
    }
}


# Find used modules, either all or just those with no arguments given:

sub FindUsedModules {
    my( $fh ) = @_;
    my @mods;
    local $_;
    while( <$fh> ) {
        if(     /^\s*use\s+([\w:]+)\s*;/
            ||  $Any && /^\s*use\s+([\w:]+)\b/
        ) {
            push @mods, $1
                if  'strict' ne $1;
        }
    }
    return @mods;
}


# Returns names of modules successfully loaded ("require"d):

sub LoadModules {
    return grep {
        ( my $file = $_ ) =~ s-::-/-g;
        $file .= ".pm";
        if( !  eval { local $_; require $file; 1 } ) {
            # ... trim error message ...
            warn "$_: $@\n";
            0   # Ignore further work for this module
        } else {
            1   # Keep this module for further work
        }
    } @_;
}


sub Main {
    my( @args ) = @_;
    ParseArgs( \my( @mods, @files ), @args );
    exit 1
        if  @mods != LoadModules( @mods );  # If some modules not found.
    if( ! @files ) {        # Just list each module and its exports:
        PrintExports( $_ )
            for @mods;
    } else {                # Search file(s) for uses of exports:
        for my $file ( @files ) {
            SearchFile( $file, @mods );
        }
    }
}
