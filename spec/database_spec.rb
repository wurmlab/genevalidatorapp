require 'GeneValidatorApp'
require 'GeneValidatorApp/database'
require 'rspec'

module GeneValidatorApp

  describe 'Database' do

    let 'root' do
      GeneValidatorApp.root
    end

    let 'empty_config' do
      File.join(root, 'spec', 'empty_config.yml')
    end

    let 'database_dir' do
      File.join(root, 'spec', 'database')
    end

    let 'database_dir_no_db' do
      File.join(root, 'spec', 'database', 'proteins', 'Cardiocondyla_obscurior')
    end

    let 'app' do
      GeneValidatorApp.init(:config_file  => empty_config,
                          :database_dir => database_dir)
    end

    it 'can tell BLAST+ databases in a directory' do

    end

    it 'can tell NCBI multipart database name' do
    #   Database.multipart_database_name?('/home/ben/pd.ben/sequenceserver/db/nr.00').should be_true
    #   Database.multipart_database_name?('/home/ben/pd.ben/sequenceserver/db/nr').should be_false
    #   Database.multipart_database_name?('/home/ben/pd.ben/sequenceserver/db/img3.5.finished.faa.01').should be_true
    end
  end
end
