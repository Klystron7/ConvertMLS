#!/usr/bin/perl -w -- 
#
# generated by wxGlade 0.9.0b2 on Thu Jan 17 20:59:26 2019
#
# To get wxPerl visit http://www.wxperl.it
#

use Wx qw[:allclasses];
use strict;

# begin wxGlade: dependencies
# end wxGlade

# begin wxGlade: extracode
# end wxGlade

package MyFrame;

use Wx qw[:everything];
use base qw(Wx::Frame);
use strict;
use Data::Dumper qw(Dumper);

#use My::ConvertMLS qw(DoConvert);

use lib "C:\\Users\\Ernest\\git\\ConvertMLS\\src";
use My::MLStoText qw(DoConvert);

sub new {
    my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
    $parent = undef              unless defined $parent;
    $id     = -1                 unless defined $id;
    $title  = "Convert MLS"      unless defined $title;
    $pos    = wxDefaultPosition  unless defined $pos;
    $size   = wxDefaultSize      unless defined $size;
    $name   = ""                 unless defined $name;

    # begin wxGlade: MyFrame::new
    $style = wxDEFAULT_FRAME_STYLE
        unless defined $style;

    $self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
    $self->SetSize(Wx::Size->new(598, 445));
    #$self->SetSize(Wx::Size->new(610, 400));
    $self->{panel_1} = Wx::Panel->new($self, wxID_ANY);
    $self->{checkbox_1004} = Wx::CheckBox->new($self->{panel_1}, wxID_ANY, "");
    $self->{checkbox_1073} = Wx::CheckBox->new($self->{panel_1}, wxID_ANY, "");
    $self->{checkbox_1007} = Wx::CheckBox->new($self->{panel_1}, wxID_ANY, "");
    $self->{checkbox_1025mfc} = Wx::CheckBox->new($self->{panel_1}, wxID_ANY, "");
    $self->{checkbox_1025mfr} = Wx::CheckBox->new($self->{panel_1}, wxID_ANY, "");
    $self->{checkbox_Dtcomp} = Wx::CheckBox->new($self->{panel_1}, wxID_ANY, "");
    $self->{Open_file} = Wx::Button->new($self->{panel_1}, wxID_ANY, "Open File");
    $self->{Exit} = Wx::Button->new($self->{panel_1}, wxID_ANY, "Exit");
    $self->{text_ctrl_1} = Wx::TextCtrl->new($self->{panel_1}, wxID_ANY, "", wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE);

    $self->__set_properties();
    $self->__do_layout();    

    Wx::Event::EVT_CHECKBOX($self, $self->{checkbox_1004}->GetId, $self->can('cb1'));
    Wx::Event::EVT_CHECKBOX($self, $self->{checkbox_1073}->GetId, $self->can('cb2'));
    Wx::Event::EVT_CHECKBOX($self, $self->{checkbox_1007}->GetId, $self->can('cb3'));
    Wx::Event::EVT_CHECKBOX($self, $self->{checkbox_1025mfc}->GetId, $self->can('cb4'));
    Wx::Event::EVT_CHECKBOX($self, $self->{checkbox_1025mfr}->GetId, $self->can('cb5'));
    Wx::Event::EVT_CHECKBOX($self, $self->{checkbox_Dtcomp}->GetId, $self->can('cb6'));
    Wx::Event::EVT_BUTTON($self, $self->{Open_file}->GetId, $self->can('OpenFile'));
    Wx::Event::EVT_BUTTON($self, $self->{Exit}->GetId, $self->can('Finish'));
    Wx::Event::EVT_TEXT($self, $self->{text_ctrl_1}->GetId, $self->can('text'));
    Wx::Event::EVT_TEXT_ENTER($self, $self->{text_ctrl_1}->GetId, $self->can('textenter'));
    Wx::Event::EVT_TEXT_MAXLEN($self, $self->{text_ctrl_1}->GetId, $self->can('textmaxlen'));
    Wx::Event::EVT_TEXT_URL($self, $self->{text_ctrl_1}->GetId, $self->can('texturl'));

    my @cbO = ( 0, 0, 0, 0, 0, 0 );
    $self->{cbOptions} = \@cbO;
    
    my $ccb = {
        cbname => "",
        cbnum => 0
    };
    
    $self->{cbName} = $ccb;    
    
    # end wxGlade
    return $self;

}


