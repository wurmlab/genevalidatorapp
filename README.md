# GeneValidatorApp

This is a Sinatra based web wrapper for [GeneValidator](https://github.com/monicadragan/GeneValidator); a program that validates gene predictions. A working example can be seen at [genevalidator.sbcs.qmul.ac.uk](http://genevalidator.sbcs.qmul.ac.uk).

If you use this program in your research, please cite us as follows:

"Dragan M, Moghul MI, Priyam A & Wurm Y (<em>in prep</em>) GeneValidator: identify problematic gene predictions" 

This program was developed at [Wurm Lab](http://yannick.poulet.org), [QMUL](http://sbcs.qmul.ac.uk) with the support of a BBSRC grant.

## Installation

1. Install all GeneValidator Prerequisites (ruby <=1.9.3, Mafft, BLAST+). You would also require a BLAST database. 
  * Please see [here](https://gist.github.com/IsmailM/b783e8a06565197084e6) for more information.

2. Install GeneValidatorApp

    
    $ gem install GeneValidatorApp


3. Set up your configuration file (see the next section).

## Configuration File

A configuration file needs to set up in order for GeneValidatorApp to run. The default location for the configuration file is in the home directory (`~/.genevalidatorapp.conf`).

### Obtain an exemplar configuration file. 

When run, GeneValidatorApp will look for the configuration file and if one is not found, the program will provide you with a personalised command to run in order to copy the exemplar configuration file to your home directory.

1. Run GeneValidatorApp


    $ genevalidatorapp


2. Run the command shown.

There are a number of compulsory variables (that is required for GeneValidatorApp to run), and a few optional variables that allow the end-user to customise the installation to their requirements.

Note: The examples 

### Compulsory Variables

##### BLAST database directory 
This is the full path to the directory containing your BLAST database. GeneValidatorApp then analyses this directory for any BLAST databases. This variable is to be set as follows (please edit this example):

    database-dir: /Users/ismailm/blastdb

##### BLAST bin Path (Compulsory if BLAST is not in the $PATH)
This is a compulsory variable only if BLAST is not in your $PATH (you can find out if 'BLAST' is your $PATH through the following command `$ which blastp`).

This is the full path to the bin folder of your BLAST installation. This variable is to be set as follows (please edit this example):

    blast-bin-path: /Users/ismailm/blast/bin

##### Mafft Path (Compulsory if Mafft is not in the $PATH)
This is a compulsory variable only if Mafft is not in your $PATH (you can find out if 'Mafft' is your $PATH through the following command `$ which mafft`).

This is the full path to your mafft installation. This variable is to be set as follows (please edit this example):

    mafft-path: /Users/ismailm/mafft/bin/mafft

### Optional Variables 

##### Default BLAST database
This is the full path to your default database (don't include any file endings). If this is not set, a single database is choosen at random. This is set as follows (please edit this example):

    default-database: /Users/ismailm/blastdb/SwissProt

##### Website Directory
This is the directory that GeneValidator serves to the web application.

By default, this is  This folder contains all the files that the web application requires as well as any files produced when analysing sequences. This variable is set as follows (please edit this example):

    web-dir: /Users/ismailm/GV/

##### Maximum input length
If you wish to limit the input size (for example, for server load reasons), you can use the following option to limit the length of the input sequences. The example shown below limits the input size to 100,000 characters.

    max-characters: 100000

## Usage

After installing simply type in:

    $ genevalidatorapp

and then go to [http://localhost:4567](http://localhost:4567) (if on a local server and using the default port: 4567)

See `$ genevalidator -h` for more information on how to run GeneValidatorApp.

## Contributing

1. Fork it ( https://github.com/IsmailM/GeneValidatorApp/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
