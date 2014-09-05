$(document).ready(function() {
  $('#input').submit(function(e) {
    e.preventDefault();
    // show activity spinner
    $('#spinner').modal({
        backdrop: 'static',
        keyboard: 'false'
      });

    // Check the type of the sequence...
    // check numbers
    var input = document.forms["input"]['seq'].value;
    // console.log(input)

    // Ckeck if no  Validations 
    if (check_val_empty()) {
      $('#spinner').modal('hide');
      //  Load an error Modal...
      return;
    };

    // DO Valdiations here before sending off the request...

    $.ajax({
      type: 'POST',
      url: '/input',
      data: $('#input').serialize(),
      success: function(response){
        $('#output').html(response);
        // initiate the table sorter
             // add custom parser to make the stars column to sort according to attr.
            $.tablesorter.addParser({
              id: 'star_scores', // called later when init the tablesorter
              is: function(s) {
                return false; // return false so this parser is not auto detected
              },
              format: function(s, table, cell, cellIndex) {
                var $cell = $(cell);
                if (cellIndex === 2) {
                  return $cell.attr('data-score') || s;
                } 
                return s;
              },
              parsed: false,
              type: 'numeric' // Setting type of data...
            });

            $('table').tablesorter({
              headers: {
                2 : { sorter: 'star_scores' } // Telling it to use custom parser...
              },
            });



        // Initiate the tooltips
        $("[data-toggle='tooltip']").tooltip();
        // remove progress notification
        $('#spinner').modal('hide');
      },
    })
  })
  
  // Handles the form submission when Ctrl+Enter is pressed anywhere on page. taken from SequenceServer...
  $(document).bind("keydown", function (e) {
    if (e.ctrlKey && e.keyCode === 13 ) {
      $('#input').trigger('submit');
    }
  });
})

function check_val_empty() {
  var val = document.forms["input"]['validations[]'];
  var checkedVal = [];
  var valLength = val.length

  for (var i = 0; i < valLength; i++) {
    if (val[i].checked) {
      checkedVal.push(val[i]);
    }
  }
  return checkedVal.length === 0 ? true : false; 
}


function change_adv_params_btn_text(adv_user){
  var btn = document.getElementById("adv_params_btn");
  if (btn.innerHTML === '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Show Advanced Parameters') {
    btn.innerHTML = '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Hide Advanced Parameters';
    $('#adv_params').collapse('show');
  }
  else {
    btn.innerHTML = '<i class="fa fa-pencil-square-o"></i>&nbsp;&nbsp;Show Advanced Parameters';
    $('#adv_params').collapse('hide');
  }
}