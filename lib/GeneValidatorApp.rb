require "GeneValidatorApp/version"

module GeneValidatorApp
  def create_results(insides)
      results = '<div id="results_box"><h2 class="page-header">Results</h2>' + insides + '</div>'
      return results
    end

    # #results_box
    #   .page-header  Results
    #     == Insides

  def to_fasta(sequence)
    sequence = sequence.lstrip
    unique_queries = Hash.new()
    if sequence[0,1] != '>'
      sequence.insert(0, ">Submitted at #{Time.now.strftime('%H:%M, %A, %B %d, %Y')}\n")
    end
    sequence.gsub!(/^\>(\S+)/) do |s|
      if unique_queries.has_key?(s)
        unique_queries[s] += 1
        s + '_' + (unique_queries[s]-1).to_s
      else
        unique_queries[s] = 1
        s
      end
    end
    return sequence
  end
end
