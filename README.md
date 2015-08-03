# GeneValidatorApp
[![Build Status](https://travis-ci.org/wurmlab/genevalidatorapp.svg?branch=master)](https://travis-ci.org/wurmlab/genevalidatorapp)
[![Gem Version](https://badge.fury.io/rb/genevalidatorapp.svg)](http://badge.fury.io/rb/genevalidatorapp)
[![Scrutinizer Code Quality](https://scrutinizer-ci.com/g/wurmlab/genevalidatorapp/badges/quality-score.png?b=master)](https://scrutinizer-ci.com/g/wurmlab/genevalidatorapp/?branch=master)







## Introduction

This is a online web application for [GeneValidator](https://github.com/wurmlab/genevalidator). This app is currently hosted at: [genevalidator.sbcs.qmul.ac.uk](http://genevalidator.sbcs.qmul.ac.uk).

GeneValidator helps in identifing problems with gene predictions and provides useful information extracted from analysing orthologs in BLAST databases. The results produced can be used by biocurators and researchers who need accurate gene predictions.

If you use GeneValidator in your work, please cite us as follows:
> "Dragan M<sup>&Dagger;</sup>, Moghul MI<sup>&Dagger;</sup>, Priyam A, Bustos C & Wurm Y (<em>in prep.</em>) GeneValidator: identify problematic gene predictions"






-
## Installation
### Installation Requirements
* Ruby (>= 2.0.0)
* NCBI BLAST+ (>= 2.2.30+) (download [here](http://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)).
* MAFFT installation (download [here](http://mafft.cbrc.jp/alignment/software/)).

Please see [here](https://gist.github.com/IsmailM/b783e8a06565197084e6) for more help with installing the prerequisites.

### Installation
Simply run the following command in the terminal.

```bash
gem install genevalidatorapp
```

If that doesn't work, try `sudo gem install genevalidatorapp` instead.

##### Running From Source (Not Recommended)
It is also possible to run from source. However, this is not recommended.

```bash
# Clone the repository.
git clone https://github.com/wurmlab/genevalidatorapp.git

# Move into GeneValidatorApp source directory.
cd GeneValidatorApp

# Install bundler
gem install bundler

# Use bundler to install dependencies
bundle install

# Optional: run tests and build the gem from source
bundle exec rake

# Run GeneValidator.
bundle exec genevalidatorapp -h
# note that `bundle exec` executes GeneValidatorApp in the context of the bundle

# Alternativaly, install GeneValidatorApp as a gem
bundle exec rake install
genevalidatorapp -h
```




## Launch GeneValidator

To configure and launch GeneValidatorApp, run the following from a command line.

```bash
genevalidatorapp
```

GeneValidatorApp will automatically guide you through an interactive setup process to help locate BLAST+ binaries and ask for the location of BLAST+ databases.

That's it! Open http://localhost:4567/ and start using GeneValidator!






## Advanced Usage

See `$ genevalidatorapp -h` for more information on all the options available when running GeneValidatorApp.

```bash
SUMMARY:
  GeneValidator - Identify problems with predicted genes

USAGE:
  $ genevalidatorapp [options]

Examples:
  # Launch GeneValidatorApp with the given config file
  $ genevalidatorapp --config ~/.genevalidatorapp.conf

  # Launch GeneValidatorApp with 8 threads at port 8888
  $ genevalidatorapp --num_threads 8 --port 8888

  # Create a config file with the other arguments
  $ genevalidatorapp -s -d ~/database_dir

    -c, --config_file                Use the given configuration file
    -b, --bin                        Load BLAST+ and/or MAFFT binaries from this directory
    -d, --database_dir               Read BLAST database from this directory
    -f, --default_database_path      The path to the default BLAST database
    -n, --num_threads                Number of threads to use to run a BLAST search
    -r, --require                    Load extension from this file
    -H, --host                       Host to run GeneValidatorApp on
    -p, --port                       Port to run GeneValidatorApp on
    -s, --set                        Set configuration value in default or given config file
    -l, --list_databases             List BLAST databases
    -D, --devel                      Start GeneValidatorApp in development mode
    -v, --version                    Print version number of GeneValidatorApp that will be loaded
    -h, --help                       Display this help message.
```


<hr>

This program was developed at [Wurm Lab](https://wurmlab.github.io), [QMUL](http://sbcs.qmul.ac.uk) with the support of a BBSRC grant.