sub __set_properties {
    my $self = shift;
    # begin wxGlade: MyFrame::__set_properties
    $self->SetTitle("MLS Conversion");
    # end wxGlade
}

sub __do_layout {
    my $self = shift;
    # begin wxGlade: MyFrame::__do_layout
    $self->{sizer_1} = Wx::BoxSizer->new(wxVERTICAL);
    $self->{grid_sizer_1} = Wx::FlexGridSizer->new(1, 2, 0, 0);
    $self->{grid_sizer_3} = Wx::FlexGridSizer->new(2, 1, 0, 0);
    $self->{grid_sizer_2} = Wx::FlexGridSizer->new(7, 1, 0, 0);
    $self->{grid_sizer_6} = Wx::FlexGridSizer->new(1, 2, 0, 0);
    $self->{grid_sizer_4} = Wx::FlexGridSizer->new(6, 2, 0, 0);
    $self->{grid_sizer_2}->Add(20, 20, 0, wxEXPAND, 0);
    my $label_1 = Wx::StaticText->new($self->{panel_1}, wxID_ANY, "Select Output Format:");
    $self->{grid_sizer_2}->Add($label_1, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 5);
    my $static_line_1 = Wx::StaticLine->new($self->{panel_1}, wxID_ANY);
    $self->{grid_sizer_2}->Add($static_line_1, 1, wxALL|wxEXPAND, 5);
    my $label_2 = Wx::StaticText->new($self->{panel_1}, wxID_ANY, "1004 Single Famiy Comp");
    $self->{grid_sizer_4}->Add($label_2, 1, wxALIGN_RIGHT|wxALL, 5);
    $self->{grid_sizer_4}->Add($self->{checkbox_1004}, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 5);
    my $label_3 = Wx::StaticText->new($self->{panel_1}, wxID_ANY, "1073 Condo Comp");
    $self->{grid_sizer_4}->Add($label_3, 1, wxALIGN_RIGHT|wxALL, 5);
    $self->{grid_sizer_4}->Add($self->{checkbox_1073}, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 5);
    my $label_4 = Wx::StaticText->new($self->{panel_1}, wxID_ANY, "1007 Rent Schedule");
    $self->{grid_sizer_4}->Add($label_4, 1, wxALIGN_RIGHT|wxALL, 5);
    $self->{grid_sizer_4}->Add($self->{checkbox_1007}, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 5);
    my $label_5 = Wx::StaticText->new($self->{panel_1}, wxID_ANY, "1025 Multi-family Comp");
    $self->{grid_sizer_4}->Add($label_5, 1, wxALIGN_RIGHT|wxALL, 5);
    $self->{grid_sizer_4}->Add($self->{checkbox_1025mfc}, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 5);
    my $label_6 = Wx::StaticText->new($self->{panel_1}, wxID_ANY, "1025 Multi-family Rent");
    $self->{grid_sizer_4}->Add($label_6, 1, wxALIGN_RIGHT|wxALL, 5);
    $self->{grid_sizer_4}->Add($self->{checkbox_1025mfr}, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 5);
    my $label_7 = Wx::StaticText->new($self->{panel_1}, wxID_ANY, "Desktop Comp");
    $self->{grid_sizer_4}->Add($label_7, 1, wxALIGN_RIGHT|wxALL, 5);
    $self->{grid_sizer_4}->Add($self->{checkbox_Dtcomp}, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 5);
    $self->{grid_sizer_4}->AddGrowableCol(0);
    $self->{grid_sizer_2}->Add($self->{grid_sizer_4}, 1, wxEXPAND, 5);
    my $static_line_2 = Wx::StaticLine->new($self->{panel_1}, wxID_ANY);
    $self->{grid_sizer_2}->Add($static_line_2, 1, wxALL|wxEXPAND, 5);
    $self->{grid_sizer_2}->Add(20, 10, 0, wxEXPAND, 0);
    $self->{grid_sizer_6}->Add($self->{Open_file}, 1, wxALL, 8);
    $self->{grid_sizer_6}->Add($self->{Exit}, 1, wxALL, 8);
    $self->{grid_sizer_6}->AddGrowableCol(0);
    $self->{grid_sizer_6}->AddGrowableCol(1);
    $self->{grid_sizer_2}->Add($self->{grid_sizer_6}, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 0);
    $self->{grid_sizer_1}->Add($self->{grid_sizer_2}, 1, 0, 0);
    my $label_8 = Wx::StaticText->new($self->{panel_1}, wxID_ANY, "Status");
    $self->{grid_sizer_3}->Add($label_8, 1, wxALIGN_CENTER|wxALL, 6);
    $self->{grid_sizer_3}->Add($self->{text_ctrl_1}, 1, wxBOTTOM|wxEXPAND|wxLEFT|wxRIGHT, 10);
    $self->{grid_sizer_3}->AddGrowableRow(1);
    $self->{grid_sizer_3}->AddGrowableCol(0);
    $self->{grid_sizer_1}->Add($self->{grid_sizer_3}, 1, wxALIGN_CENTER|wxALL|wxEXPAND, 5);
    $self->{panel_1}->SetSizer($self->{grid_sizer_1});
    $self->{grid_sizer_1}->AddGrowableRow(0);
    $self->{grid_sizer_1}->AddGrowableCol(1);
    $self->{sizer_1}->Add($self->{panel_1}, 1, wxEXPAND, 0);
    $self->SetSizer($self->{sizer_1});
    $self->Layout();
    # end wxGlade
}

