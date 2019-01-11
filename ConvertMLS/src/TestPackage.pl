
use strict;
use warnings;

my $testref = 0;
my $funcref;
my @arguref;

if ( $testref == 0 ) {

    $funcref = \&ProcessComp1004;
    @arguref = ( 1, 2 );

}

my $ans = $funcref->(@arguref);
print $ans;

sub preprocess_input {

    my $csvFileName = $_[0];

    #convert comma delimited to tab delimited
    my $csv = Text::CSV->new( { binary => 1 } );
    my $tsv = Text::CSV->new( { binary => 1, sep_char => "\t", eol => "\n" } );

    #set up for temporary output file
    ( my $base, my $dir, my $ext ) = fileparse( $csvFileName, '\..*' );
    my $fileNameTxt = "${dir}${base}.txt";
    
    open( my $infh, '<:encoding(utf8)', $csvFileName );
    open( my $outfhNameTxt, '>:encoding(utf8)', $fileNameTxt );   #temp tab delim file.
    $outfhNameTxt->autoflush();

    my $rownum = 1;
    while ( my $row = $csv->getline($infh) ) {

        # fix duplicate field names in Paragon 5 MLS export
        # Basement appears twice, once for yes or no, and again for type.
        # Change to Bsmnt_1 and Bsmnt_2

        if ( $rownum eq 1 ) {
            my $dupcnt  = 1;
            my $cnt     = 0;
            my $element = '';
            my $newname = '';
            foreach ( @{$row} ) {
                $element = @{$row}[$cnt];
                if ( $element =~ /Basement/ix ) {
                    $element =~ s/Basement/Bsmnt_${dupcnt}/;
                    @{$row}[$cnt] = $element;
                    $dupcnt++;
                }
                $cnt++;
            }
        }

        $tsv->print( $outfhNameTxt, $row );
        $rownum++;
    }
    $outfhNameTxt->autoflush();
    close $outfhNameTxt;

    # Preprocess file to replace single and double quotes (' -> `, " -> ~)
    my @line;
    my $cnt = 0;

    open( $outfhNameTxt, '<', $fileNameTxt );

    # read file line by line
    while (<$outfhNameTxt>) {
        $line[$cnt] = $_;

        # CAAR records may have a tab after the last field,
        # making it seem that there is one more field than there is.
        # so remove any tab character just before the newline.
        $line[$cnt] =~ s/(\t\n)/\n/;
        $line[$cnt] =~ s/'/`/ig;
        $line[$cnt] =~ s/"//ig;
        $cnt++;
    }
    close $outfhNameTxt;
    
    
    #create temporary file
    my $dTmpFile;
    my $dTmpFileName = "${dir}${base}_temp${ext}";
    open( $dTmpFile, '>', $dTmpFileName );
    $dTmpFile->autoflush();
    my $lcnt = 0;
    while ( $lcnt < $cnt ) {
        print $dTmpFile $line[$lcnt];
        $lcnt++;    
    }

    close $dTmpFile;
     
     
       
    #set up for output file
    ( $base, $dir, $ext ) = fileparse( $fileNameTxt, '\..*' );
    my $WToutfileName = "${dir}${base}_for_wintotal${ext}";
    open( my $WToutfile, '+>', $WToutfileName );

    # replace \ with / in output file name.
    $WToutfileName =~ s/\//\\/g;

    my $WToutfileNameTxt = "${dir}${base}_for_wintotal_text${ext}";
    open( my $WToutfileTxt, '+>', $WToutfileNameTxt );

 

    return (
        $WToutfile,        $WToutfileTxt, $WToutfileName,
        $WToutfileNameTxt, $dTmpFileName
    );
}

sub set_process_options {
    
}

sub process_comp_1004 {

    my (@inputs) = @_;
    return $inputs[0] + $inputs[1];
}

sub process_comp_1025 {

    my (@inputs) = @_;

}

