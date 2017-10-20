#!/usr/bin/perl

# Requires 'yum install perl-Net-OpenSSH.noarch'

use Net::OpenSSH;

my $host = "$ARGV[0]";
my $password = "$ARGV[1]";

$filename = 'imapsync-accounts.txt';

# use the perl open function to open the file
open(FILE, $filename) or die "Could not read from $filename, program halting.";

my $ssh = Net::OpenSSH->new($host, password => $password);
   $ssh->error and
         die "Couldn't establish SSH connection: ". $ssh->error;

         # loop through each line in the file
         # with the typical "perl file while" loop
         while(<FILE>)
         {
           # get rid of the pesky newline character
             chomp;

               # read the fields in the current line into an array
                 @fields = split(';', $_);

                  $ssh->system("/scripts/addpop '$fields[0]' '$fields[1]' 0");

                  }
                  close FILE;
