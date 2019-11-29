package My::MLStoText;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(DoConvert);

use File::Basename qw( fileparse );
use Tie::IxHash();
use Text::RecordParser();
use Switch;
use Text::CSV();
use File::Basename qw( fileparse );
use Math::Round qw( round );
use IO::Handle();
#use Time::localtime qw( localtime );
use Tk qw( MainLoop exit );
use Date::Calc qw(check_date Add_Delta_Days);
use List::MoreUtils qw(first_index);
use Time::Piece;
use Wx;

#DoConvert();

sub DoConvert {

    my ( $filename, $cbOpt, $status ) = @_;
    my @cbOptions = @$cbOpt;

    #my $filename  = "C:\\Users\\Ernest\\git\\ConvertMLS\\ConvertMLS\\Condo1.csv";
    #my @cbOptions = ( 0, 1, 0, 0, 0 );
    #my $status    = 0;

    # check input options and compare with file data
    # return output file name and function ptr for processing.
    # if not option does not match prints message and returns to window
    ( my $spoRes, my $WTfileName, my $proFuncPt ) = set_process_opts( $filename, @cbOptions, $status );
    if ($spoRes) {return}

    # preprocess input file and return data file name
    ( my $ppRes, my $dataFileNm ) = preprocess( $filename, $status );
    if ($ppRes) {return}

    #process data
    ( my $pRes ) = process_data( $dataFileNm, $WTfileName, $proFuncPt, $status );

    #my $cmd = "notepad.exe ".$WTfileName;
    #my ( $stat, $output ) = Wx::ExecuteCommand($cmd);

    return $WTfileName;

}

sub set_process_opts {
    my ( $inputFileNm, @outFileOptions, $stat ) = @_;

    my ( $funcref, @arguref );
    if (1) {
        $funcref = \&hello;
        @arguref = ( 1, 2 );
    }
    my $ans = $funcref->(@arguref);

    #print $ans;

    # set output file name based on selected checkbox
    my @fileTypes = ( "_1004_comps", "_1073_comps", "_1007_rent", "_1025_comps", "_1025_rent", "_desktop_comps" );

    # processing function based on selected checkbox
    my @proFunc;
    $proFunc[0] = \&process_comp_1004;
    $proFunc[1] = \&process_comp_1073;
    $proFunc[2] = \&process_rent_1007;
    $proFunc[3] = \&process_comp_1025;
    $proFunc[4] = \&process_rent_1025;
    $proFunc[5] = \&process_comp_Desktop;

    # set file name and processing function based on checkbox
    my $index    = first_index {/1/} @outFileOptions;
    my $fileType = $fileTypes[$index];
    my $funType  = $proFunc[$index];

    # set up name for final output file
    my ( $base, $dir, $ext ) = fileparse( $inputFileNm, '\..*' );
    my $WToutfileNm = "${dir}${base}${fileType}.txt";

    # replace \ with / in output file name.
    $WToutfileNm =~ s/\//\\/g;

    return ( 0, $WToutfileNm, $funType );

}

sub preprocess {

    my $csvFileName = $_[0];
    my $stat        = $_[1];

    #  set up for comma delimited to tab delimited
    my $csv = Text::CSV->new( { binary => 1 } );
    my $tsv = Text::CSV->new( { binary => 1, sep_char => "\t", eol => "\n" } );

    #set up for temporary output file
    ( my $base, my $dir, my $ext ) = fileparse( $csvFileName, '\..*' );
    my $fileNameTxt = "${dir}${base}.txt";

    # open input and output files
    open( my $infh,         '<:encoding(utf8)', $csvFileName );
    open( my $outfhNameTxt, '>:encoding(utf8)', $fileNameTxt );
    $outfhNameTxt->autoflush();

    # read in comma delimited file and output to tab delimited file
    # First, fix duplicate field names (first line of file) in Paragon 5 MLS export
    # Basement appears twice, once for yes or no, and again for type.
    # Change to Bsmnt_1 and Bsmnt_2
    my $dupcnt = 1;
    my $row    = $csv->getline($infh);
    my $arrs   = @$row;
    for ( my $i = 0; $i < @$row; $i++ ) {
        @$row[$i] =~ s/Basement/"Bsmnt_".$dupcnt++/e;
    }
    $tsv->print( $outfhNameTxt, $row );

    # continue input/output with 2nd line
    while ( $row = $csv->getline($infh) ) {
        $tsv->print( $outfhNameTxt, $row );
    }
    $outfhNameTxt->autoflush();
    close $outfhNameTxt;

    # Preprocess file to replace single and double quotes (' -> `, " -> ~)
    open( $outfhNameTxt, '<', $fileNameTxt );
    my @line;
    my $cnt = 0;

    # read new tab delimited file line by line
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

    #create temp file for data processing
    my $dTmpFile;
    my $dTmpFileName = "${dir}${base}_temp.txt";
    open( $dTmpFile, '>', $dTmpFileName );
    $dTmpFile->autoflush();
    my $lcnt = 0;
    while ( $lcnt < $cnt ) {
        print $dTmpFile $line[$lcnt];
        $lcnt++;
    }
    close $dTmpFile;

    # clean up by deleting temporary output file
    my $delfile = unlink($fileNameTxt);

    my $result = 0;

    return ( $result, $dTmpFileName );
}

sub process_data {

    my ( $dataFileNm, $WTfileNm, $func, $stat ) = @_;

    # open output file
    open( my $WToutfile, '+>', $WTfileNm );

    # set up output data hash table and
    # print fields on output file
    my $blankRecHash = WTrecord();

    #printFields( $blankRecHash, $WToutfile );

    # set up record parser
    my $p = Text::RecordParser->new(
        {   filename         => $dataFileNm,
            field_separator  => "\t",
            record_separator => "\n"
        }
    );
    $p->bind_header;

    # loop over each input record and process
    # get each record (row from file) as a hashref
    my $pnum = 1;
    while ( my $record = $p->fetchrow_hashref ) {

        # Get a new record with only tabs
        my $currRec = $blankRecHash;

        # process using function determined in sub set_process_options
        $func->( $record, $currRec, $WToutfile );

        # update status on main window
        my $cRec = "Comp #".$pnum++.": ".$currRec->{'Address1'}."\n";
        $stat->AppendText($cRec);

        print $WToutfile ("\n");

    }

    # close file handles not needed
    close $p->fh;
    close $WToutfile;

    # clean up temp file
    unlink $dataFileNm;

    return 0;
}

sub process_comp_1004 {

    my ( $mlsrec, $outdata, $outfile ) = @_;

    CAAR_Resid( $mlsrec, $outdata );
    CAAR_Resid_Text( $outdata, $outfile );

    return 0;
}

sub process_comp_1073 {

    my ( $mlsrec, $outdata, $outfile ) = @_;

    CAAR_Resid( $mlsrec, $outdata );
    CAAR_Condo( $outdata, $outfile );

    return 0;
}

