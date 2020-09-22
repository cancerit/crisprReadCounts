# Changes

## 1.4.0

* `crisprReadCounts.pl` now skips secondary, supplementary and vendor failed alignments in the input CRAM file.
* Added option `--reverse-complement`(`-rc`) to `crisprReadCounts.pl` to reverse complement input reads before counting. Reads are reverse complemented prior to trimming.

## 1.3.3

* Made plasmid file optional

## 1.3.2

* Fixes #9, #10, #11, #12, #13

## 1.3.1

* Added dual guiides to travis.yml

## 1.3.0

* Added code for dual guide CRISPR

## 1.2.0

* Added a Docker container
