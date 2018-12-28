use Module::Extract::Use;

$extractor = Module::Extract::Use->new;
$details = $extractor->get_modules_with_details("ConvertMLS.pm");
print "Convert::MLS::Paragon depends on:\n\n";
foreach my $m (@$details) {
    print "  $m->{module}:\n";
    print "     version = $m->{version}\n" if defined($m->{version});
    print "     pragma  = $m->{pragma}\n";
    print "     imports = ", join(' ', @{ $m->{imports} }),"\n";
    print "\n";
}