sub process_rent_1007 {

    my ( $inrec, $outdata, $outfile ) = @_;

    my $w = sprintf( '%c', 8 );

    # Line 	Form field			input field 													output
    #	1	Address line 1		street address	(from MLS)								street address	$w
    #	2	Address	line 2		city, state, zip (from MLS)								city state zip $w
    #	3	proximity line 1			n/a												$w
    #	3	proximity line 2			n/a												$w
    #	4	date lease begins	sold date to next half month or month (from MLS)		date $w
    #	5	date lease ends		1-year or lease required								date $w
    #	6	monthly rent		sold price		(from MLS)								price $w
    #	7	less util,furn				n/a												3x($w)
    #	8	Adjusted rent		sold price		(from MLS)								price $w
    #	9	Data Sourc			"Tax Recds/MLS"	(standard)								"Tax Recds/MLS" 6x($w)
    #	10	Location			Location (from MLS)										Location 2x($w)
    #	11	View				View (from MLS)											View 2x($w)
    #	12	Design style		Number of stories (from MLS)							Stories 4x($w)
    #	13	Age					Age (calculated from MLS)								Age 2x($w)
    #	14	Condition			"Average"												"Average" 2x($w)
    #	15	Room count			Total,Beds,Baths										Total,$w,Beds,$w,Baths,3x($w)
    #   16	GLA					Square feet (MLS)										square feet 3x($w)
    #   17	Other				Basement/Finish(MLS)									Basement/finished 2x($w)
    #   18	Other				"n/a"													"n/a" 2x($w)
    #   19	Other				Parking (MLS)											Parking 4x($w)

    # format for 1007 rent schedule form
    tie my %rental  => 'Tie::IxHash',
        address1    => '',
        address2    => '',
        prox1       => '',
        prox2       => '',
        begindate   => '',
        enddate     => '',
        rentmon     => '',
        lesutilfurn => '',
        rentadj     => '',
        datasrc     => '',
        location    => '',
        view        => '',
        design      => '',
        age         => '',
        condition   => '',
        roomcnt     => '',
        gla         => '',
        other1      => '',
        other2      => '',
        other3      => '';

    #3 Street Name Preprocessing
    my $fullStreetName = titleCap( $inrec->{'Address'} );
    $fullStreetName =~ s/ \(.*//;    #remove parens

    my $streetName = $fullStreetName;
    if ( $streetName =~ m/( +[nsew] *$| +[ns][ew] *$)/ig ) {
        my $strpostdir = uc $1;
        $streetName =~ s/$strpostdir//i;
    }

    #5 Street Name, Street Suffix
    #find street suffix (assumes last word is street type, e.g. ave, rd, ln)
    my @words        = split( / /, $streetName );
    my @revwords     = reverse(@words);
    my $streetSuffix = $revwords[0];
    $streetName =~ s/$streetSuffix//;

    #6 Address 1
    #my $streetnum = $inrec->{'Street Num'};
    #my $address1  = "$streetnum $fullStreetName";
    my $address1 = $fullStreetName;

    #7 Address 2
    my $city = $inrec->{'City'};
    $city = titleCap($city);
    $city =~ s/\(.*//;
    $city =~ s/\s+$//;
    my $state    = $inrec->{'State'};
    my $zip      = $inrec->{'Zip'};
    my $address2 = $city.", ".$state." ".$zip;

    $rental{'address1'} = $address1.$w;
    $rental{'address2'} = $address2.$w;

    # proximity
    $rental{'prox1'} = $w;
    $rental{'prox2'} = $w;

    # lease begin date
    my $indate    = $inrec->{'LeasDate'};
    my @da        = ( $indate =~ m/(\d+)/g );
    my $mo        = $da[0];
    my $day       = $da[1];
    my $yr        = $da[2];
    my $begindate = $mo."/".$day."/".$yr;
    $rental{'begindate'} = $begindate.$w;

    my $leaseterm = $inrec->{'LeaseTerm'};
    my $enddate;

    if ( not defined $leaseterm ) {
        $enddate = "Lease term not specified";
    }
    elsif ( $leaseterm eq '' ) {
        $enddate = "Lease term not specified";
    }
    elsif ( $leaseterm =~ /1-year|^$/ig ) {
        my ( $yr1, $mo1, $day1 ) = Add_Delta_Days( $yr, $mo, $day, 364 );
        $enddate = $mo1."/".$day1."/".$yr1;
    }
    else {
        $enddate = $leaseterm;
    }

    $rental{'enddate'} = $enddate.$w;

    # monthly rent
    my $rentmon = $inrec->{'Lease Amt'};
    $rental{'rentmon'} = $rentmon.$w;

    # lessutil
    $rental{'lesutilfurn'} = $w.$w;

    # adj rent
    $rental{'rentadj'} = $rentmon.$w;

    # datasrc
    # ML Number
    my $mlnumber = '';
    $mlnumber = $inrec->{'MLS #'};
    $rental{'datasrc'} = "CAARMLS#".$mlnumber.$w."Tax Records".$w."None".$w.$w.$w.$w;

    # location
    my $location = '';
    my $subdiv   = $inrec->{'Subdivisn'};
    if ( $subdiv =~ m/NONE|^$/ig ) {
        $location = titleCap($city);
    }
    else {
        $location = titleCap($subdiv);
    }
    $rental{'location'} = $location.$w.$w;

    # view
    my $view = "Residential";
    $rental{'view'} = $view.$w.$w;

    # design
    my $design = $inrec->{'Level'};
    $rental{'design'} = $design.$w.$w.$w.$w;

    # age
    my $age = 0;

    #$age = $time{'yyyy'} - $inrec->{'Year Built'};
    $age = localtime->year + 1900 - $inrec->{'Year Built'};
    $rental{'age'} = $age.$w.$w;

    # condition
    $rental{'condition'} = "Average".$w.$w;

    #-----------------------------------------
    # Rooms
    # From CAAR MLS:
    # Room count includes rooms on levels other than Basement.
    # AtticApt, BasementApt, Bedroom, BilliardRm, Brkfast, BonusRm, ButlerPantry, ComboRm,
    # DarkRm, Den, DiningRm, ExerciseRm, FamRm, Foyer, Full Bath, Gallery, GarageApt, GreatRm,
    # Greenhse, Half Bath, HmOffice, HmTheater, InLaw Apt, Kitchen, Laundry, Library, LivingRm,
    # Loft, Master BR, MudRm, Parlor, RecRm, Sauna, SewingRm, SpaRm, Study/Library, SunRm, UtilityRm

    my $rooms      = 0;
    my $fullbath   = 0;
    my $halfbath   = 0;
    my $bedrooms   = 0;
    my $bsRooms    = 0;
    my $bsRecRm    = 0;
    my $bsFullbath = 0;
    my $bsHalfbath = 0;
    my $bsBedrooms = 0;
    my $bsOther    = 0;
    my $bsRmCount  = 0;

    #maximum of 30 rooms
    my $room             = '';
    my $indx             = 0;
    my $rindx            = 0;
    my $rlim             = 30;
    my $rmtype           = '';
    my $rmflr            = '';
    my $roomnum          = '';
    my $roomcount        = '';
    my $roomname         = '';
    my $roomfieldname    = '';
    my $roomlevfieldname = '';
    my $roomlev          = '';

    while ( $rindx < $rlim ) {
        $roomcount        = sprintf( "%02d", $rindx + 1 );
        $roomfieldname    = 'Rm'.$roomcount;
        $roomlevfieldname = $roomfieldname.'Lv';
        $roomname         = $inrec->{$roomfieldname};
        $roomlev          = $inrec->{$roomlevfieldname};

        $roomname =~ s/^\s+|\s+$//g;
        $rmtype = $roomname;
        $roomlev =~ s/ //g;
        $rmflr = $roomlev;

        if ( $rmflr !~ /Basement/ ) {
            if ($rmtype =~ /Bedroom|Breakfast|Bonus|Den|Dining|Exercise|Family|Great|Home Office|Home Theater|Kitchen|Library|Living|Master|Mud|Parlor|Rec|Sauna|Sewing|Spa|Study|Library|Sun/i)
            {
                $rooms++;
            }
            if ( $rmtype =~ /Full Bath/i ) {
                $fullbath++;
            }
            if ( $rmtype =~ /Half Bath/i ) {
                $halfbath++;
            }
            if ( $rmtype =~ /Bedroom|Master/ ) {
                $bedrooms++;
            }
        }
        if ( $rmflr =~ /Basement/ ) {
            if ( $rmtype =~ /Bonus|Den|Family|Great|Library|Living|Rec|Study|Library/i ) {
                $bsRecRm++;
                $bsRmCount++;
            }
            if ( $rmtype
                =~ /Breakfast|Dining|Exercise|Home Office|Home Theater|Kitchen|Mud|Parlor|Sauna|Sewing|Spa|Sun/i )
            {
                $bsOther++;
                $bsRmCount++;
            }
            if ( $rmtype =~ /Full Bath/i ) {
                $bsFullbath++;
                $bsRmCount++;
            }
            if ( $rmtype =~ /Half Bath/i ) {
                $bsHalfbath++;
                $bsRmCount++;
            }
            if ( $rmtype =~ /Bedroom|Master/ ) {
                $bsBedrooms++;
                $bsRmCount++;
            }
        }

        $indx++;
        $rindx++

            #$rindx = $indx * 3;

    }
    if ( $rooms < $bedrooms + 2 ) {
        $rooms = $bedrooms + 2;
    }

    my $bsRmList    = '';
    my $bsRmListTxt = '';

    #   if ( $bsRmCount > 0 ) {
    #       if ( $bsRecRm > 0 )    { $bsRmList = $bsRecRm . "rr"; }
    #       if ( $bsBedrooms > 0 ) { $bsRmList = $bsRmList . $bsBedrooms . "br"; }
    #       if ( ( $bsFullbath + $bsHalfbath ) > 0 ) {
    #           $bsRmList = $bsRmList . $bsFullbath . "." . $bsHalfbath . "ba";
    #       }
    #       if ( $bsOther > 0 ) { $bsRmList = $bsRmList . $bsOther . "o"; }
    #   }
    $bsRmList    = $bsRecRm.'rr'.$bsBedrooms.'br'.$bsFullbath.'.'.$bsHalfbath.'ba'.$bsOther.'o';
    $bsRmListTxt = $bsRecRm.$w.$bsBedrooms.$w.$bsFullbath.'.'.$bsHalfbath.$w.$bsOther;

    # Bedrooms
    my $bedroomstot = $inrec->{'#Beds'};
    my $bedroomsbg  = $inrec->{'#BedsBG'};
    my $bedroomsAG  = $bedroomstot - $bedroomsbg;

    #-----------------------------------------

    # Baths
    my $baths = 0;

    #   if ( $fullbath == 0 ) {
    #       $fullbath = $inrec->{'#FBaths'};
    #       $halfbath = $inrec->{'#HBaths'};
    #   }

    $fullbath = $inrec->{'#FBaths'};
    $halfbath = $inrec->{'#HBaths'};
    my $bgbath = $inrec->{'#BathsBG'};
    if ( $bgbath =~ /.5/ ) {
        $halfbath = $halfbath - 1;
        $bgbath   = $bgbath - 1;
    }
    if ( $bgbath >= 1 ) {
        $fullbath = $fullbath - $bgbath;
    }
    my $bathnum = $fullbath + $halfbath / 10;
    my $bathstr = "$fullbath.$halfbath";
    $baths = sprintf( "%.1f", $bathnum );

    #-----------------------------------------

    $bsRmList = '';
    if ( $bsRmCount > 0 ) {
        if ( $bsRecRm > 0 )    { $bsRmList = $bsRecRm."rr"; }
        if ( $bsBedrooms > 0 ) { $bsRmList = $bsRmList.$bsBedrooms."br"; }
        if ( ( $bsFullbath + $bsHalfbath ) > 0 ) {
            $bsRmList = $bsRmList.$bsFullbath.".".$bsHalfbath."ba";
        }
        if ( $bsOther > 0 ) { $bsRmList = $bsRmList.$bsOther."o"; }
    }

    $rental{'roomcnt'} = $rooms.$w.$bedrooms.$w.$fullbath.".".$halfbath.$w.$w;

    my $sfAGFin = $inrec->{'SqFt Above Grade Fin'};
    my $sfAGTot = $inrec->{'SqFt Above Grade Total'};
    my $sfAGUnF = $inrec->{'SqFt Above Grade UnFin'};
    my $sfBGFin = $inrec->{'SqFt Below Grade Fin'};
    my $sfBGTot = $inrec->{'SqFt Below Grade Total'};
    my $sfBGUnF = $inrec->{'SqFt Below Grade Unfin'};
    my $sfFnTot = $inrec->{'SqFt Fin Total'};
    my $sfGaFin = $inrec->{'SqFt Garage Fin'};
    my $sfGaTot = $inrec->{'SqFt Garage Total'};
    my $sfGaUnF = $inrec->{'SqFt Garage Unfin'};
    my $sfTotal = $inrec->{'SqFt Total'};
    my $sfUnTot = $inrec->{'SqFt Unfin Total'};

    my $basType = "wo";

    # gla above grade
    my $gla = $sfAGFin;
    $rental{'gla'} = $gla.$w.$w;

    # other line 1
    if ( $rooms == 0 ) {
        $rental{'other1'} = $sfTotal."sf".$sfFnTot."sf".$basType.$w.$w;
    }
    else {
        $rental{'other1'} = $sfBGTot."sf".$sfBGFin."sf".$basType.$w.$w;
    }

    # other2
    $rental{'other2'} = $bsRmList.$w.$w;

    # other3
    my $garout    = "No Garage";
    my $garcarnum = $inrec->{'Garage Num Cars'};
    if ( $garcarnum >= 1 ) {
        $garout = $garcarnum." Car Garage";
    }
    $rental{'other3'} = $garout.$w.$w.$w.$w;

    print $outfile "\n";
    while ( my ( $key, $value ) = each(%rental) ) {
        print $outfile $value;

        #print $outfile "$key => $value\n";

    }
    print $outfile "\n";

# 403 Valley Road Ext # ACharlottesville, VA 229031.06 miles NE2,0250.93XMLS#508911, MLS#50704308/03/2013, 09/15/2012Fry's Spring
# 43Above Average2,1702,1702,025531.11,085975531.11,0851,050
# format for 1025 rent comparables
#    tie my %rent1025 => 'Tie::IxHash',
#        address1     => '',
#        address2     => '',
#        prox         => '',
#        rent         => '',
#        rentgba      => '',
#        rentctrl     => '',
#        datasrc      => '',
#        leasedate    => '',
#        location     => '',
#        age          => '',
#        condition    => '',
#        GBA          => '';
#
#    $rent1025{'address1'}  = $address1.$w;
#    $rent1025{'address2'}  = $address2.$w;
#    $rent1025{'prox'}      = $w;
#    $rent1025{'rent'}      = $rentmon.$w;
#    $rent1025{'rentgba'}   = $w;
#    $rent1025{'rentctrl'}  = $w.'X'.$w;
#    $rent1025{'datasrc'}   = "MLS#".$mlnumber.$w;
#    $rent1025{'leasedate'} = $begindate.$w;
#    $rent1025{'location'}  = $location.$w;
#    $rent1025{'age'}       = $age.$w;
#    $rent1025{'condition'} = $w;
#    $rent1025{'GBA'}       = $sfFnTot.$w;
#
#    print $outfile "\n";
#    while ( my ( $key, $value ) = each(%rent1025) ) {
#        print $outfile $value;
#
#        #print $outfile "$key => $value\n";
#    }
#    print $outfile "\n";

    return 0;
}

sub process_comp_1025 {

    my ( $mlsrec, $outdata, $outfile ) = @_;

    CAAR_Resid( $mlsrec, $outdata );
    CAAR_Resid_Text( $outdata, $outfile );

    return 0;
}

sub process_rent_1025 {

    my (@inputs) = @_;

}

sub process_comp_Desktop {

    my ( $mlsrec, $outdata, $outfile ) = @_;

    CAAR_Resid( $mlsrec, $outdata );
    CAAR_Desktop( $outdata, $outfile );

    return 0;
}

sub CAAR_Resid {
    my ($inrec)  = shift;
    my ($outrec) = shift;

    #my ($outfile) = shift;

    # Backspace character used between fields in Wintotal
    my $w = sprintf( '%c', 8 );

    #    my $tc       = Lingua::EN::Titlecase->new("initialize titlecase");
    #    my %addrArgs = (
    #        country                     => 'US',
    #        autoclean                   => 1,
    #        force_case                  => 1,
    #        abbreviate_subcountry       => 0,
    #        abbreviated_subcountry_only => 1
    #    );
    #my $laddress = new Lingua::EN::AddressParse(%addrArgs);

    my $address   = $inrec->{'Address'};
    my $streetnum = '';

    # Street Number
    if ( $address =~ /(\d+)/ ) {
        $streetnum = $1;
    }
    $outrec->{'StreetNum'} = $streetnum;

    #-----------------------------------------

    $outrec->{'StreetDir'} = '';

    #-----------------------------------------

    #my $addrTC = $tc->title( $inrec->{'Address'} );
    my $addrTC = titleCap( $inrec->{'Address'} );
    $outrec->{'Address1'} = $addrTC;

    print( $outrec->{'Address1'} );
    print "\n";

    #-----------------------------------------

    # Address 2
    my $city = $inrec->{'City'};

    #$city = $tc->title($city);
    $city = titleCap( $inrec->{'City'} );
    $city =~ s/\(.*//;
    $city =~ s/\s+$//;
    my $address2 = $city.", "."VA ".$inrec->{'Zip'};
    $outrec->{'Address2'} = $address2;

    #-----------------------------------------

    # Address 3
    my $address3 = "VA"." ".$inrec->{'Zip'};
    $outrec->{'Address3'} = $address3;

    #-----------------------------------------

    # City
    $outrec->{'City'} = $city;

    #-----------------------------------------

    # State
    $outrec->{'State'} = "VA";

    #-----------------------------------------

    # Zip
    $outrec->{'Zip'} = $inrec->{'Zip'};

    #-----------------------------------------

    # SalePrice
    my $soldstatus = 0;
    my $soldprice  = 0;
    my $recstatus  = $inrec->{'Status'};
    if ( $recstatus eq 'SLD' ) {
        $soldstatus = 0;                        #sold
        $soldprice  = $inrec->{'Sold Price'};
    }
    elsif ( $recstatus =~ m /ACT/i ) {
        $soldstatus = 1;                        #Active
        $soldprice  = $inrec->{'Price'};
    }
    elsif ( $recstatus =~ m /PND/i ) {
        $soldstatus = 2;                        #Pending
        $soldprice  = $inrec->{'Price'};
    }
    elsif ( $recstatus =~ m /CNT/i ) {
        $soldstatus = 3;                        #Contingent
        $soldprice  = $inrec->{'Price'};
    }
    elsif ( $recstatus =~ m /EXP/i ) {
        $soldstatus = 4;                        #Withdrawn
        $soldprice  = $inrec->{'Price'};
    }
    else {

        #nothing
    }
    $outrec->{'SalePrice'} = $soldprice;

    #-----------------------------------------

    # SoldStatus
    $outrec->{'Status'} = $soldstatus;

    #-----------------------------------------

    # DataSource1
    my $datasrc = "CAARMLS #".$inrec->{'MLS#'}.";DOM ".$inrec->{'DOM'};
    $outrec->{'DataSource1'} = $datasrc;
    $outrec->{'DOM'}         = $inrec->{'DOM'};

    #-----------------------------------------

    # Data Source 2
    $outrec->{'DataSource2'} = "Tax Records";

    #-----------------------------------------

    # Finance Concessions Line 1
    # REO		REO sale
    # Short		Short sale
    # CrtOrd	Court ordered sale
    # Estate	Estate sale
    # Relo		Relocation sale
    # NonArm	Non-arms length sale
    # ArmLth	Arms length sale
    # Listing	Listing

    my $finconc1 = '';
    if ( $soldstatus == 0 ) {

        #my $agentnotes = $inrec->{'Agent Notes'};
        my $agentnotes = '';

        if ( $inrec->{'Foreclosur'} =~ /Yes/i ) {
            $finconc1 = "REO";
        }
        elsif ( $inrec->{'LenderOwn'} =~ /Yes/i ) {
            $finconc1 = "REO";
        }
        elsif ( $inrec->{'ShortSale'} =~ /Yes/i ) {
            $finconc1 = "Short";
        }
        elsif ( $agentnotes =~ /court ordered /i ) {
            $finconc1 = "CrtOrd";
        }
        elsif ( $agentnotes =~ /estate sale /i ) {
            $finconc1 = "Estate";
        }
        elsif ( $agentnotes =~ /relocation /i ) {
            $finconc1 = "Relo";
        }
        else {
            $finconc1 = "ArmLth";
        }
    }
    elsif ( $soldstatus == 1 ) {
        $finconc1 = "Listing";
    }
    elsif ( $soldstatus == 2 ) {
        $finconc1 = "Listing";
    }
    elsif ( $soldstatus == 3 ) {
        $finconc1 = "Listing";
    }
    else {
        $finconc1 = '';
    }
    $outrec->{'FinanceConcessions1'} = $finconc1;

    #-----------------------------------------

    # FinanceConcessions2
    # Type of financing:
    # FHA		FHA
    # VA		VA
    # Conv		Conventional
    # Seller 	Seller
    # Cash 		Cash
    # RH		Rural Housing
    # Other
    # Format: 12 Char maximum

    my $finconc2    = '';
    my $conc        = '';
    my $finconc2out = '';
    my $finOther    = '';
    my $finFullNm   = '';

    if ( $soldstatus == 0 ) {
        my $terms = $inrec->{'How Sold'};
        if ( $terms =~ /NOTSP/ig ) {
            $finconc2  = "NotSpec";
            $finFullNm = "Other (describe)";
            $finOther  = "NotSpec";            #Not Specified
        }
        elsif ( $terms =~ /CASH/ig ) {
            $finconc2  = "Cash";
            $finFullNm = "Cash";
        }
        elsif ( $terms =~ /CNVFI/ig ) {
            $finconc2  = "Conv";
            $finFullNm = "Conventional";
        }
        elsif ( $terms =~ /CNVAR/ig ) {
            $finconc2  = "Conv";
            $finFullNm = "Conventional";
        }
        elsif ( $terms =~ /FHA/ig ) {
            $finconc2  = "FHA";
            $finFullNm = "FHA";
        }
        elsif ( $terms =~ /VHDA/ig ) {
            $finconc2  = "VHDA";
            $finFullNm = "Other (describe)";
            $finOther  = "VHDA";
        }
        elsif ( $terms =~ /FHMA/ig ) {
            $finconc2  = "FHMA";
            $finFullNm = "Other (describe)";
            $finOther  = "FHMA";
        }
        elsif ( $terms =~ /VA/ig ) {
            $finconc2  = "VA";
            $finFullNm = "VA";
        }
        elsif ( $terms =~ /ASMMT/ig ) {
            $finconc2  = "AsmMtg";
            $finFullNm = "Other (describe)";
            $finOther  = "AsmMtg";
        }
        elsif ( $terms =~ /PVTMT/ig ) {
            $finconc2  = "PrvMtg";
            $finFullNm = "Other (describe)";
            $finOther  = "PrvMtg";
        }
        elsif ( $terms =~ /OWNFN/ig ) {
            $finconc2  = "Seller";
            $finFullNm = "Seller";
        }
        elsif ( $terms =~ /OTHER/ig ) {
            $finconc2  = "NotSpec";
            $finFullNm = "Other (describe)";
            $finOther  = "NotSpec";
        }
        elsif ( $terms =~ /USDAR/ig ) {
            $finconc2  = "RH";
            $finFullNm = "USDA - Rural housing";
        }
        else {
            $finconc2  = "NotSpec";
            $finFullNm = "Other (describe)";
            $finOther  = "NotSpec";
        }

        $conc = 0;
        if ( $inrec->{'SellerConc'} ) {
            $conc = USA_Format( $inrec->{'SellerConc'} );
            $conc =~ s/$//;
            $conc = $inrec->{'SellerConc'};
        }
        $finconc2out = $finconc2.";".$conc;
    }

    $outrec->{'FinanceConcessions2'} = $finconc2out;
    $outrec->{'FinConc'}             = $finconc2;
    $outrec->{'FinFullNm'}           = $finFullNm;
    $outrec->{'FinOther'}            = $finOther;
    $outrec->{'Conc'}                = $conc;

    #-----------------------------------------

    # DateSaleTime1
    my $datesaletime1 = '';
    if ( $soldstatus == 0 ) {
        $datesaletime1 = $inrec->{'Close Date'};
    }
    else {
        $datesaletime1 = $inrec->{'Lst Date'};
    }
    my $dateonly = '';
    if ( $datesaletime1 =~ m/((0?[1-9]|1[012])\/(0?[1-9]|[12][0-9]|3[01])\/(19|20)\d\d)/ ) {
        $dateonly = $1;
    }
    $outrec->{'DateSaleTime1'} = $dateonly;

    #-----------------------------------------

    # DateSaleTime2
    my $datesaletime2 = '';
    if ( $soldstatus == 0 ) {
        my $sdate = $inrec->{'Close Date'};
        my @da    = ( $sdate =~ m/(\d+)/g );
        $datesaletime2 = $da[2]."/".$da[0]."/".$da[1];

        #time_manip('yyyy/mm/dd', $sdate );
    }
    $outrec->{'DateSaleTime2'} = $datesaletime2;

    #-----------------------------------------
    # SaleDateFormatted
    # Sale and Contract formatted as mm/yy
    my ( $sdatestr, $cdatestr, $wsdatestr, $wcdatestr, $fulldatestr, $salestatus, $cdate ) = ('') x 7;

    if ( $soldstatus == 0 ) {
        my $sdate = $inrec->{'Close Date'};
        my @da    = ( $sdate =~ m/(\d+)/g );

        #my $m2digit = sprintf("%02d", $da[0]);
        my $m2digit  = sprintf( "%02d", $da[0] );
        my $yr2digit = sprintf( "%02d", $da[2] % 100 );
        $sdatestr  = "s".$m2digit."/".$yr2digit;
        $wsdatestr = $m2digit."/".$yr2digit;

        setifdef( $cdate, $inrec->{'Cont Date'} );
        my @cnda = ( $cdate =~ m/(\d+)/g );
        unless ( check_date( $cnda[2], $cnda[0], $cnda[1] ) ) {
            $cdatestr = "Unk";
        }
        else {
            my @da       = ( $cdate =~ m/(\d+)/g );
            my $m2digit  = sprintf( "%02d", $da[0] );
            my $yr2digit = sprintf( "%02d", $da[2] % 100 );
            $cdatestr  = "c".$m2digit."/".$yr2digit;
            $wcdatestr = $m2digit."/".$yr2digit;
        }
        $fulldatestr            = $sdatestr.";".$cdatestr;
        $outrec->{'SaleStatus'} = "Settled sale";
        $outrec->{'SaleDate'}   = $wsdatestr;
        $outrec->{'ContDate'}   = $wcdatestr;

    }
    elsif (( $soldstatus == 1 )
        || ( $soldstatus == 2 )
        || ( $soldstatus == 3 ) )
    {
        $fulldatestr = "Active";
        $outrec->{'SaleStatus'} = "Active";
    }

    #$outrec->{'CloseDate'} = $wsdatestr;
    #$outrec->{'ContrDate'} = $wcdatestr;

    #$fulldatestr = 's12/11;c11/11';
    $outrec->{'SaleDateFormatted'} = $fulldatestr;

    #-----------------------------------------

    # Location
    # N - Neutral, B - Beneficial, A - Adverse
    # Res		Residential
    # Ind		Industrial
    # Comm		Commercial
    # BsyRd		Busy Road
    # WtrFr		Water Front
    # GlfCse	Golf Course
    # AdjPrk	Adjacent to Park
    # AdjPwr	Adjacent to Power Lines
    # LndFl		Landfill
    # PubTrn	Public Transportation

    # basic neutral residential
    my $loc1    = "N";
    my $loc2    = "Res";
    my $loc3    = '';
    my $fullLoc = $loc1.";".$loc2;

    # special cases
    #	my $spLoc;
    #	$spLoc =~ s/Wintergreen Mountain Village/Wintergreen Mtn/ig;
    #	$location =~ s/1800 Jefferson Park Ave/Charlottesville/ig;
    #	my $fullLoc = $loc1 . ";" . $loc2;

    $outrec->{'Location1'} = $fullLoc;

    # Original Non-UAD Location
    #	my $location;
    #	my $subdiv;
    #
    #	$subdiv = $inrec->{'Subdivision'};
    #	if ( $subdiv =~ m/NONE/ig ) {
    #		$location = $tc->title($city);
    #	} else {
    #		$subdiv =~ s/`/'/;
    #		$subdiv = $tc->title($subdiv);
    #		$subdiv =~ s/\(.*//;
    #		$subdiv =~ s/\s+$//;
    #		$location = $subdiv;
    #	}
    #	$location =~ s/Wintergreen Mountain Village/Wintergreen Mtn/ig;
    #	$location =~ s/1800 Jefferson Park Ave/Charlottesville/ig;
    #
    #	$outrec->{'Location1'} = $location;

    #-----------------------------------------

    # PropertyRights
    $outrec->{'PropertyRights'} = "Fee Simple";

    #-----------------------------------------

    # Site
    # MLS: LotSize
    my $acres      = $inrec->{'Acres #'};
    my $acresuffix = '';
    my $outacres   = '';
    if ( $acres < 0.001 ) {
        $outacres = '';
    }
    if ( ( $acres > 0.001 ) && ( $acres < 1.0 ) ) {
        my $acresf = $acres * 43560;
        $outacres = sprintf( "%.0f", $acresf );
        $acresuffix = " sf";
    }
    if ( $acres >= 1.0 ) {
        $outacres = sprintf( "%.2f", $acres );
        $acresuffix = " ac";
    }
    $outrec->{'LotSize'} = $outacres.$acresuffix;

    #-----------------------------------------

    # View
    # N - Neutral, B - Beneficial, A - Adverse
    # Wtr		Water View
    # Pstrl		Pastoral View
    # Woods		Woods View
    # Park		Park View
    # Glfvw		Golf View
    # CtySky	City View Skyline View
    # Mtn		Mountain View
    # Res		Residential View
    # CtyStr	CtyStr
    # Ind		Industrial View
    # PwrLn		Power Lines
    # LtdSght	Limited Sight

    # MLS LotView
    # Blue Ridge | Garden | Golf | Mountain | Pastoral | Residential | Water | Woods
    # Water properties: Bay/Cove | Irrigation | Pond/Lake | Pond/Lake Site | River | Spring | Stream/Creek

    my $view1    = "N";
    my $view2    = 'Res';
    my $view3    = '';
    my $fullView = '';

    my $MLSview = $inrec->{'View'};
    if ( $MLSview =~ /Blue Ridge|Mountain/ig ) {    #View-Blue Ridge
        $view3 = "Mtn";
    }
    elsif ( $MLSview =~ /Pastoral|Garden/ ) {       #View-Pastoral
        $view3 = "Pstrl";
    }
    elsif ( $MLSview =~ /Water/ ) {                 #View-Water
        $view3 = "Wtr";
    }
    elsif ( $MLSview =~ /Woods/ ) {                 #View-Woods
        $view3 = "Woods";
    }

    # Analyze view according to area
    # Cville

    # Albemarle

    # Nelson

    # Fluvanna

    $fullView = $view1.";".$view2.";".$view3;
    $outrec->{'LotView'} = $fullView;

    #-----------------------------------------

    # DesignAppeal

    my $stories    = "";
    my $design     = "";
    my $design_uad = '';
    my $storynum   = '';
    my $proptype   = $inrec->{'PropType'};
    my $atthome    = $inrec->{'Attached Home'};
    $stories = $inrec->{'Level'};

    # Street Number
    #$stories =~ s/\D//;
    $stories =~ s/[^0-9\.]//ig;
    $outrec->{'Stories'} = $stories;

    my $designFullName = $inrec->{'Design'};
    $design = $designFullName;
    if ( $designFullName =~ /Arts & Crafts/ig ) {
        $design = "Craftsman";
    }
    elsif ( $designFullName =~ /Contemporary/ig ) {
        $design = "Contemp";
    }

    $design =~ tr/ //ds;
    if ( $proptype =~ /Detached/ig ) {
        $design_uad = 'DT'.$stories.';'.$design;
    }
    elsif ( $proptype =~ /Attached/ig ) {
        if ( $atthome =~ /End Unit/ig ) {
            $design_uad = 'SD'.$stories.';'.$design;
        }
        elsif ( $atthome =~ /Duplex/ig ) {
            $design_uad = 'SD'.$stories.';'.$design;
        }
        else {
            $design_uad = 'AT'.$stories.';'.$design;
        }
    }
    $outrec->{'Design'}        = $design;
    $outrec->{'DesignAppeal1'} = $design_uad;

    #-----------------------------------------

    # Age
    my $age      = 0;
    my $compyear = int( $inrec->{'YearBuilt'} );
    if ( $soldstatus == 0 ) {

        # Age calculated from year sold
        my $sdate = $inrec->{'Close Date'};
        my @da    = ( $sdate =~ m/(\d+)/g );
        $age = $da[2] - $compyear;

    }

    #elsif (( $soldstatus == 1 ) || ( $soldstatus == 2 ) || ( $soldstatus == 3 ) )
    elsif ( grep { $soldstatus eq $_ } qw(1 2 3) ) {
        my $t    = Time::Piece->new();
        my $year = $t->year;
        $age = $year - $compyear;
    }
    $outrec->{'Age'} = $age;

    #-----------------------------------------

    # DesignConstructionQuality
    # Q1 through Q6
    my $extcond = '';

    # use price per square foot after location/land

    my $soldpriceint = $soldprice;
    $soldpriceint =~ s/^\$//;
    $soldpriceint =~ s/,//g;

    if ( $soldpriceint > 2000000 ) {
        $extcond = "Q1";
    }
    elsif ( $soldpriceint > 1000000 ) {
        $extcond = "Q2";
    }
    elsif ( $soldpriceint > 175000 ) {
        $extcond = "Q3";
    }
    elsif ( $soldpriceint > 80000 ) {
        $extcond = "Q4";
    }
    else {
        $extcond = "";
    }

    #$extcond = '';
    $outrec->{'DesignConstrQual'} = $extcond;

    #-----------------------------------------

    # AgeCondition1
    my $agecondition = '';
    my $agecond      = '';
    if ( $age <= 1 ) {
        $agecond = "C1";
    }
    else {
        $agecond = "C3";
    }

    #	my $kitcounter = $inrec->{"Kitchen Counters"};
    #	if ( $kitcounter =~ /Granite|Marble|Quartz|Soapstone|Wood|Solid Surface/ ) {
    #		$agecondition = "C2";
    #	} else {
    #		$agecondition = $agecond;
    #	}
    #$agecond = '';
    $outrec->{'AgeCondition1'} = $agecond;

    #-----------------------------------------
    # CarStorage1
    # UAD output example: 2ga2cp2dw, 2gd2cp2dw,

    my $garage      = '';
    my $gartype     = '';
    my $carport     = '';
    my $garnumcar   = '';
    my $cpnumcar    = '';
    my $dw          = '';
    my $nogar       = 1;
    my $nocp        = 1;
    my $nodw        = 1;
    my $carstortype = '';
    my $carstorUAD = '';
    
    # uad expansion fields
    my $atg = '0';
    my $dtg = '0';
    my $big = '0';
    my $cpg = '0';
    my $dwg = '0';
    my $garfeat     = $inrec->{'Garage Features'};

    if ( $inrec->{'Garage'} eq 'Y' ) {

        # check number of cars garage
        $garnumcar = $inrec->{'Garage#Car'};
        if ( $garnumcar =~ /(\d)/ ) {
            $garnumcar = $1;
            # number of cars exists, so use that number
        }
        else {
            $garnumcar = 1;
        }

        # check if attached/detached/built-in

        if ( $garfeat =~ /Attached/ ) {
            $gartype = 'ga';
            $atg = $garnumcar;
        }
        elsif ( $garfeat =~ /Detached/ ) {
            $gartype = 'gd';
            $dtg = $garnumcar;
        }
        elsif ( $garfeat =~ /In Basement/ ) {
            $gartype = 'bi';
            $big = $garnumcar;
        }

        $carstortype = $garnumcar.$gartype;
        $nogar       = 0;
    }

    # check for carport
    $cpnumcar = $inrec->{'Carpt#Car'};
    if ( $cpnumcar =~ /(\d)/ ) {
        $cpnumcar    = $1;
        $nocp        = 0;
        $carstortype = $carstortype.$cpnumcar.'cp';
        $cpg = $cpnumcar;
    }

    if ( $garfeat =~ /On Street Parking/ ) {
        $dw = '';
    }

    my $driveway = '';
    setifdef( $driveway, $inrec->{'Driveway'} );
    if ( $driveway =~ /Asphalt|Brick|Concrete|Dirt|Gravel|Riverstone/ ) {
        $dw          = '2dw';
        $carstortype = $carstortype.$dw;
        $dwg = 2;
    }
    
    $carstorUAD = $w.$atg.$w.$dtg.$w.$big.$w.$cpg.$w.$dwg;

    if ( $nogar && $nocp && $nodw ) {
        $carstortype = 'None';
        $carstorUAD = 'X'.$w.'0'.$w.'0'.$w.'0'.$w.'0'.$w.'0'; 
    }

    $outrec->{'CarStorage1'} = $carstortype;
    
    #UAD fields car storage:
    #None, attached garage, detached garage, built-in garage, carport, driveway
    $outrec->{'CarStorage1Txt'} = $carstorUAD;
    

        #-----------------------------------------

        # CoolingType
        my $heat = '';
    my $cool     = '';
    my $divider  = "/";
    my $cooling  = $inrec->{'Air Conditioning'};
    my $heating  = $inrec->{'Heating'};
    if ( ( $cooling =~ /Heat Pump/i ) || ( $heating =~ /Heat Pump/i ) ) {
        $heat    = "HTP";
        $cool    = '';
        $divider = '';
    }
    else {
        if ( $cooling =~ /Central AC/ ) {
            $cool = "CAC";
        }
        else {
            $cool = "NoCAC";
        }
        if ( $heating =~ /Forced Air|Furnace/i ) {
            $heat = "FWA";
        }
        elsif ( $heating =~ /Electric/i ) {
            $heat = "EBB";
        }
        elsif ( $heating =~ /Baseboard|Circulator|Hot Water/i ) {
            $heat = "HWBB";
        }
        else {
            $heat = $heating;
        }
    }
    $outrec->{'CoolingType'} = $heat.$divider.$cool;

    #-----------------------------------------

    #23 FunctionalUtility
    $outrec->{'FunctionalUtility'} = "Average";

    #-----------------------------------------

    # EnergyEfficiencies1
    # EcoCert: LEED Certified  Energy Star | EarthCraft | Energy Wise | WaterSense Certified Fixtures
    # Heating: Active Solar | Geothermal | passive Solar
    # Windows: Insulated | Low-E
    # Water Heater: Instant | Solar | Tankless

    # first check EcoCert

    my ( $energyeff, $remarks, $windows, $doors, $heats, $waterhtr, $ewndd, $eheat, $ewhtr ) = ('') x 9;
    $energyeff = 'None';
    setifdef( $remarks,  $inrec->{'Remarks'} );
    setifdef( $windows,  $inrec->{'Windows'} );
    setifdef( $doors,    $inrec->{'Doors'} );
    setifdef( $heats,    $inrec->{'Heating'} );
    setifdef( $waterhtr, $inrec->{'Water Heater'} );

    if ( $remarks =~ /LEED/i ) {
        $energyeff = "LEED Cert";
    }
    elsif ( $remarks =~ /Energy Star/i ) {
        $energyeff = "EnergyStar Cert";
    }
    elsif ( $remarks =~ /EarthCraft /i ) {
        $energyeff = "EartCraft Cert";
    }
    elsif ( $remarks =~ /Energy Wise/i ) {
        $energyeff = "EnergyWise Cert";
    }
    else {
        if ( $windows =~ /insulated|low-e/i ) {
            $ewndd = "InsWnd ";
        }
        if ( $doors =~ /insul/i ) {
            if ( $ewndd =~ /InsWnd/ig ) {
                $ewndd = "InsWnd&Drs ";
            }
            else {
                $ewndd = "InsDrs ";
            }
        }
        if ( $heats =~ /Solar/i ) {
            $eheat = "Solar ";
        }
        if ( $heats =~ /Geothermal/i ) {
            $eheat = $eheat."GeoHTP ";
        }
        if ( $waterhtr =~ /Solar/ ) {
            if ( $eheat !~ /Solar/ ) {
                $ewhtr = "Solar ";
            }
        }
        if ( $waterhtr =~ /Instant|Tankless/i ) {
            $ewhtr = "InstHW";
        }
        $energyeff = $eheat.$ewhtr.$ewndd;
        $energyeff =~ s/ /,/ig;
        $energyeff =~ s/,$//ig;
    }

    $outrec->{'EnergyEfficiencies1'} = $energyeff;

    #-----------------------------------------

    # Rooms
    # From CAAR MLS:
    # Room count includes rooms on levels other than Basement.
    # AtticApt, BasementApt, Bedroom, BilliardRm, Brkfast, BonusRm, ButlerPantry, ComboRm,
    # DarkRm, Den, DiningRm, ExerciseRm, FamRm, Foyer, Full Bath, Gallery, GarageApt, GreatRm,
    # Greenhse, Half Bath, HmOffice, HmTheater, InLaw Apt, Kitchen, Laundry, Library, LivingRm,
    # Loft, Master BR, MudRm, Parlor, RecRm, Sauna, SewingRm, SpaRm, Study/Library, SunRm, UtilityRm

    my $rooms      = 0;
    my $fullbath   = 0;
    my $halfbath   = 0;
    my $bedrooms   = 0;
    my $bsRooms    = 0;
    my $bsRecRm    = 0;
    my $bsFullbath = 0;
    my $bsHalfbath = 0;
    my $bsBedrooms = 0;
    my $bsOther    = 0;
    my $bsRmCount  = 0;

    #maximum of 30 rooms
    #my @rmarr = split( /,/, $inrec->{'Rooms'} );
    my $room             = '';
    my $indx             = 0;
    my $rindx            = 0;
    my $rlim             = 30;
    my $rmtype           = '';
    my $rmflr            = '';
    my $roomnum          = '';
    my $roomcount        = '';
    my $roomname         = '';
    my $roomfieldname    = '';
    my $roomlevfieldname = '';
    my $roomlev          = '';
    while ( $rindx < $rlim ) {
        $roomcount        = sprintf( "%02d", $rindx + 1 );
        $roomfieldname    = 'Rm'.$roomcount;
        $roomlevfieldname = $roomfieldname.'Lv';
        $roomname         = $inrec->{$roomfieldname};
        $roomlev          = $inrec->{$roomlevfieldname};

        #my $rmtype = $rmarr[$rindx];
        #my $rmsz   = $rmarr[ $rindx + 1 ];
        #my $rmflr  = $rmarr[ $rindx + 2 ];
        #$rmtype =~ s/^\s+|\s+$//g;
        #$rmflr  =~ s/ //g;

        $roomname =~ s/^\s+|\s+$//g;
        $rmtype = $roomname;
        $roomlev =~ s/ //g;
        $rmflr = $roomlev;

        if ( $rmflr !~ /Basement/ ) {
            if ( $rmtype
                =~ /Bedroom|Breakfast|Bonus|Den|Dining|Exercise|Family|Great|Home Office|Home Theater|Kitchen|Library|Living|Master|Mud|Parlor|Rec|Sauna|Sewing|Spa|Study|Library|Sun/i
                )
            {
                $rooms++;
            }
            if ( $rmtype =~ /Full Bath/i ) {
                $fullbath++;
            }
            if ( $rmtype =~ /Half Bath/i ) {
                $halfbath++;
            }
            if ( $rmtype =~ /Bedroom|Master/ ) {
                $bedrooms++;
            }
        }
        if ( $rmflr =~ /Basement/ ) {
            if ( $rmtype =~ /Bonus|Den|Family|Great|Library|Living|Rec|Study|Library/i ) {
                $bsRecRm++;
                $bsRmCount++;
            }
            if ( $rmtype
                =~ /Breakfast|Dining|Exercise|Home Office|Home Theater|Kitchen|Mud|Parlor|Sauna|Sewing|Spa|Sun/i )
            {
                $bsOther++;
                $bsRmCount++;
            }
            if ( $rmtype =~ /Full Bath/i ) {
                $bsFullbath++;
                $bsRmCount++;
            }
            if ( $rmtype =~ /Half Bath/i ) {
                $bsHalfbath++;
                $bsRmCount++;
            }
            if ( $rmtype =~ /Bedroom|Master/ ) {
                $bsBedrooms++;
                $bsRmCount++;
            }
        }

        $indx++;
        $rindx++

            #$rindx = $indx * 3;

    }
    if ( $rooms < $bedrooms + 2 ) {
        $rooms = $bedrooms + 2;
    }

    $outrec->{'Rooms'} = $rooms;

    my $bsRmList    = '';
    my $bsRmListTxt = '';

    #	if ( $bsRmCount > 0 ) {
    #		if ( $bsRecRm > 0 )    { $bsRmList = $bsRecRm . "rr"; }
    #		if ( $bsBedrooms > 0 ) { $bsRmList = $bsRmList . $bsBedrooms . "br"; }
    #		if ( ( $bsFullbath + $bsHalfbath ) > 0 ) {
    #			$bsRmList = $bsRmList . $bsFullbath . "." . $bsHalfbath . "ba";
    #		}
    #		if ( $bsOther > 0 ) { $bsRmList = $bsRmList . $bsOther . "o"; }
    #	}
    $bsRmList    = $bsRecRm.'rr'.$bsBedrooms.'br'.$bsFullbath.'.'.$bsHalfbath.'ba'.$bsOther.'o';
    $bsRmListTxt = $bsRecRm.$w.$bsBedrooms.$w.$bsFullbath.'.'.$bsHalfbath.$w.$bsOther;

    # Basement2
    $outrec->{'Basement2'}    = $bsRmList;
    $outrec->{'Basement2Txt'} = $bsRmListTxt;
    $outrec->{'BsRecRm'}      = $bsRecRm;
    $outrec->{'BsBedRm'}      = $bsBedrooms;
    $outrec->{'BsFullB'}      = $bsFullbath;
    $outrec->{'BsHalfB'}      = $bsHalfbath;
    $outrec->{'BsOther'}      = $bsOther;

    #-----------------------------------------

    # Bedrooms
    my $bedroomstot = $inrec->{'#Beds'};
    my $bedroomsbg  = $inrec->{'#BedsBG'};
    my $bedroomsAG  = $bedroomstot - $bedroomsbg;

    $outrec->{'Beds'} = $bedroomsAG;

    #-----------------------------------------

    # Baths
    my $baths = 0;

    #	if ( $fullbath == 0 ) {
    #		$fullbath = $inrec->{'#FBaths'};
    #		$halfbath = $inrec->{'#HBaths'};
    #	}

    $fullbath = $inrec->{'#FBaths'};
    $halfbath = $inrec->{'#HBaths'};
    my $bgbath = $inrec->{'#BathsBG'};
    if ( $bgbath =~ /.5/ ) {
        $halfbath = $halfbath - 1;
        $bgbath   = $bgbath - 1;
    }
    if ( $bgbath >= 1 ) {
        $fullbath = $fullbath - $bgbath;
    }
    my $bathnum = $fullbath + $halfbath / 10;
    my $bathstr = "$fullbath.$halfbath";
    $baths = sprintf( "%.1f", $bathnum );
    $outrec->{'Baths'} = $bathstr;

    #-----------------------------------------

    # BathsFull
    $outrec->{'BathsFull'} = $fullbath;

    #-----------------------------------------

    # BathsHalf
    $outrec->{'BathsHalf'} = $halfbath;

    #-----------------------------------------

    # Basement1
    # Crawl | English | Finished | Full | Heated | Inside Access | Outside Access |
    # Partial | Partly Finished | Rough Bath Plumb | Shelving | Slab | Sump Pump |
    # Unfinished | Walk Out | Windows | Workshop

    $outrec->{'Basement1'} = '';

    #-----------------------------------------

    # Basement2
    #$outrec->{'Basement2'} = $bsmntfin;

    #-----------------------------------------

    $outrec->{'ExtraCompInfo2'} = '';

    #-----------------------------------------

    # ExtraCompInfo1 (Fireplaces)
    my ( $fp, $fpout, $numFPword, $numFP, $locFP, $locFPcnt ) = ('') x 6;

    $numFPword = $inrec->{'Fireplace'};
    if ( $numFPword =~ /One/ ) {
        $numFP = 1;
    }
    elsif ( $numFPword =~ /Two/ ) {
        $numFP = 2;
    }
    elsif ( $numFPword =~ /Three/ ) {
        $numFP = 3;
    }
    else {
        $numFP = 0;
    }

    setifdef( $locFP, $inrec->{'Fireplace Location'} );
    $locFPcnt = $locFP =~ (
        m/Basement|Bedroom|Den|Dining Room|Exterior Fireplace|Family Room|Foyer|Great Room|!
								Home Office|Kitchen|Library|Living Room|Master Bedroom|Study/ig
    );
    if ( !$locFPcnt ) { $locFPcnt = 0 }

    if ( $numFP >= $locFPcnt ) {
        $fp = $numFP;
    }
    elsif ( $locFPcnt >= $numFP ) {
        $fp = $locFPcnt;
    }
    elsif ( $numFP == 0 && $locFPcnt == 0 ) {
        $fpout = "0 Fireplace";
    }

    if ( $fp == 0 ) {
        $fpout = "0 Fireplace";
    }

    if ( $fp == 1 ) {
        $fpout = $fp." Fireplace";
    }
    elsif ( $fp > 1 ) {
        $fpout = $fp." Fireplaces";
    }

    $outrec->{'ExtraCompInfo1'} = $fpout;

    #-----------------------------------------

    # SqFt Source: Appraisal, Builder, Other, Owner, Tax Assessor
    my $sqftsrc = '';

    #-----------------------------------------

    # SqFt (after basement is determined)
    # Square foot fields added to CAAR on 7/19/2011:
    # SqFt Above Grade Fin
    # SqFt Above Grade Total
    # SqFt Above Grade UnFin
    # SqFt Below Grade Fin
    # SqFt Below Grade Total
    # SqFt Below Grade Unfin
    # SqFt Fin Total
    # SqFt Garage Fin
    # SqFt Garage Total
    # SqFt Garage Unfin
    # SqFt Total
    # SqFt Unfin Total

    my $sfAGFin = $inrec->{'AGFin'};
    $sfAGFin =~ s/,//g;
    my $sfAGTot = $inrec->{'AGTotSF'};
    my $sfAGUnF = $inrec->{'AGUnfin'};
    my $sfBGFin = $inrec->{'BGFin'};
    my $sfBGTot = $inrec->{'BGTotSF'};
    my $sfBGUnF = $inrec->{'BGUnfin'};
    my $sfFnTot = $inrec->{'TotFinSF'};
    my $sfGaFin = $inrec->{'GarAGFin'};
    my $sfGaTot = $inrec->{'GarTotAG'};
    my $sfGaUnF = $inrec->{'GarAGUnf'};
    my $sfTotal = $inrec->{'TotFinSF'};
    my $sfUnTot = $inrec->{'TotUnfinSF'};

    #my $listdate = Date::EzDate->new( $inrec->{'List Date'} );
    #if ( $listdate >= $sfDate ) {
    my $basType    = "wo";
    my $basTypeTxt = "Walk-out";
    $sfBGTot =~ s/,//;
    $sfBGFin =~ s/,//;
    if ( $sfAGFin > 0 ) {
        $outrec->{'SqFt'} = $sfAGFin;
        if ( $sfBGTot == 0 ) {
            $outrec->{'Basement1'}    = "0sf";
            $outrec->{'Basement1Txt'} = 0 .$w. 0;
            $outrec->{'Basement2'}    = $w;
            $outrec->{'Basement2Txt'} = 0 .$w. 0 .$w."0.0".$w. 0;
        }
        else {
            my $basExit = $inrec->{'Bsmnt_2'};
            if ( $basExit =~ /Walk Out/ig ) {
                $basType    = "wo";
                $basTypeTxt = "Walk-out";
            }
            elsif ( $basExit =~ /Outside Entrance/ig ) {
                $basType    = "wu";
                $basTypeTxt = "Walk-up";
            }
            elsif ( $basExit =~ /Inside Access/ig ) {
                $basType    = "in";
                $basTypeTxt = "Interior-only";
            }

            #Walk Out
            if ( $sfBGFin == 0 ) {
                $outrec->{'Basement1'}    = $sfBGTot."sf". 0 .$basType;
                $outrec->{'Basement1Txt'} = $sfBGTot.$w. 0 .$w.$basTypeTxt;
            }
            else {
                $outrec->{'Basement1'}    = $sfBGTot."sf".$sfBGFin."sf".$basType;
                $outrec->{'Basement1Txt'} = $sfBGTot.$w.$sfBGFin.$w.$basTypeTxt;
            }
        }
    }
    else {
        # SF Above Grade not entered, use SqFt Fin total
        my $sqft        = '';
        my $sqftabvGrnd = '';
        my $bsmntyn     = $inrec->{'Bsmnt_1'};
        my $bsmntfin    = $inrec->{'Bsmnt_2'};

        if ( ( $sfAGFin eq '' ) | ( $sfAGFin eq undef ) | ( $sfAGFin == 0 ) ) {

            $sfAGFin = $inrec->{'TotFinSF'};
            $stories = $inrec->{'Levels'};
            $sqft    = $sfAGFin;
            if ( $bsmntyn eq 'No' ) {
                $sqftabvGrnd = $sqft;

            }
            elsif ( $bsmntfin eq 'Finished' ) {
                if ( $stories eq '1 Story' ) {
                    $sqftabvGrnd = round( 0.5 * $sqft );
                }
                elsif ( $stories eq '1.5 Story' ) {
                    $sqftabvGrnd = round( 0.6 * $sqft );
                }
                elsif ( $stories eq '2 Story' ) {
                    $sqftabvGrnd = round( 0.67 * $sqft );
                }
                else {
                    $sqftabvGrnd = round( 0.75 * $sqft );
                }

            }
            elsif ( $bsmntfin eq 'Partly Finished' ) {
                if ( $stories eq '1 Story' ) {
                    $sqftabvGrnd = round( 0.67 * $sqft );
                }
                elsif ( $stories eq '1.5 Story' ) {
                    $sqftabvGrnd = round( 0.75 * $sqft );
                }
                elsif ( $stories eq '2 Story' ) {
                    $sqftabvGrnd = round( 0.8 * $sqft );
                }
                else {
                    $sqftabvGrnd = round( 0.8 * $sqft );
                }

            }
            else {
                $sqftabvGrnd = $sqft;
            }

        }
        else {
            $sqftabvGrnd = $sfAGFin;
        }

        $outrec->{'SqFt'} = $sqftabvGrnd;
    }

    #-----------------------------------------

    # Porch ()Porch/Patio/Deck)
    # Porch: Balcony | Brick | Deck | Front | Glassed | Patio | Porch | Rear | Screened | Side | Slate | Terrace
    my $pchcnt = 0;
    my $balcnt = 0;
    my $dekcnt = 0;
    my $patcnt = 0;
    my $tercnt = 0;

    my $pchout = '';
    my $pdp    = $inrec->{'Structure-Deck/Porch'};
    if ( $pdp =~ /Porch[^ -]|Rear|Side/ ) {
        $pchout = "Pch ";
        $pchcnt++;
    }
    if ( $pdp =~ /Front/ig ) {
        $pchout = $pchout."FPc ";
        $pchcnt++;
    }
    if ( $pdp =~ /Screened/ig ) {
        $pchout = $pchout."ScPc ";
        $pchcnt++;
    }
    if ( $pdp =~ /Glassed/ig ) {
        $pchout = $pchout."EncPc ";
        $pchcnt++;
    }

    $outrec->{'Porch'} = $pchout;

    #-----------------------------------------

    my $patout = '';
    if ( $pdp =~ /Patio[^ -]/ ) {
        $patout = "Pat ";
    }
    if ( $pdp =~ /Covered/ig ) {
        $patout = $pchout."CvPat ";
    }
    $outrec->{'Patio'} = $patout;

    #-----------------------------------------

    my $dkout = '';
    if ( $pdp =~ /Deck/ ) {
        $patout = "Deck ";
    }
    $outrec->{'Deck'} = $dkout;

    #-----------------------------------------

    # FencePorchPatio2
    my $totpchcnt = 0;
    my $pdpout    = '';

    $pdpout = $pchout.$patout.$dkout;
    $outrec->{'FencePorchPatio2'} = $pdpout;

    #-----------------------------------------

    # ExtraCompInfo3
    $outrec->{'ExtraCompInfo3'} = $pdpout;

    #-----------------------------------------

    # Notes1
    $outrec->{'Notes1'} = "Imported from CAAR";

    #-----------------------------------------

    # Photo
    my $photo = '';
    $photo = $inrec->{'Photo 1'};
    $outrec->{'Photo'} = '';

    #-----------------------------------------

    my $mediaflag = '';
    setifdef( $mediaflag, $inrec->{'Media Flag'} );
    $outrec->{'MediaFlag'} = '';

    #-----------------------------------------

    my $medialink = $inrec->{'Media Link'};
    my $mediapath = '';
    if ( $mediaflag =~ m/1 Photo|Multiphotos/ig ) {
        if ( $medialink =~ /(http:\/\/www.caarmls.com.*?.jpg>)/ix ) {
            $mediapath = $1;
        }
    }
    $outrec->{'MediaLink'} = '';

    #-----------------------------------------

    # ML Number
    my $mlnumber = '';
    $mlnumber = $inrec->{'MLS#'};
    $outrec->{'MLNumber'} = $mlnumber;

    #-----------------------------------------

    # ML Prop Type
    $proptype             = '';
    $proptype             = $inrec->{'PropType'};
    $outrec->{'PropType'} = $proptype;

    #-----------------------------------------

    # ML County
    my $county = '';
    my $area   = '';
    $area = $inrec->{'Cnty/IncC'};
    switch ($area) {
        case '001' { $county = "Albemarle" }
        case '002' { $county = "Amherst" }
        case '003' { $county = "Augusta" }
        case '004' { $county = "Buckingham" }
        case '005' { $county = "Charlottesville" }
        case '006' { $county = "Culpeper" }
        case '007' { $county = "Fauquier" }
        case '008' { $county = "Fluvanna" }
        case '009' { $county = "Goochland" }
        case '010' { $county = "Greene" }
        case '011' { $county = "Louisa" }
        case '012' { $county = "Madison" }
        case '013' { $county = "Nelson" }
        case '014' { $county = "Orange" }
        case '015' { $county = "Rockbridge" }
        case '016' { $county = "Waynesboro" }
        case '017' { $county = "Other" }
    }
    $outrec->{'County'} = $county;

    #-----------------------------------------

    # DateofPriorSale1
    my $dateofPriorSale1 = '';
    $outrec->{'DateofPriorSale1'} = $dateofPriorSale1;

    #-----------------------------------------

    # PriceofPriorSale1
    my $priceofPriorSale1 = '';
    $outrec->{'PriceofPriorSale1 '} = $priceofPriorSale1;

    #-----------------------------------------

    # DataSourcePrior1
    my $dataSourcePrior1 = "Assessors Records";
    if ( $area >= 9 ) {
        $dataSourcePrior1 = "Courthouse Records";
    }
    $outrec->{'DataSourcePrior1'} = $dataSourcePrior1;

    #-----------------------------------------

    # EffectiveDatePrior1
    my $effectiveDatePrior1 = '';
    $outrec->{'EffectiveDatePrior1'} = $effectiveDatePrior1;

    #-----------------------------------------

    # Agent Notes
    my $agentNotes = '';    #$inrec->{'Agent Notes'};
    if ( defined $agentNotes ) {

        # $outrec->{'AgentNotes'} = $agentNotes;
        $outrec->{'AgentNotes'} = '';
    }

    #-----------------------------------------

    # Dependencies
    my $dependencies = $inrec->{'Dependencies'};
    if ( defined $dependencies ) {
        $outrec->{'Dependencies'} = $dependencies;
    }

    #-----------------------------------------

    # Zoning
    my $zoning = $inrec->{'Zoning'};
    if ( defined $zoning ) {
        $outrec->{'Zoning'} = $zoning;
    }

    #-----------------------------------------

    # Hoa Fee
    my $hoafee = $inrec->{'AssnFee'};
    if ( defined $hoafee ) {
        $outrec->{'HoaFee'} = $hoafee;
    }

    #-----------------------------------------

    #condo specific
    my $aprop = $inrec->{'PropType'};
    if ( $aprop =~ /Condo/ig ) {

        # Unit Number
        my $unitnum = $inrec->{'Unit #'};
        $outrec->{'Unitnum'} = $unitnum;

        # Amenities
        #Art Studio | Bar/Lounge | Baseball Field | Basketball Court | Beach | Billiard Room
        #| Boat Launch | Clubhouse | Community Room | Dining Rooms | Exercise Room | Extra Storage
        #| Golf | Guest Suites | Lake | Laundry Room | Library | Meeting Room | Newspaper Serv.
        #| Picnic Area | Play Area | Pool | Riding Trails | Sauna | Soccer Field | Stable
        #| Tennis | Transportation Service | Volleyball | Walk/Run Trails

        # | Walk/Run Trails | Boat Launch | Clubhouse | Community Room | Exercise Room
        # | Extra Storage | Golf | Play Area | Pool | Riding Trails | Sauna | Stable Tennis | Walk/Run Trails

        my $amenities = $inrec->{'Amenities(HOA/Club/Sub)'};
        $outrec->{'Amenities'} = $amenities;

        # stories
        # 1-4 stories:  stories
        # 5-7:			mid-rise
        # 8 and higher: High-rise

        # address modified with unit number
        $outrec->{'Address1'} = $outrec->{'Address1'};
        $outrec->{'Address2'} = $unitnum.$outrec->{'Address2'};

        # location set to city

        # subdivision set to project name
        my $projectname = titleCap( $inrec->{'Subdivision'} );
        $projectname =~ s/ \(.*//;
        $outrec->{'ProjectName'} = $projectname;
        $outrec->{'HOAFee'}      = $inrec->{'AssnFee'};

    }

    #-----------------------------------------
    #-----------------------------------------
    # CAAR_Resid Last Line
    #my $pnum = 1;
    #while ( my ( $k, $v ) = each %$outrec ) {
    #print $outfile "$v\t";

    # print "$pnum\n";
    # $pnum = $pnum+1;
    #}
    #print $outfile "\n";

}

sub CAAR_Resid_Text {

    # output comparable as text file for direct copy into Total
    my ($outrec)  = shift;
    my ($outfile) = shift;

    my $or = $outrec;
    my $w = sprintf( '%c', 8 );

    # Line	Form Field					input field
    #	1	111 Street Ave				street address (from MLS)
    #	2	City, ST 12345				street address
    #	3	CityST12345				city, state, zip
    #	4   Proximity
    #	5   Sale Price
    #	6   Price per square foot
    #	7   CAARMLS#;DOM
    #	8   CAARMLS#DOM
    #	9   Tax Records
    #	10  sale type
    #	11  financing type;concession amount
    #	12  financing typeconcession amount
    #	13  s02/17;c01/17
    #	14  Settled saleX01/1702/17
    #	15  N;Res;
    #	16  NeutralResidential
    #	17  Fee Simple
    #	18  21780 sf
    #	19  N;Res;
    #	20  NeutralResidential
    #	21  DT2;Colonial
    #	22  X2Colonial
    #   23  Q3
    #	24  10
    #	25  C3
    #	26  742.1
    #	27  2,500
    #	28  2500sf1000sfwo
    #	29  25001000Walk-out
    #	30  1rr1br1.1ba1o
    #	31  111.11
    #	32  Average
    #	33  FWA/CAC
    #	34  InsulWnd&Drs
    #	35  2ga2dw
    #   36  22
    #	37  CvP,Deck
    #	38  1 Fireplace
    #

    #pre-processing of some fields for text output
    my $uadexp1 = $or->{'FinFullNm'}.$w.$or->{'FinOther'}.$w.$or->{'Conc'};
    my $datestr = $or->{'SaleStatus'}.$w."X".$w.$w.$or->{'ContDate'}.$w.$or->{'SaleDate'}.$w.$w.$w.$w;
    my $design  = "x".$w.$w.$w.$or->{'Stories'}.$w.$or->{'Design'}.$w.$w;
    my $rooms   = $or->{'Rooms'}.$w.$or->{'Beds'}.$w.$or->{'Baths'}.$w.$w;

    tie my %comp    => 'Tie::IxHash',
        address1    => $or->{'Address1'}.$w,
        address2    => $or->{'Address2'}.$w,
        citystzip   => $or->{'City'}.$w.$or->{'State'}.$w.$or->{'Zip'}.$w,
        proximity   => $w,
        saleprice   => $or->{'SalePrice'}.$w,
        saleprgla   => $w,
        datasrc     => $or->{'DataSource1'}.$w."CAARMLS #".$or->{'MLNumber'}.$w.$or->{'DOM'}.$w,
        versrc      => $or->{'DataSource2'}.$w,
        saletype    => $or->{'FinanceConcessions1'}.$w.$w,
        finconc     => $or->{'FinanceConcessions2'}.$w.$uadexp1.$w.$w,
        datesale    => $or->{'SaleDateFormatted'}.$w.$datestr,
        location    => "N;Res".$w."Neutral".$w."Residential".$w.$w.$w.$w.$w,
        lsorfeesim  => "Fee Simple".$w.$w,
        site        => $or->{'LotSize'}.$w.$w,
        view        => "N;Res".$w."Neutral".$w."Residential".$w.$w.$w.$w.$w,
        designstyle => $or->{'DesignAppeal1'}.$w.$design,
        quality     => $or->{'DesignConstrQual'}.$w.$w,
        age         => $or->{'Age'}.$w.$w,
        condition   => $or->{'AgeCondition1'}.$w.$w.$w,
        roomcnt     => $rooms,
        gla         => $or->{'SqFt'}.$w.$w,
        basement    => $or->{'Basement1'}.$w.$or->{'Basement1Txt'}.$w.$w,
        basementrm  => $or->{'Basement2'}.$w.$or->{'Basement2Txt'}.$w.$w,
        funcutil    => "Average".$w.$w,
        heatcool    => $or->{'CoolingType'}.$w.$w,
        energyeff   => $or->{'EnergyEfficiencies1'}.$w.$w,
        garage      => $or->{'CarStorage1'}.$w,
        garage1     => $or->{'CarStorage1Txt'}.$w.$w,
        pchpatdk    => $or->{'FencePorchPatio2'}.$w.$w,
        fireplace   => $or->{'ExtraCompInfo1'}.$w.$w;

    my $x = 1;

    #print $outfile "\n";
    while ( my ( $key, $value ) = each(%comp) ) {
        print $outfile ($value);
    }
    print $outfile "\n";

}

sub CAAR_Condo {

    # output comparable as text file for direct copy into Total
    my ($outrec)  = shift;
    my ($outfile) = shift;

    my $or = $outrec;
    my $w = sprintf( '%c', 8 );

    #CONDO

    # Line  Form Field                          input field
    #   1   137 Green Turtle Ln                street address (from MLS)
    #   2   5, Charlottesville, VA 22901       unit #, street address
    #   3   5CharlottesvilleVA22901         unit #, city, state, zip
    #   4   Turtle Creek Condos                Project Name
    #   5   7                                   Phase
    #   6   Proximity
    #   7   Sale Price
    #   8   Price per square foot
    #   9   CAARMLS#;DOM
    #   10  CAARMLS#DOM
    #   11  Tax Records
    #   12  sale type
    #   13  ArmLthCash;0
    #   14  Cash0
    #   13  s02/17;c01/17
    #   14  Settled saleX07/1707/17
    #   15  N;Res;
    #   16  NeutralResidential
    #   17  Fee Simple
    #   18  HOA Fee
    #   19  Common Elements
    #   20  Rec Facilities
    #   19  N;Res;
    #   20  NeutralResidential
    #   21  DT2;Colonial
    #   22  X2Colonial
    #   23  Q3
    #   24  10
    #   25  C3
    #   26  742.1
    #   27  2,500
    #   28  2500sf1000sfwo
    #   29  25001000Walk-out
    #   30  1rr1br1.1ba1o
    #   31  111.11
    #   32  Average
    #   33  FWA/CAC
    #   34  InsulWnd&Drs
    #   35  2ga2dw
    #   36  22
    #   37  CvP,Deck
    #   38  1 Fireplace

    # Additional fields requred for condo specific:
    # unit #, project name (subdivison), project phase (not available), HOA Fee
    # common elements, rec facilities

    #pre-processing of some fields for text output
    my $uadexp1 = $or->{'FinFullNm'}.$w.$or->{'FinOther'}.$w.$or->{'Conc'};
    my $datestr = $or->{'SaleStatus'}.$w."X".$w.$w.$or->{'ContDate'}.$w.$or->{'SaleDate'}.$w.$w.$w.$w;
    my $design  = "x".$w.$w.$w.$or->{'Stories'}.$w.$or->{'Design'}.$w.$w;
    my $rooms   = $or->{'Rooms'}.$w.$or->{'Beds'}.$w.$or->{'Baths'}.$w.$w;

    tie my %comp    => 'Tie::IxHash',
        address1    => $or->{'Address1'}.$w,
        address2    => $or->{'Address2'}.$w,
        citystzip   => $or->{'Unitnum'}.$w.$or->{'City'}.$w.$or->{'State'}.$w.$or->{'Zip'}.$w,
        project     => $or->{'ProjectName'}.$w,
        phase       => $w,
        proximity   => $w,
        saleprice   => $or->{'SalePrice'}.$w,
        saleprgla   => $w,
        datasrc     => $or->{'DataSource1'}.$w."CAARMLS #".$or->{'MLNumber'}.$w.$or->{'DOM'}.$w,
        versrc      => $or->{'DataSource2'}.$w,
        saletype    => $or->{'FinanceConcessions1'}.$w.$w,
        finconc     => $or->{'FinanceConcessions2'}.$w.$uadexp1.$w.$w,
        datesale    => $or->{'SaleDateFormatted'}.$w.$datestr,
        location    => "N;Res".$w."Neutral".$w."Residential".$w.$w.$w.$w.$w,
        lsorfeesim  => "Fee Simple".$w.$w,
        hoafee      => $or->{'HOAFee'}.$w.$w,
        commonelem  => $w.$w,
        recfacil    => $w.$w,
        floorloc    => $w.$w.$w,
        view        => "N;Res;".$w."Neutral".$w."Residential".$w.$w.$w.$w.$w,
        designstyle => $w.$w.$w.$w.$w.$w.$w.$w.$w.$w,
        quality     => $or->{'DesignConstrQual'}.$w.$w,
        age         => $or->{'Age'}.$w.$w,
        condition   => $or->{'AgeCondition1'}.$w.$w.$w,
        roomcnt     => $rooms,
        gla         => $or->{'SqFt'}.$w.$w,
        basement    => $or->{'Basement1'}.$w.$or->{'Basement1Txt'}.$w.$w,
        basementrm  => $or->{'Basement2'}.$w.$or->{'Basement2Txt'}.$w.$w,
        funcutil    => "Average".$w.$w,
        heatcool    => $or->{'CoolingType'}.$w.$w,
        energyeff   => $or->{'EnergyEfficiencies1'}.$w.$w,
        garage      => $or->{'CarStorage1'}.$w.$w,
        pchpatdk    => $or->{'FencePorchPatio2'}.$w.$w,
        fireplace   => $or->{'ExtraCompInfo1'}.$w.$w;

    my $x = 1;

    #print $outfile "\n";
    while ( my ( $key, $value ) = each(%comp) ) {
        print $outfile ($value);
    }
    print $outfile ("\n");
}

sub CAAR_Desktop {
        
    # output comparable as text file for direct copy into Total
    my ($outrec)  = shift;
    my ($outfile) = shift;

    my $or = $outrec;
    my $w = sprintf( '%c', 8 );
    
    # Line  Form Field                          input field
    # 1     123 Anystreet St
    # 2     Palmyra, VA 22963
    # 3     Proximity
    # 4     MLS #579973; DOM 24
    # 5     198,000
    # 6     10/31/2018
    # 7     1.0 Ac
    # 8     1,500
    # 9     32.0
    # 10    Age 9
    # 11    2 Car Built-in Garage
    # 12    Bsmnt: 850sf/0sf Fin
    # 13    CvP
    
        #pre-processing of some fields for text output
    my $uadexp1 = $or->{'FinFullNm'}.$w.$or->{'FinOther'}.$w.$or->{'Conc'};
    my $datestr = $or->{'SaleStatus'}.$w."X".$w.$w.$or->{'ContDate'}.$w.$or->{'SaleDate'}.$w.$w.$w.$w;
    my $design  = "x".$w.$w.$w.$or->{'Stories'}.$w.$or->{'Design'}.$w.$w;
    my $rooms   = $or->{'Rooms'}.$w.$or->{'Beds'}.$w.$or->{'Baths'}.$w.$w;

    tie my %comp    => 'Tie::IxHash',
        address1    => $or->{'Address1'}.$w,
        address2    => $or->{'Address2'}.$w,
        proximity   => $w,
        datasrc     => "MLS #".$or->{'MLNumber'}."; DOM ".$or->{'DOM'}.$w,       
        saleprice   => $or->{'SalePrice'}.$w,
        datesale    => $or->{'DateSaleTime1'}.$w,
        site        => $or->{'LotSize'}.$w,
        gla         => $or->{'SqFt'}.$w,
        bedbath     => $or->{'Beds'}.$w.$or->{'Baths'}.$w,
        age         => $or->{'Age'}.$w,
        garage      => $or->{'CarStorage1'}.$w;

    my $x = 1;

    #print $outfile "\n";
    while ( my ( $key, $value ) = each(%comp) ) {
        print $outfile ($value);
    }
    print $outfile ("\n");
    
}

sub WTrecord {

    # output record
    # side data structure
    tie my %wthash          => 'Tie::IxHash',
        StreetNum           => '',
        StreetDir           => '',
        StreetName          => '',
        StreetSuffix        => '',
        Address1            => '',
        Address2            => '',
        Address3            => '',
        City                => '',
        State               => '',
        Zip                 => '',
        PropertyRights      => '',
        DataSource1         => '',
        DataSource2         => '',
        DesignAppeal1       => '',
        DesignConstrQual    => '',
        Age                 => '',
        AgeCondition1       => '',
        CarStorage1         => '',
        LotSize             => '',
        LotView             => '',
        CoolingType         => '',
        FunctionalUtility   => '',
        EnergyEfficiencies1 => '',
        SalePrice           => '',
        Status              => '',
        Beds                => '',
        Baths               => '',
        BathsFull           => '',
        BathsHalf           => '',
        Basement1           => '',
        Basement2           => '',
        ExtraCompInfo2      => '',
        ExtraCompInfo1      => '',
        SqFt                => '',
        Rooms               => '',
        Location1           => '',
        DateSaleTime1       => '',
        DateSaleTime2       => '',
        FinanceConcessions1 => '',
        FinanceConcessions2 => '',
        Porch               => '',
        Patio               => '',
        Deck                => '',
        FencePorchPatio2    => '',
        ExtraCompInfo3      => '',
        Notes1              => '',
        Photo               => '',
        MediaFlag           => '',
        MediaLink           => '',
        MLNumber            => '',
        PropType            => '',
        County              => '',
        DateofPriorSale1    => '',
        PriceofPriorSale1   => '',
        DataSourcePrior1    => '',
        EffectiveDatePrior1 => '',
        Dependencies        => '',
        Amenities           => '',
        UnitNum             => '',
        HoaFee              => '',
        AgentNotes          => '',
        Zoning              => '',
        SaleDateFormatted   => '',
        DOM                 => '',
        FinConc             => '',
        FinFullNm           => '',
        FinOther            => '',
        Conc                => '',
        SaleStatus          => '',
        SaleDate            => '',
        ContDate            => '',
        Stories             => '',
        Design              => '';

    #DOM                 => '',
    #CloseDate           => '',
    #ContrDate           => '';

    tie my %sdhash     => 'Tie::IxHash',
        fullStreetName => "",
        streetSuffix   => "";

    #my $val = $wthash{key1};
    #print %wthash;

    return \%wthash;
}

sub printFields {
    my ($localhash) = shift;
    my ($localfile) = shift;

    while ( my ( $k, $v ) = each %$localhash ) {
        print $localfile "$k\t";
    }
    print $localfile "\n";
}

sub USA_Format {

    ( my $n = shift ) =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g;
    return "\$$n";
}

sub setifdef {
    $_[0] = $_[1] if defined( $_[1] );
}

sub hello {
    my ( $in1, $in2 ) = @_;
    return $in1 + $in2;
}

sub titleCap {
    local $_ = shift;

    my %nocap;
    for (
        qw(
        a an the
        and but or
        as at but by for from in into of off on onto per to with
        )
        )
    {
        $nocap{$_}++;
    }

    # put into lowercase if on stop list, else titlecase
    s/(\pL[\pL']*)/$nocap{$1} ? lc($1) : ucfirst(lc($1))/ge;

    s/^(\pL[\pL']*) /\u\L$1/x;    # last  word guaranteed to cap
    s/ (\pL[\pL']*)$/\u\L$1/x;    # first word guaranteed to cap

    # treat parenthesized portion as a complete title
    s/\( (\pL[\pL']*) /(\u\L$1/x;
    s/(\pL[\pL']*) \) /\u\L$1)/x;

    # capitalize first word following colon or semi-colon
    s/ ( [:;] \s+ ) (\pL[\pL']* ) /$1\u\L$2/x;

    return $_;
}
