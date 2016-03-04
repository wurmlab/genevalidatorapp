# GeneValidator
#
# A web wrapper for GeneValidator (identify problems with predicted genes)
#
# If you use GeneValidator in your work, please cite us as follows:
#
#  Dragan M‡, Moghul MI‡, Priyam A, Bustos C & Wurm Y. 2016.
#  GeneValidator: identify problems with protein-coding gene predictions.
#  Bioinformatics, doi: 10.1093/bioinformatics/btw015.
#
# VERSION 1.0.0

FROM ubuntu:16.04
MAINTAINER Bruno Vieira <mail@bmpvieira.com>

LABEL Description="Identify problems with protein-coding gene predictions http://genevalidator.sbcs.qmul.ac.uk" Version="1.0.0"

RUN apt-get update
RUN apt-get install -y build-essential ruby ruby-dev ncbi-blast+ mafft zlib1g-dev libgsl0-dev
RUN gem install genevalidatorapp
CMD genevalidatorapp -d /db
