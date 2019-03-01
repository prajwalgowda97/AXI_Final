#!/usr/bin/perl -w
use strict;
use FileHandle;
use Cwd qw(cwd);
use File::Path;
use List::Util qw(shuffle);
system("figlet -c Project-Z");

my $simulateFlag  = 1;
my $pwd           = cwd;
my ($day,$mon)    = (localtime)[3..5];
my $date          = sprintf("%02d_%02d",$day,$mon+1);
my $regdir        = "$pwd/${date}_regression_result";
eval { mkpath($regdir) unless (-d $regdir)} or die "can't create log directory";
my $iFile         = $ARGV[0];
my $cov_en        = $ARGV[1];
my @tests         = ();
my @pass_tests    = ();
my @fail_tests    = ();

open(FILE, "<", $iFile) or die $!;
foreach my $line (shuffle <FILE>) 
{
  print $line;
  if($line =~/^\s*(\w+)\s+(\d+)\s*$/) 
  {
    for(my $i = 0; $i < $2; $i++) 
    {
      push @tests, $1;
    }
  } 
  elsif($line =~/^\s*(\w+)\s*$/) 
  {
    push @tests, $1;
  } 
  else 
  {
    print "*warning: ignored $line";
  }
}
close(FILE);

foreach my $test (@tests) 
{
  simulate_test($test); 
}
   
if($simulateFlag) 
{
  report_test();
}

sub simulate_test 
{
  my $pass = 0;
  my ($test) = @_;
   {   
    my $seed = int (rand(100000));
   
    if(defined $cov_en) ###### Inside the irun command change the compile_file path to your file and DUT_NAME with your dut instance name in your TB top file #####
    {
      system("irun -access +rwc -f compile_list.f -svseed $seed +UVM_TESTNAME=$test  +define+UVM_REPORT_DISABLE_FILE_LINE -coverage all -covdut axi4_slave_top  -covworkdir /cov_work -covoverwrite -covfile ./cov_files/cov_cmd.cf -uvmhome CDNS-1.1d"); 
    }
    else
    {  
      system("irun -access +rwc -f compile_list.f -svseed $seed +UVM_TESTNAME=$test +define+UVM_REPORT_DISABLE_FILE_LINE -uvmhome CDNS-1.1d"); 
    }


if(open(FILE, "<", "irun.log")) 
    {
      my $f = do {local $/;<FILE>};
      $pass = ($f =~ /UVM_ERROR\s*:\s*0\s*.*UVM_FATAL\s*:\s*0\s*/);
      if($pass != 1)
      {
        my $simdir = "${regdir}/${test}_${seed}";
        eval { mkpath($simdir) unless (-d $simdir)} or die "can't create log directory";
    
        if(open (FILE1,'>',"${simdir}/${test}_${seed}.log"))
        {   
          print FILE1 $f;
    
        }
        close (FILE1);    

        system("mv ./wave.shm ${simdir}/");
        system("mv ./x* ${simdir}/");
      }
      else
      {
        system("rm -r ./wave.shm");
      } 
      if($pass)
      {
        push @pass_tests, "test_name : ${test}    seed : ${seed}";
      }
      else 
      {
        push @fail_tests, "test_name : ${test}    seed : ${seed}";
      }
    close (FILE);
    }
 } }
   
if(defined $cov_en)
  {
       system("imc -exec ./cov_files/cov_merge.cmd");   
       system("mv cov_report.txt ${regdir}/");
       system("mv cov_report_html ${regdir}/");
       system("mv cov_uncovered_report.txt  ${regdir}/");
       system("rm imc.log");
       system("rm mdv.log");
       system("rm imc.key"); 
       system("rm -r cov_work");

  }

sub report_test {
  open(FILE, ">>", "${regdir}/${date}_regression.log") or die $!;
  print FILE "REGRESSION RESULTS\n";
  print FILE "==================\n\n";
  print FILE "PASSED TESTS: " . scalar @pass_tests . "\n";
  foreach my $pass_test (@pass_tests) {
    print FILE "$pass_test\n";
  }
  print FILE "\n----------------\n";
  print FILE "FAILED TESTS: " . scalar @fail_tests . "\n";
  foreach my $fail_test (@fail_tests) {
    print FILE "$fail_test\n";
  }
  close(FILE);
  print "\n";
  system("cat ${regdir}/${date}_regression.log");
}

system("rm -rf x*");

exit 0;