sub cb1 {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::cb1 <event_handler>
    
    my $cbNm = $self->{cbName}{cbname} = "checkbox_1004";
    my $cbNb = $self->{cbName}{cbnum} = 0;
    
    my $checked = $event->IsChecked();
    $self->unSet_allCB();

    if ($checked) {
        $self->{checkbox_1004}->SetValue(1);
        $self->{cbOptions}[0] = 1;
    }
    else {
        $self->{checkbox_1004}->SetValue(0);
        $self->{cbOptions}[0] = 0;
    }

    my $cb = $self->{cbOptions};
    #print @$cb;
    #print "\n";    
    
    
    #warn "Event handler (cb1) not implemented";
    #$event->Skip;
    # end wxGlade
}


sub cb2 {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::cb2 <event_handler>
    
    my $checked = $event->IsChecked();
    $self->unSet_allCB();

    if ($checked) {
        $self->{checkbox_1073}->SetValue(1);
        $self->{cbOptions}[1] = 1;
    } 
    else  {
        $self->{checkbox_1073}->SetValue(0);
        $self->{cbOptions}[1] = 0;
    }

    my $cb = $self->{cbOptions};
    print @$cb;
    print "\n";
        
    #warn "Event handler (cb2) not implemented";
    #$event->Skip;
    # end wxGlade
}


sub cb3 {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::cb3 <event_handler>
    
    my $checked = $event->IsChecked();
    $self->unSet_allCB();

    if ($checked) {
        $self->{checkbox_1007}->SetValue(1);
        $self->{cbOptions}[2] = 1;
    }
    else {
        $self->{checkbox_1007}->SetValue(0);
        $self->{cbOptions}[2] = 0;
    }
    
    my $cb = $self->{cbOptions};
    print @$cb;
    print "\n";
    
    
    warn "Event handler (cb3) not implemented";
    $event->Skip;
    # end wxGlade
}


sub cb4 {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::cb4 <event_handler>
    
    my $checked = $event->IsChecked();
    $self->unSet_allCB();

    if ($checked) {
        $self->{checkbox_1025mfc}->SetValue(1);
        $self->{cbOptions}[3] = 1;
    }
    else {
        $self->{checkbox_1025mfc}->SetValue(0);
        $self->{cbOptions}[3] = 0;
    }
    
    my $cb = $self->{cbOptions};
    print @$cb;
    print "\n";    
    
    #warn "Event handler (cb4) not implemented";
    #$event->Skip;
    # end wxGlade
}


sub cb5 {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::cb5 <event_handler>
    
    my $checked = $event->IsChecked();
    $self->unSet_allCB();

    if ($checked) {
        $self->{checkbox_1025mfr}->SetValue(1);
        $self->{cbOptions}[4] = 1;
    }
    else {
        $self->{checkbox_1025mfr}->SetValue(0);
        $self->{cbOptions}[4] = 0;
    }

    my $cb = $self->{cbOptions};
    print @$cb;
    print "\n";    
    
    #warn "Event handler (cb5) not implemented";
    #$event->Skip;
    # end wxGlade
}


