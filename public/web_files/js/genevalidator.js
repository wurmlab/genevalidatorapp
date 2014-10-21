$(document).ready(function() {
  checkCollapseState()
  keepFooterFixedToBottom()
  addSeqValidation()
  inputValidation()

  $(document).bind("keydown", function (e) {
    if (e.ctrlKey && e.keyCode === 13 ) {
      $('#input').trigger('submit')
    }
  })
})


// Looks for a cookie (called 'GeneValidator_adv_params_status') to check the state of the adv_params box when it was last closed. 
//  This function is called upon as soon as the website is loaded;  
function checkCollapseState() {
  if ($.cookie('GeneValidator_adv_params_status')){
    var adv_params_status = $.cookie('GeneValidator_adv_params_status')
    if (adv_params_status === 'open') {
      var btn = document.getElementById("adv_params_btn")
      btn.innerHTML = '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Hide Advanced Parameters'
      $('#adv_params').addClass('in')
    }
  }
}

// This function simply ensures that the footer stays to fixed to the bottom of the window
function keepFooterFixedToBottom() {
  $('#mainbody').css({'margin-bottom': (($('#footer').height()) + 15)+'px'})
  $(window).resize(function(){
      $('#mainbody').css({'margin-bottom': (($('#footer').height()) + 15)+'px'})
  })
}

// Creates a custom Validation for Jquery Validation plugin...
// It ensures that sequences are either protein or genetic data...
// If there are multiple sequences, ensures that they are of the same type
// It utilises the checkType function (further below)...
function addSeqValidation() {
  jQuery.validator.addMethod("checkInputType", function(value, element) {
    types = []
    if (value.charAt(0) === '>') {
      seqs_array = value.split('>')
      for (var i = 1; i < seqs_array.length; i++) {
        lines = seqs_array[i].split('\n')
        if (lines.length !== 0) {
          clean_lines = jQuery.grep(lines,function(n){ return(n) });
          if (clean_lines.length !== 0){
            clean_lines.shift()
            seq = clean_lines.join('')
            var type = checkType(seq, 0.9)
            types.push(type)
            if ((type !== 'protein') && (type !== 'dna') && (type !== 'rna')) {
              return false
            }
          }
        } 
      }
      var firstType = types[0]
      for (var i = 0; i < types.length; i++) {
        if (types[i] !== firstType){
          return false
        }
      }
      return true
    } else {
      var type = checkType(value, 0.9)
      if ((type !== 'protein') && (type !== 'dna') && (type !== 'rna')) {
        return false
      } else {
        return true
      }
    }
  }, "* The Input must be either genetic or protein Sequence(s). Please ensure that your sequences do not contains any non-letter character(s). If there are multiple sequences, ensure that they are all of one type. ");
}


// A function that validates the input - Utilises Jquery.Validator.js
function inputValidation() {
  var maxCharacters = $('#seq').attr("data-maxCharacters")
  $('#input').validate({
    rules: {
        seq: {
            minlength: 5,
            required: true,
            checkInputType: true,
            maxlength: maxCharacters // returns a number or undefined
        },
        'validations[]': {
           required: true,
        },
    },
    highlight: function(element) {
        $(element).closest('.form-group').addClass('has-error');
    },
    unhighlight: function(element) {
        $(element).closest('.form-group').removeClass('has-error');
    },
    errorElement: 'span',
    errorClass: 'help-block',
    errorPlacement: function(error, element) {
        if (element.parent().parent().attr('id') === 'validations_group') {
          var helpText = document.getElementById('lastValidation')
          error.insertAfter(helpText);
        } else{
          if (element.parent('.input-group').length) {
              error.insertAfter(element.parent());
          } else {
              error.insertAfter(element);
          }
        }
    },
    submitHandler: function(form) {
      $('#spinner').modal({
        backdrop: 'static',
        keyboard: 'false'
      })
      ajaxFunction()
    }
  })
}

// Sends the data within the form to the Server
function ajaxFunction() {
  $.ajax({
    type: 'POST',
    url: 'input',
    data: $('#input').serialize(),
    success: function(response){
      $('#results_box').show();
      $('#output').html(response)
      initTableSorter() // initiate the table sorter
      $("[data-toggle='tooltip']").tooltip() // Initiate the tooltips
      removeEmptyColumns(); // Remove Unwanted Columns
      $('#spinner').modal('hide') // remove progress notification
    },
    error: function (e, status) {
      if (e.status == 500) {
        var errorMessage = e.responseText
        $('#results_box').show();
        $('#output').html(errorMessage)
        $('#spinner').modal('hide') // remove progress notification
      } else {
        var errorMessage = e.responseText
        $('#results_box').show();
        $('#output').html("There seems to be an unidentified Error.")
        $('#spinner').modal('hide') // remove progress notification
      }
    }

  })
}

//  Table sortert Initialiser 
//   Contains a custom parser that allows the Stars to be sorted. 
function initTableSorter() {
  $.tablesorter.addParser({
    id: 'star_scores',
    is: function(s) {return false},
    format: function(s, table, cell, cellIndex) {
      var $cell = $(cell)
      if (cellIndex === 2) {
        return $cell.attr('data-score') || s
      } 
      return s
    },
    parsed: false,
    type: 'numeric'
  })

  $('table').tablesorter({
    headers: {
      2 : { sorter: 'star_scores' }
    },
  })
}

// Remove empty colums that are not used for that type of input data...
function removeEmptyColumns() {
  $('#sortable_table tr th').each(function(i) {
    var tds = $(this).parents('table') // Select all tds in column
    .find('tr td:nth-child(' + (i + 1) + ')')
    // Check if all cells in the column are empty
    if ($(this).hasClass( "chart-column" )) {
    } else {
      if ($(this).text().trim() == '') { 
        //hide header
        $(this).hide();
        //hide cells
        tds.hide();
      }
    }
  })
}

// Function is called each time the Adv. Params button is pressed...
function changeAdvParamsBtnText() {
  var btn = document.getElementById("adv_params_btn")
  if (btn.innerHTML === '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Show Advanced Parameters') {
    btn.innerHTML = '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Hide Advanced Parameters'
    $('#adv_params').collapse('show')
    $.cookie('GeneValidator_adv_params_status', 'open')
  }
  else {
    btn.innerHTML = '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Show Advanced Parameters'
    $('#adv_params').collapse('hide')
    $.cookie('GeneValidator_adv_params_status', 'closed')
  }
}

// FROM BIONODE-Seq - See https://github.com/bionode/bionode-seq
// Checks whether a sequence is a protein or genetic sequence...
checkType = function (sequence, threshold, length, index) {
  if (threshold === undefined) {
    threshold = 0.9
  }
  if (length === undefined) {
    length = 10000
  }
  if (index === undefined) {
    index = 1
  }
  var seq = sequence.slice(index - 1, length)
  var total = seq.length
  var acgMatch = ((seq.match(/[ACG]/gi) || []).length) / total
  var tMatch = ((seq.match(/[T]/gi) || []).length) / total
  var uMatch = ((seq.match(/[U]/gi) || []).length) / total
  var proteinMatch = ((seq.match(/[ARNDCQEGHILKMFPSTWYV\*]/gi) || []).length) / total

  if (((acgMatch + tMatch) >= threshold) || ((acgMatch + uMatch) >= threshold)) {
    if (tMatch >= uMatch) {
      return 'dna'
    } else if (uMatch >= tMatch) {
      return 'rna'
    } else {
      return 'dna'
    }
  } else if (proteinMatch >= threshold) {
    return 'protein'
  }
}
