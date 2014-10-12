# GeneValidatorApp

This is a sinatra based web wrapper for [GeneValidator](https://github.com/monicadragan/GeneValidator). GeneValidator is a program that validates gene predictions.

## Installation

1. Install all GeneValidator Prerequisites (mafft, BLAST+). You would also require a BLAST database.

2. Install my fork of GeneValidator (In the next major version, this step will be automated)
```
	$ git clone https://github.com/IsmailM/GeneValidator.git
	$ cd GeneValidator
	$ rake
```
3. Install GeneValidatorApp
```
    $ gem install GeneValidatorApp
```
4. Copy the examplar config file to your home directory.
  * Run GeneValidatorApp
```
    $ genevalidatorapp 
```
  * Run the command shown to copy the examplar config file to your home directory.

5. Set up variables in your config file.
  * Set the `database-dir` variables to the full path to the directory containing your BLAST databases. 
  * Set the `default-database` variable to the full path to the BLAST database that you would like to be your default database. 

## Usage

After instaling simply type in:

	$ genevalidatorapp

and then go to localhost:4567 (if on a local server and using the default port: 4567)

## Debugging (or simply to see more info. on what's happening)

Run GeneValidatorApp with the -d argument.

	$ genevalidator -d


## Contributing

1. Fork it ( https://github.com/[my-github-username]/GeneValidatorApp/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