sub cb6 {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::cb6 <event_handler>
    
    my $checked = $event->IsChecked();
    $self->unSet_allCB();

    if ($checked) {
        $self->{checkbox_Dtcomp}->SetValue(1);
        $self->{cbOptions}[5] = 1;
    }
    else {
        $self->{checkbox_Dtcomp}->SetValue(0);
        $self->{cbOptions}[5] = 0;
    }

    my $cb = $self->{cbOptions};
    print @$cb;
    print "\n";    
    
    
    #warn "Event handler (cb6) not implemented";
    #$event->Skip;
    # end wxGlade
}


sub OpenFile {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::OpenFile <event_handler>
    
    # make sure that a processsing option is selected.
    my @cbar = @{$self->{cbOptions}};
    my $selopt = grep /1/, @cbar ;
    if ( $selopt == 0 ){
            $self->msg_dialog();
            $event->Skip;
            return;
    }
    
    $self->{Open_file}->Enable(0);
    my $fileDialog       = Wx::FileDialog->new( $self, "Select MLS File", "", "", "", wxFD_OPEN );
    my $fileDialogStatus = $fileDialog->ShowModal();
    my $filename         = $fileDialog->GetPath();

    $self->{text_ctrl_1}->AppendText("Processing Data\n\n");

    my $WTfileNm = DoConvert( $filename, $self->{cbOptions}, $self->{text_ctrl_1} );

    my $cmd = "notepad.exe ".$WTfileNm;
    my ( $stat, $output ) = Wx::ExecuteCommand($cmd);

    $self->{text_ctrl_1}->WriteText("\nFinished\n");
    $self->{Open_file}->Enable(1);    
    
    #warn "Event handler (OpenFile) not implemented";
    #$event->Skip;
    # end wxGlade
}


sub Finish {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::Finish <event_handler>
    
    $self->Destroy();
    
    #warn "Event handler (Finish) not implemented";
    #$event->Skip;
    # end wxGlade
}


sub text {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::text <event_handler>
    # warn "Event handler (text) not implemented";
    $event->Skip;
    # end wxGlade
}


sub textenter {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::textenter <event_handler>
    warn "Event handler (textenter) not implemented";
    $event->Skip;
    # end wxGlade
}


sub textmaxlen {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::textmaxlen <event_handler>
    warn "Event handler (textmaxlen) not implemented";
    $event->Skip;
    # end wxGlade
}


sub texturl {
    my ($self, $event) = @_;
    # wxGlade: MyFrame::texturl <event_handler>
    warn "Event handler (texturl) not implemented";
    $event->Skip;
    # end wxGlade
}

sub unSet_allCB {
    my ($self) = @_;
    if ( $self->{checkbox_1004}->GetValue() ) {
        $self->{checkbox_1004}->SetValue(0);
        $self->{cbOptions}[0] = 0;
    }
    if ( $self->{checkbox_1073}->GetValue() ) {
        $self->{checkbox_1073}->SetValue(0);
        $self->{cbOptions}[1] = 0;
    }    
    if ( $self->{checkbox_1007}->GetValue() ) {
        $self->{checkbox_1007}->SetValue(0);
        $self->{cbOptions}[2] = 0;
    }
    if ( $self->{checkbox_1025mfc}->GetValue() ) {
        $self->{checkbox_1025mfc}->SetValue(0);
        $self->{cbOptions}[3] = 0;
    }
    if ( $self->{checkbox_1025mfr}->GetValue() ) {
        $self->{checkbox_1025mfr}->SetValue(0);
        $self->{cbOptions}[4] = 0;
    }
    if ( $self->{checkbox_Dtcomp}->GetValue() ) {
        $self->{checkbox_Dtcomp}->SetValue(0);
        $self->{cbOptions}[5] = 0;
    }

}

sub msg_dialog {
    my( $self ) = @_;
    my $info = Wx::AboutDialogInfo->new;

    $info->SetName( 'Select Option' );
    #$info->SetVersion( '0.01 alpha 12' );
    $info->SetDescription( 'Select One Processing Option' );
    #$info->SetCopyright( '(c) 2001-today Me <me@test.com>' );

    Wx::AboutBox( $info );
}


# end of class MyFrame

1;

package MyApp;

use base qw(Wx::App);
use strict;

sub OnInit {
    my( $self ) = shift;

    Wx::InitAllImageHandlers();

    my $frame = MyFrame->new();

    $self->SetTopWindow($frame);
    $frame->Show(1);

    return 1;
}
# end of class MyApp

package main;

unless(caller){
    my $app = MyApp->new();
    $app->MainLoop();
}


