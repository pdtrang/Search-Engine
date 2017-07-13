#!/usr/bin/perl
use List::Util 'sum'; # module used to sum all values in a hash

use porter;

$query = join " ", @ARGV;
chomp($query);


$urlfile = "./mapURL.txt";
$indexfile = "./index.txt";

# function to print a hash
sub Print_hash
{
	my %hashref = @_;

	foreach my $key (sort keys %hashref){
		print $key, "\t", $hashref{$key},"\n";
	}
}

################################## Load mapURL and index ##################################
open (FILE, $urlfile) or die "Could not open $file: $!"; # open input file

%mapURL = ();
while( $line = <FILE>)  {   # read each line in the input file
	chomp($line);
	@text = ();
	@text = split/\s+/,$line;
	$mapURL{$text[0]} = $text[1];
}
close(FILE);

# Print_hash(%mapURL);

%wordcount = ();	# a hash to store total frequency of words in all documents.
%docs_count = ();	# a hash to store how different documents a word occurs.

open (FILE, $indexfile) or die "Could not open $file: $!"; # open input file

$l = 0;
while($line = <FILE>){
	chomp($line);
	@text = ();
	@text = split/\s+/,$line;

	if (($l%2) == 0){
		$docs_count{$text[0]} = $text[1];
		$word = $text[0];
	} else {
		$text_size = @text;
		for ($i = 0; $i < $text_size; $i=$i+2){
			$wordcount{$word}{$text[$i]} = $text[($i+1)];
		}
		
	}
	$l = $l + 1;
}

close(FILE);

################################## Finished Loading  mapURL and index ##################################

sub Process_Query{
	my $str = $_[0];
    
    $str =~ s/^\s+//; # remove space at the beginning
    $str =~ s/\s+$//; # remove space at the end
    $str =~ tr/[A-Z]/[a-z]/; # convert to lower case
    $str =~ s/\d//g; # remove digits
    $str =~ s/[[:punct:]]//g; # replace all punctuations in string by a space 

    
    my @words = split/\s+/,$str;

    # remove stop words and stemming
    $processed_str = "";
    foreach $word (@words) {
    	if (!exists $stop_words{$word}) {
    		$processed_str = $processed_str." ".porter($word);
    	}	    
	}
   
    return $processed_str;
}

$indir = "./processed/";

opendir DIR, $indir or die "cannot open dir $indir: $!";
@file= readdir DIR;
closedir DIR;

$N = @file;
$N = $N-2;

# compute IDF
%IDF = ();
foreach $word (keys %docs_count){
	$IDF{$word} = log( $N/$docs_count{$word} ) / ( log (10) );
}

# compute Document Length
$wtd = 0;
%DocLength = (); # Document Length
foreach $word (keys %IDF){
	$idf = $IDF{$word};
	foreach $k (keys %{$wordcount{$word}}){
		$c = $wordcount{$word}{$k};
		$wtd = $idf * $c;
		if (exists $DocLength{$k}){
			$DocLength{$k} = $DocLength{$k} + ($wtd * $wtd);
		} else {
			$DocLength{$k} = $wtd * $wtd;
		}
	}
}

# sqrt of Document Length
foreach $doc (keys %DocLength){
	$DocLength{$doc} = sqrt($DocLength{$doc});
}

# process query and put each word into an array and count frequency of words
$pq = Process_Query($query);

print ("You are searching for: ", $query,"\n");

@queryList = split(/\s+/,$pq);

%q_freq = (); # frequency of words in query
while($q = pop @queryList){

	if (exists $q_freq{$q}){
		$q_freq{$q} = $q_freq{$q} + 1;	
	} else {
		$q_freq{$q} = 1;	
	}
	
}

# compute nominator for cosine similarity
%docNum = (); # nominator of query and document for cosine similarity
$qLength = 0; # length of query
foreach $wo (keys %q_freq){
	if (exists $IDF{$wo}){
		$idf = $IDF{$wo}; # idf of word	
	} else {
		$idf = 0;
	}
	
	$qLength = $qLength + $q_freq{$wo}*$idf;
	$kq = $q_freq{$wo};	# count of word in query
	
	$w = $kq * $idf; # weight of word in query

	foreach $k (keys %{$wordcount{$wo}}){
		$c = $wordcount{$wo}{$k};

		if (exists $docNum{$k}){
			$docNum{$k} = $docNum{$k} + $w * $idf *$c;
		} else {
			$docNum{$k} = $w * $idf *$c;
		}
	}
}

# compute cosine similarity of query with document
%relatedDoc = (); # hash stores all related document with their scores 
foreach $k (keys %docNum){
	$score = $docNum{$k} / ($DocLength{$k} * sqrt($qLength));
	$relatedDoc{$k} = $score;
}

$size = keys %relatedDoc;
if ($size == 0){
	print "No result found.\n";
}
else{

	@keysList = sort { $relatedDoc{$b}<=> $relatedDoc{$a} } keys %relatedDoc;


	print "\nRelated Documents: \n";

	foreach $k (@keysList){
		print $k, " - ", $mapURL{$k}, " : ", $relatedDoc{$k},"\n";
	}

}