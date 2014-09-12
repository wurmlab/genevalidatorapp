$(document).ready(function() {
  checkCollapseState()
  
  jQuery.validator.addMethod("checkInputType", function(value, element) {
    types = []
    if (value.charAt(0) === '>') {
      lines = value.split('\n')
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].match(/^>/)) {
        } else {
          var type = checkType(lines[i], 0.9)
          types.push(type)
          if ((type !== 'protein') && (type !== 'dna') && (type !== 'rna')) {
            return false
          }
        }
      }
      console.log(types)
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

  }, "* The Input must be either genetic or protein Sequence(s).");

    $('#input').validate({
      rules: {
          seq: {
              minlength: 5,
              required: true,
              checkInputType: true

          },
          'validations[]': {
             required: true,
          }
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
        console.log()
        //  if (element.parent().parent(_.hasClass("input-append")) {
        //   console.log('cwcwdwdc')
        // }
        //   console.log(element.parent().child())
        //   // error.insertAfter()
        // } else {
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



        // }
      },

      submitHandler: function(form) {

        $('#spinner').modal({
          backdrop: 'static',
          keyboard: 'false'
        })

        $.ajax({
          type: 'POST',
          url: '/input',
          data: $('#input').serialize(),
          success: function(response){
            console.log('2hey')
            $('#output').html(response)
            // initiate the table sorter
            initTableSorter()
            // Initiate the tooltips
            $("[data-toggle='tooltip']").tooltip()
            // Remove Unwanted Columns
            removeEmptyColumns(); 
            // remove progress notification
            $('#spinner').modal('hide')
          },
          failure: function(){
            return
          }
        })

      }
    })

  $(document).bind("keydown", function (e) {
    if (e.ctrlKey && e.keyCode === 13 ) {
      $('#input').trigger('submit')
    }
  })
})

checkType = function (sequence, threshold) {
  var total = sequence.length
  var acgMatch = ((sequence.match(/[ACG]/gi) || []).length) / total
  var tMatch = ((sequence.match(/[T]/gi) || []).length) / total
  var uMatch = ((sequence.match(/[U]/gi) || []).length) / total
  var proteinMatch = ((sequence.match(/[ARNDCQEGHILKMFPSTWYV\*]/gi) || []).length) / total

  if (((acgMatch + tMatch) > threshold) || ((acgMatch + uMatch) > threshold)) {
    if (tMatch > uMatch) {
      return 'dna'
    } else if (uMatch > tMatch) {
      return 'rna'
    };
  } else if (proteinMatch > threshold) {
    return 'protein'
  }
}


function checkEmptyValidation() {
  var val = document.forms["input"]['validations[]']
  var checkedVal = []
  var valLength = val.length

  for (var i = 0; i < valLength; i++) {
    if (val[i].checked) {
      checkedVal.push(val[i])
    }
  }
  if (checkedVal.length === 0) {
    $('#validations_group').addClass("has-error")
    $('#validation_alert').show()
    return true
  } else {
    return false
  }
}

function ChangeAdvParamsBtnText() {
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


////  TODO: Change the cookie name so that it has a Genevalidator prefix...  
// Looks for a cookie (called 'adv_params_status') to check the state of the adv_params box when it was last closed. 
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

function removeEmptyColumns() {
  $('#sortable_table tr th').each(function(i) {
    var tds = $(this).parents('table') // Select all tds in column
    .find('tr td:nth-child(' + (i + 1) + ')')
    // Check if all cells in the column are empty
    if(tds.length == tds.filter(':empty').length) { 
      $(this).hide() // Hide header
      tds.hide() // Hide cells
    }
  })
}