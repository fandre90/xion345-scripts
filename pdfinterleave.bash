#!/bin/bash

# Copyright Fabien André <fabien.andre@xion345.info>
# Distributed under the MIT license

# This script interleaves pages from two distinct PDF files and produces an 
# output PDF file. The odd pages are taken from a first PDF file and the even 
# pages are taken from a second PDF file passed respectively as first and second
# argument.
# The first two pages of the output file are the first page of the
# odd pages PDF file and the *last* page of the even pages PDF file. The two
# following pages are the second page of the odd pages PDF file and the 
# second to last page of the even pages PDF file and so on.
#
# This is useful if you have two-sided documents scanned each side on a 
# different file as it can happen when using a one-sided Automatic Document
# Feeder (ADF)
#
# It does a similar job to : 
# https://github.com/weltonrodrigo/pdfapi2/blob/46434ab3f108902db2bc49bcf06f66544688f553/contrib/pdf-interleave.pl
# but only requires bash (> 4.0) and poppler utils.

# Print usage/help message
function usage {
    echo "Usage: $0 <PDF-even-pages-file> <PDF-odd-pages-file>"
    exit 1
}

# Add leading zeros to pad numbers in filenames matching the pattern 
# $prefix$number.pdf. This allows filenames to be easily sorted using
# sort.
#  $1 : The prefix of the filenames to consider
function add_leading_zero {
    prefix=$1
    baseprefix=$(basename $prefix | sed -e 's/[]\/()$*.^|[]/\\&/g')
    dirprefix=$(dirname $prefix)
    for filename in "$prefix"*".pdf"
    do
        base=$(basename "$filename")
        index=$(echo "$base" | sed -rn "s/$baseprefix([0-9]+).pdf$/\1/p")
        newbase=$(printf "$baseprefix%04d.pdf" $index)
        mv $filename "$dirprefix/$newbase"
  done
}

# Interleave pages from two distinct PDF files and produce an output PDF file.
# Note that the pages from the even pages file (second file) will be used in 
# the reverse order (last page first).
#   $1 : Odd pages filename
#   $2 : Odd pages filename with extension removed
#   $3 : Even pages filename
#   $4 : Even pages filename with extension removed
#   $5 : Unique key used for temporary files
#   $6 : Output file
function pdfinterleave {
    oddfile=$1
    oddbase=$2
    evenfile=$3
    evenbase=$4
    key=$5
    outfile=$6
    # Odd pages
    pdfseparate $oddfile "$oddbase-$key-%d.pdf"
    add_leading_zero "$oddbase-$key-"
    oddpages=($(ls "$oddbase-$key-"* | sort))
    
    # Even pages
    pdfseparate $evenfile "$evenbase-$key-%d.pdf"
    add_leading_zero "$evenbase-$key-"
    evenpages=($(ls "$evenbase-$key-"* | sort -r))

    # Interleave pages
    pages=()
    for((i=0;i<${#oddpages[@]};i++))
    do
        pages+=(${oddpages[i]})
        pages+=(${evenpages[i]})
    done

    pdfunite ${pages[@]} "$outfile"

    rm ${oddpages[@]}
    rm ${evenpages[@]}
}

if [ $# -lt 2 ]
then
    usage
fi

if [ $1 == $2 ]
then
    echo "Odd pages file and even pages file must be different." >&2
    exit 1
fi

if ! hash pdfunite 2>/dev/null || ! hash pdfseparate 2>/dev/null
then
    echo "This script requires pdfunite and pdfseparate from poppler utils" \
      "to be in the PATH. On Debian based systems, they are found in the" \
      "poppler-utils package"
    exit 1
fi

oddbase=${1%.*}
evenbase=${2%.*}
odddir=$(dirname $oddbase)
oddfile=$(basename $oddbase)
evenfile=$(basename $evenbase)

outfile="$odddir/$oddfile-$evenfile-interleaved.pdf"
key=$(tr -dc "[:alpha:]" < /dev/urandom | head -c 8)
if [ -e $outfile ]
then
   echo "Output file $outfile already exists" >&2
   exit 1
fi

pdfinterleave $1 $oddbase $2 $evenbase $key $outfile

# SO - Bash command that prints a message on stderr
#   http://stackoverflow.com/questions/2643165/bash-command-that-prints-a-message-on-stderr
# SO - Check if a program exists from a bash script
#   http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
# SO - How to debug a bash script?
#   http://stackoverflow.com/questions/951336/how-to-debug-a-bash-script
# SO - Escape a string for sed search pattern
#   http://stackoverflow.com/questions/407523/escape-a-string-for-sed-search-pattern