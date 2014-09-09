$(document).ready(function() {
  checkCollapseState()

  $('#input').submit(function(e) {
    e.preventDefault()
    // show activity spinner
    $('#spinner').modal({
      backdrop: 'static',
      keyboard: 'false'
    })

    // Check the type of the sequence...
    // check numbers
    // if (checkInputSeq()) {
    //   $('#spinner').modal('hide')
    //   //  Load an error Modal...
    //   return
    // }

    // Ckeck if no  Validations 
    if (checkEmptyValidation()) {
      $('#spinner').modal('hide')
      //  Load an error Modal...
      return
    }

    $.ajax({
      type: 'POST',
      url: '/input',
      data: $('#input').serialize(),
      success: function(response){
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
    })
  })
  
  // Handles the form submission when Ctrl+Enter is pressed anywhere on page. taken from SequenceServer...
  $(document).bind("keydown", function (e) {
    if (e.ctrlKey && e.keyCode === 13 ) {
      $('#input').trigger('submit')
    }
  })
})



// Validate the input
// Check the input type 
//// Can only have one type of sequence (not a mixture )
//// No Numbers....
function checkInputSeq(){
    var fasta = require('bionode-fasta')
    var seq = require('bionode-seq')
    var input = document.forms["input"]['seq'].value
    // var type = seq.checkType(input)
    // console.log(type)
    // console.log("hi")

    // fasta.obj('seq').on('data', console.log) // Returns Objects

    // return true; // Kills the app...
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
  return checkedVal.length === 0 ? true : false
}


function ChangeAdvParamsBtnText() {
  var btn = document.getElementById("adv_params_btn")
  if (btn.innerHTML === '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Show Advanced Parameters') {
    btn.innerHTML = '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Hide Advanced Parameters'
    $('#adv_params').collapse('show')
    $.cookie('adv_params_status', 'open')
  }
  else {
    btn.innerHTML = '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Show Advanced Parameters'
    $('#adv_params').collapse('hide')
    $.cookie('adv_params_status', 'closed')
  }
}


function checkCollapseState() {
  if ($.cookie('adv_params_status')){
    var adv_params_status = $.cookie('adv_params_status')
    if (adv_params_status === 'open') {
        var btn = document.getElementById("adv_params_btn")
        btn.innerHTML = '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Hide Advanced Parameters'
        $('#adv_params').addClass('in')
    }
  }
}

// A Table sortert Initialiser 
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